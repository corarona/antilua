-- autocraft: custom crafting GUI with autocraft toggle
-- Open via /autocraft (chat command) or TAB → cheat menu

autocraft = {}

local al_formspec = core.al_formspec

local RECIPES = {}
local ACTIVE_KEY = nil
local PAUSED = false
local TIMER = 0
local INTERVAL = 0.3
local SETTING = "autocraft"
local WAS_ON = false
local recipe_filter = ""

local function recipe_key(grid)
	local parts = {}
	for i = 1, 9 do
		local s = grid[i]
		if s and not s:is_empty() then
			parts[i] = s:get_name() .. " " .. s:get_count()
		else
			parts[i] = ""
		end
	end
	return table.concat(parts, "|")
end

local function grids_match(a, b)
	for i = 1, 9 do
		local sa, sb = a[i], b[i]
		local na = (sa and not sa:is_empty()) and sa:get_name() or ""
		local nb = (sb and not sb:is_empty()) and sb:get_name() or ""
		if na ~= nb then
			return false
		end
	end
	return true
end

local function serialize()
	local out = {}
	for _, r in pairs(RECIPES) do
		local g = {}
		for i = 1, 9 do
			local s = r.grid[i]
			if s and not s:is_empty() then
				g[i] = {n = s:get_name(), c = s:get_count()}
			else
				g[i] = false
			end
		end
		table.insert(out, {g = g, o = r.output})
	end
	return core.write_json(out) or "[]"
end

local function load(data)
	local ok, parsed = pcall(core.parse_json, data)
	if not ok or not parsed then
		return
	end
	RECIPES = {}
	for _, entry in ipairs(parsed) do
		local gd = entry.g
		if gd then
			local items = {}
			for i = 1, 9 do
				local d = gd[i]
				if d then
					items[i] = ItemStack(d.n .. " " .. d.c)
				else
					items[i] = ItemStack()
				end
			end
			local key = recipe_key(items)
			if not RECIPES[key] then
				RECIPES[key] = {grid = items, output = entry.o or ""}
			end
		end
	end
end

local function save()
	core.settings:set("autocraft_recipes", serialize())
end

local saved = core.settings:get("autocraft_recipes")
if saved and saved ~= "" then
	load(saved)
end

local function msg(text)
	core.display_chat_message("Autocraft: " .. text)
end

local function is_on()
	return core.settings:get_bool(SETTING)
end

local function find_slots(inv, itemname, need)
	local main = inv and inv.main
	if not main then
		return nil, 0
	end
	local total = 0
	local slots = {}
	for i = 1, #main do
		local s = main[i]
		if s and not s:is_empty() and s:get_name() == itemname then
			table.insert(slots, {idx = i, stack = s})
			total = total + s:get_count()
		end
	end
	return slots, total
end

local function fill_grid(recipe)
	local inv = core.get_inventory("current_player")
	if not inv then
		return false
	end

	for i = 1, 9 do
		local needed = recipe.grid[i]
		if needed and not needed:is_empty() then
			local cur = inv.craft[i]
			local cur_count = (cur and not cur:is_empty() and cur:get_name() == needed:get_name()) and cur:get_count() or 0
			local need = needed:get_count()

			if cur_count < need then
				local missing = need - cur_count
				local slots = find_slots(inv, needed:get_name(), missing)
				if not slots then
					return false
				end
				ws.move_stack("current_player", "main", slots[1].idx, "current_player", "craft", i, missing)
			end
		end
	end
	return true
end

local function take_result()
	ws.move_stack("current_player", "craftresult", 1, "current_player", "main", 1, 0)
end

local function capture_recipe()
	local inv = core.get_inventory("current_player")
	if not inv then
		return nil
	end
	local preview = inv.craftpreview and inv.craftpreview[1]
	if not preview or preview:is_empty() then
		return nil
	end
	local key = recipe_key(inv.craft)
	if not RECIPES[key] then
		RECIPES[key] = {grid = {}, output = preview:get_name()}
		for i = 1, 9 do
			local s = inv.craft[i]
			RECIPES[key].grid[i] = (s and not s:is_empty()) and ItemStack(s:get_name() .. " " .. s:get_count()) or ItemStack()
		end
		save()
	end
	return key
end

local function step()
	if not is_on() or not ACTIVE_KEY then
		PAUSED = false
		return
	end
	local recipe = RECIPES[ACTIVE_KEY]
	if not recipe then
		ACTIVE_KEY = nil
		return
	end
	local inv = core.get_inventory("current_player")
	if not inv then
		return
	end
	local result = inv.craftresult and inv.craftresult[1]
	if result and not result:is_empty() then
		take_result()
	end
	if not grids_match(recipe.grid, inv.craft) then
		if PAUSED then
			if fill_grid(recipe) then
				PAUSED = false
			end
			return
		end
		if not fill_grid(recipe) then
			PAUSED = true
			msg(recipe.output .. " [OUT OF INGREDIENTS]")
			ws.notify("Autocraft: " .. recipe.output .. " out of ingredients", ws.NOTIFY_WARNING, {chat = false})
			return
		end
	end
	local act = InventoryAction("craft")
	act:craft("current_player")
	act:set_count(1)
	act:apply()
end

core.register_globalstep(function(dtime)
	local on = is_on()
	if on ~= WAS_ON then
		WAS_ON = on
		if on then
			if ACTIVE_KEY then
				local r = RECIPES[ACTIVE_KEY]
				msg((r and r.output or ACTIVE_KEY) .. " [ACTIVE]")
			else
				msg("ON. Open /autocraft to set a recipe.")
			end
		else
			if ACTIVE_KEY then
				local r = RECIPES[ACTIVE_KEY]
				msg((r and r.output or ACTIVE_KEY) .. " [STOPPED]")
			else
				msg("OFF")
			end
			PAUSED = false
			TIMER = 0
		end
	end
	if on and ACTIVE_KEY then
		TIMER = TIMER + dtime
		if TIMER >= INTERVAL then
			TIMER = 0
			step()
		end
	end
end)

-- Recipe detector: polls craft grid for changes (throttled)
local LAST_GRID = {}
local detect_timer = 0
core.register_globalstep(function(dtime)
	detect_timer = detect_timer + dtime
	if detect_timer < 0.2 then return end
	detect_timer = 0

	local inv = core.get_inventory("current_player")
	if not inv then
		return
	end
	local changed = false
	for i = 1, 9 do
		local cur = inv.craft[i]
		local prev = LAST_GRID[i]
		local cn = cur and not cur:is_empty() and cur:get_name() or ""
		local pn = prev and not prev:is_empty() and prev:get_name() or ""
		if cn ~= pn then
			changed = true
		end
		LAST_GRID[i] = cur
	end
	if changed then
		local preview = inv.craftpreview and inv.craftpreview[1]
		if preview and not preview:is_empty() then
			capture_recipe()
		end
	end
end)

-- Builds only the autocraft GUI content (no formspec chrome).
-- Used both for the standalone formspec and when embedded as an inventory tab.
function autocraft.build_gui_content()
	local on = is_on()
	local sel = ACTIVE_KEY and RECIPES[ACTIVE_KEY]
	local output = (sel and sel.output) or "-"

	local sb = al_formspec.new()
	sb:add(
		al_formspec.label(2.25, 0.375, "Autocraft"),
		al_formspec.label(0.375, 0.375, "Recipe: " .. output),
		"list[current_player;craft;2.25,0.75;3,3;]",
		"image[6.125,2;1.5,1;gui_crafting_arrow.png]",
		"list[current_player;craftpreview;8.2,2;1,1;]",
		"list[current_player;main;0.375,5.1;9,3;9]",
		"list[current_player;main;0.375,9.05;9,1;]",
		"listring[current_player;craft]",
		"listring[current_player;main]",
		al_formspec.button(6.1, 3.4, 2.5, 0.8, "autocraft_toggle",
			on and "Autocraft: ON" or "Autocraft: OFF"),
		al_formspec.button(6.1, 4.25, 2.5, 0.8, "show_recipes", "Recipes")
	)
	return sb:get()
end

local function autocraft_show_standalone()
	local sb = al_formspec.begin("size[11.75,10.425]")
	sb:add(autocraft.build_gui_content())
	return core.show_formspec("autocraft:gui", sb:get())
end

local autocraft_redraw = autocraft_show_standalone

-- Redirect where autocraft re-renders itself. The inventory tab sets this to
-- re-show the tab page instead of the standalone formspec.
function autocraft.set_redraw(fn)
	autocraft_redraw = fn or autocraft_show_standalone
end

local function show_gui()
	return autocraft_redraw()
end

local function show_list()
	local count = 0
	for _ in pairs(RECIPES) do
		count = count + 1
	end
	if count == 0 then
		msg("No recipes yet. Open /autocraft and place items on the grid.")
		return
	end

	-- Build filtered list
	local filtered = {}
	for key, recipe in pairs(RECIPES) do
		if recipe_filter ~= "" then
			local label = recipe.output or key
			local match = ws.fuzzy_match(label, recipe_filter)
			if not match then
				for i = 1, 9 do
					local s = recipe.grid[i]
					if s and not s:is_empty() and ws.fuzzy_match(s:get_name(), recipe_filter) then
						match = true
						break
					end
				end
			end
			if not match then
				-- skip
			else
				table.insert(filtered, {key = key, recipe = recipe})
			end
		else
			table.insert(filtered, {key = key, recipe = recipe})
		end
	end

	local h = math.min(#filtered, 12)
	local sb = al_formspec.cheat_form_begin("size[9," .. (3 + h) .. ",true]")
	sb:add(
		al_formspec.searchbar(0, 0, 8.5, "rfilter", { default = recipe_filter }),
		al_formspec.label(0, 0.9, "Known Recipes (" .. #filtered .. "/" .. count .. ")")
	)

	local y = 1.5
	for _, entry in ipairs(filtered) do
		local key = entry.key
		local recipe = entry.recipe
		local btn = "sel|" .. key
		local sel = ACTIVE_KEY == key
		local lb = sel and ">" or " "
		sb:add(al_formspec.button(0, y, 1.5, 0.7, btn, lb))
		local label = recipe.output or key
		local details = {}
		for i = 1, 9 do
			local s = recipe.grid[i]
			if s and not s:is_empty() then
				table.insert(details, s:get_name())
			end
		end
		if #details > 0 then
			label = label .. "  (" .. table.concat(details, ", ") .. ")"
		end
		if #label > 45 then
			label = label:sub(1, 45) .. ".."
		end
		sb:add(al_formspec.label(1.7, y, label))
		y = y + 0.8
	end
	sb:add(al_formspec.button(3.5, y + 0.3, 2, 0.8, "__close", "Close"))
	core.show_formspec("autocraft:list", sb:get())
end

-- Handles autocraft GUI input. Used by both the standalone formspec
-- ("autocraft:gui") and the inventory tab. Returns true when it consumed the
-- fields.
function autocraft.handle_gui_fields(fields)
	if fields.autocraft_toggle then
		core.settings:set_bool(SETTING, not is_on())
		show_gui()
	elseif fields.show_recipes then
		show_list()
	end
	return true
end

core.register_on_formspec_input(function(formname, fields)
	if formname == "autocraft:gui" then
		autocraft.handle_gui_fields(fields)
	elseif formname == "autocraft:list" then
		if fields.__close then
			return
		end
		if fields.__rfilter_search or (fields.key_enter_field == "rfilter" and fields.rfilter ~= recipe_filter) then
			recipe_filter = fields.rfilter or ""
			show_list()
			return
		end
		for raw in pairs(fields) do
			if raw:find("^sel|") then
				local key = raw:sub(5)
				if RECIPES[key] then
					if ACTIVE_KEY == key then
						ACTIVE_KEY = nil
						msg("deselected")
					else
						ACTIVE_KEY = key
						if is_on() then
							msg((RECIPES[key].output or key) .. " [ACTIVE]")
						end
					end
					show_list()
				end
				return
			end
		end
	end
end)

if core.register_cheat then
	core.register_cheat("Autocraft", {
		category = "Player",
		setting = SETTING,
		description = "Auto-craft items from inventory",
	})
end

core.register_chatcommand("autocraft", {
	description = "Open the autocraft GUI",
	func = show_gui,
})

core.register_chatcommand("autocraft_list", {
	description = "Show known recipes",
	func = show_list,
})

core.register_chatcommand("autocraft_clear", {
	description = "Clear all known recipes",
	func = function()
		RECIPES = {}
		ACTIVE_KEY = nil
		save()
		msg("cleared all recipes")
	end,
})

--
-- Inventory tab (registered directly: the mod loader orders the `inventory`
-- mod before autocraft because autocraft optionally depends on it)
--

if core.inv_tabs and core.inv_tabs.register_tab then
	core.inv_tabs.register_tab({
		id = "autocraft",
		title = "Autocraft",
		build = function()
			return autocraft.build_gui_content()
		end,
		handle = function(fields)
			return autocraft.handle_gui_fields(fields)
		end,
		-- The GUI draws the craft grid and the player inventory itself.
		show_inventory = false,
	})
	-- Re-render inside the tab page when autocraft asks to redraw, falling
	-- back to the standalone formspec when the tab isn't open.
	autocraft.set_redraw(function()
		if core.inv_tabs.is_open() then
			core.inv_tabs.set_active("autocraft")
		else
			autocraft_show_standalone()
		end
	end)
end
