-- Antilua generalized inventory tab framework.
--
-- Lets client mods register extra tabs on the player inventory formspec.
-- The server's own inventory formspec stays the default "main" tab.
-- Integrates with native tab systems when present:
--   * mineclone*: mcl_inventory survival tab row (crafting_creative_* images)
--   * minetest_game: sfinv tabheader (sfinv_nav_tabs)
--   * anything else: a generic tab bar rendered above the form
--
-- Native tab clicks are forwarded to the server (which re-sends the
-- inventory formspec); Antilua tabs are rendered and handled locally.
--
-- API (core.inv_tabs):
--   register_tab{ id, title, [icon], build(ctx), [handle(fields)], [active()], [show_inventory] }
--     id             unique tab id (string)
--     title          tab label
--     icon           itemstring used as the tab icon (needed for the
--                    mineclone*/generic image tab rows; optional otherwise)
--     build(ctx)     returns the tab's formspec content string
--     handle(fields) optional; return true to swallow fields (not forwarded)
--     active()       optional; default true
--     show_inventory optional; whether to draw the player's main inventory
--                    under the tab content (default true)
--   get_tabs() / get_active() / set_active(id) / get_game() / is_open()

local F = core.formspec_escape

local invtabs = {}

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local tabs = {}
local tabs_by_id = {}

local state = {
	formname = "al_inv",
	form_open = false,
	game = nil,
	integration = nil,
	raw = "",
	active = "main",
}

local function get_game()
	if state.game then
		return state.game
	end
	if core.get_item_def("mcl_core:stone") then
		state.game = "mineclone"
	elseif core.get_item_def("default:stone") then
		state.game = "minetest"
	else
		state.game = "unknown"
	end
	return state.game
end

-- ---------------------------------------------------------------------------
-- Generalized right-side sub-tab system
-- ---------------------------------------------------------------------------
-- Vertical sub-tab buttons rendered along the right edge of a form, used by
-- inventory tabs whose own UI has sub-views (openInv, schembuilder). The
-- buttons sit clear of the Antilua inventory tab bar at the top.

core.al_subtabs = {}

local subtab_counter = 0

function core.al_subtabs.new(opts)
	subtab_counter = subtab_counter + 1
	local group = {
		id = opts.id or ("al_subtab" .. subtab_counter),
		labels = opts.labels or {},
		current = opts.current or 0,
	}

	-- Tab column geometry for a given page width. Buttons are wide enough for
	-- their labels; the content reflows to `content_right` so nothing is
	-- covered by the column.
	function group.layout(width)
		local tab_w = math.min(2.5, width * 0.21)
		local tab_x = width - tab_w - 0.1
		local content_right = tab_x - 0.15
		return { tab_w = tab_w, tab_x = tab_x, content_right = content_right }
	end

	-- Vertical sub-tab buttons for the right side. A slightly smaller font
	-- keeps the longer labels (e.g. "Browse Schematics") inside the buttons
	-- with a visible left margin.
	function group.render(width, height)
		local lay = group.layout(width)
		local parts = {}
		for i, label in ipairs(group.labels) do
			local id = "al_subtab_" .. group.id .. "_" .. (i - 1)
			parts[#parts + 1] = "style[" .. id .. ";font_size=*0.85]"
				.. "button[" .. lay.tab_x .. "," .. (0.4 + (i - 1) * 1.0) .. ";"
				.. lay.tab_w .. ",0.9;" .. id .. ";"
				.. core.formspec_escape(label) .. "]"
		end
		return table.concat(parts)
	end

	-- If a sub-tab button was clicked, update the current index and return it;
	-- otherwise return nil.
	function group.handle(fields)
		for i = 1, #group.labels do
			if fields["al_subtab_" .. group.id .. "_" .. (i - 1)] then
				group.current = i - 1
				return group.current
			end
		end
		return nil
	end

	function group.set(i)
		group.current = i
	end

	function group.get()
		return group.current
	end

	return group
end

-- ---------------------------------------------------------------------------
-- Tab content padding
-- ---------------------------------------------------------------------------
-- Tabs that manage their own layout (e.g. the sub-tab system) opt out via
-- `pad = false`; everything else gets a small margin so content isn't flush
-- against the form edges / inventory tab bar.

local function pad_content(def, content)
	if def.pad == false then
		return content
	end
	return "container[0.25,0.25]" .. content .. "container_end[]"
end

-- ---------------------------------------------------------------------------
-- Formspec parsing helpers
-- ---------------------------------------------------------------------------

-- Splits s on sep, ignoring separators escaped with a backslash.
local function split_unescaped(s, sep)
	local parts = {}
	local start = 1
	for i = 1, #s do
		if s:sub(i, i) == sep then
			local p = i - 1
			local b = 0
			while p >= 1 and s:sub(p, p) == "\\" do
				b = b + 1
				p = p - 1
			end
			if b % 2 == 0 then
				parts[#parts + 1] = s:sub(start, i - 1)
				start = i + 1
			end
		end
	end
	parts[#parts + 1] = s:sub(start)
	return parts
end

-- Returns all top-level formspec elements: { name, params, start, finish }
local function fs_elements(fs)
	local els = {}
	local i, n = 1, #fs
	while i <= n do
		local ob = fs:find("%[", i)
		if not ob then
			break
		end
		local name = fs:sub(i, ob - 1)
		local cb
		local j = ob + 1
		while j <= n do
			if fs:sub(j, j) == "]" then
				local p, b = j - 1, 0
				while p >= 1 and fs:sub(p, p) == "\\" do
					b = b + 1
					p = p - 1
				end
				if b % 2 == 0 then
					cb = j
					break
				end
			end
			j = j + 1
		end
		if cb then
			els[#els + 1] = { name = name, params = fs:sub(ob + 1, cb - 1), start = i, finish = cb }
			i = cb + 1
		else
			els[#els + 1] = { name = name, params = fs:sub(ob + 1), start = i }
			break
		end
	end
	return els
end

local function extract_size(fs)
	for _, el in ipairs(fs_elements(fs)) do
		if el.name == "size" then
			local p = split_unescaped(el.params, ",")
			local w, h = tonumber(p[1]), tonumber(p[2])
			if w and h then
				return { w = w, h = h }
			end
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Shared tab-row block builder (mineclone*-style image tabs at negative-Y)
-- ---------------------------------------------------------------------------

local function row_tab_block(id, title, icon, index, active)
	local x_img = 0.2 + (index - 1) * 1.6
	local x_btn = 0.44 + (index - 1) * 1.6
	local bg = active and "crafting_creative_active.png" or "crafting_creative_inactive.png"
	if icon and icon ~= "" then
		return table.concat({
			"style[" .. id .. ";border=false;bgimg=;bgimg_pressed=;noclip=true]",
			"image[" .. x_img .. ",-1.34;1.5,1.44;" .. bg .. "]",
			"item_image_button[" .. x_btn .. ",-1.1;1,1;" .. icon .. ";" .. id .. ";]",
			"tooltip[" .. id .. ";" .. F(title) .. "]",
		})
	end
	return table.concat({
		"style[" .. id .. ";border=false;bgimg=" .. bg .. ";bgimg_pressed=" .. bg .. ";noclip=true]",
		"button[" .. x_img .. ",-1.34;1.5,1.44;" .. id .. ";" .. F(title) .. "]",
	})
end

-- ---------------------------------------------------------------------------
-- mineclone* integration (mcl_inventory survival tab row)
-- ---------------------------------------------------------------------------

local mineclonia = {}

function mineclonia.detect(fs)
	return fs:find("size[11.75,10.9]", 1, true) ~= nil
end

local function extract_native_tabs(fs)
	local native = {}
	local pending_active = false
	for _, el in ipairs(fs_elements(fs)) do
		if el.name == "image" then
			if el.params:find("crafting_creative_", 1, true)
					and el.params:find("-1.34", 1, true) then
				pending_active = el.params:find("crafting_creative_active", 1, true) ~= nil
			end
		elseif el.name == "item_image_button" then
			local p = split_unescaped(el.params, ";")
			local btn = p[4]
			if btn and btn:find("^tab_") then
				native[#native + 1] = {
					id = btn:sub(5),
					icon = p[3] or "",
					title = btn:sub(5),
					active = pending_active,
				}
				pending_active = false
			end
		end
	end
	for _, el in ipairs(fs_elements(fs)) do
		if el.name == "tooltip" then
			local p = split_unescaped(el.params, ";")
			local btn = p[1]
			if btn and btn:find("^tab_") then
				local id = btn:sub(5)
				for _, t in ipairs(native) do
					if t.id == id then
						t.title = p[2] or t.title
						break
					end
				end
			end
		end
	end
	return native
end

function mineclonia.wrap(fs, ctx)
	local native = extract_native_tabs(fs)
	local parts = {}
	local i = #native
	-- The server only renders its tab row when more than one survival tab
	-- exists; otherwise add an explicit active "Main" button so the current
	-- (server inventory) view stays visible in the tab bar.
	if #native == 0 then
		i = i + 1
		parts[#parts + 1] = row_tab_block("al_tab_main", "Main", nil, i, true)
	end
	for _, def in ipairs(ctx.tabs) do
		if def.active() then
			i = i + 1
			parts[#parts + 1] = row_tab_block("al_tab_" .. def.id, def.title, def.icon, i, false)
		end
	end
	if #parts == 0 then
		return fs
	end
	return fs .. table.concat(parts)
end

function mineclonia.page(fs, ctx)
	local def = ctx.def
	local bar_parts = {}
	local i = 0
	local native = extract_native_tabs(fs)
	-- The server only renders its tab row when more than one survival tab
	-- exists; otherwise add an explicit "Main" button so the player can get
	-- back to the server's inventory from an Antilua tab.
	if #native == 0 then
		i = i + 1
		bar_parts[#bar_parts + 1] = row_tab_block("al_tab_main", "Main", nil, i, false)
	end
	for _, t in ipairs(native) do
		i = i + 1
		bar_parts[#bar_parts + 1] = row_tab_block("tab_" .. t.id, t.title, t.icon, i, false)
	end
	for _, d in ipairs(ctx.tabs) do
		if d.active() then
			i = i + 1
			bar_parts[#bar_parts + 1] = row_tab_block("al_tab_" .. d.id, d.title, d.icon, i, ctx.active == d.id)
		end
	end
	local inv = ""
	if def.show_inventory then
		inv = table.concat({
			ws.get_itemslot_bg_v4(0.375, 5.575, 9, 3),
			"list[current_player;main;0.375,5.575;9,3;9]",
			ws.get_itemslot_bg_v4(0.375, 9.525, 9, 1),
			"list[current_player;main;0.375,9.525;9,1;]",
			"listring[current_player;main]",
		})
	end
	ctx.height = 10.9
	ctx.width = 11.75
	return table.concat({
		"formspec_version[6]",
		"size[11.75,10.9]",
		inv,
		pad_content(def, def.build(ctx)),
		table.concat(bar_parts),
	})
end

function mineclonia.resolve(fields)
	if fields["al_tab_main"] ~= nil then
		return "main"
	end
	for _, t in ipairs(extract_native_tabs(state.raw)) do
		if fields["tab_" .. t.id] ~= nil then
			return "native"
		end
	end
	for _, def in ipairs(tabs) do
		if fields["al_tab_" .. def.id] ~= nil then
			return def.id
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- minetest_game integration (sfinv tabheader)
-- ---------------------------------------------------------------------------

local sfinv = {}

function sfinv.detect(fs)
	return fs:find("sfinv_nav_tabs", 1, true) ~= nil
end

local function parse_tabheader(fs)
	for _, el in ipairs(fs_elements(fs)) do
		if el.name == "tabheader" then
			local p = split_unescaped(el.params, ";")
			if p[2] == "sfinv_nav_tabs" then
				return el, p
			end
		end
	end
	return nil
end

local function tabheader_titles(p)
	return split_unescaped(p[3] or "", ",")
end

local function build_tabheader(p, titles, current)
	local parts = { p[1], p[2], table.concat(titles, ","), tostring(current) }
	for k = 5, #p do
		parts[#parts + 1] = p[k]
	end
	return "tabheader[" .. table.concat(parts, ";") .. "]"
end

local function sfinv_titles_with_ours(ctx, current_out)
	local el, p = parse_tabheader(state.raw)
	local titles = {}
	if p then
		titles = tabheader_titles(p)
	end
	local current = p and (tonumber(p[4]) or 1) or 1
	for _, def in ipairs(ctx.tabs) do
		if def.active() then
			if def.id == ctx.active then
				current = #titles + 1
			end
			titles[#titles + 1] = F(def.title)
		end
	end
	current_out[1] = current
	return el, p, titles, current
end

function sfinv.wrap(fs, ctx)
	local el, p, titles, current = sfinv_titles_with_ours(ctx, {})
	if not el then
		return fs
	end
	return fs:sub(1, el.start - 1) .. build_tabheader(p, titles, current) .. fs:sub(el.finish + 1)
end

function sfinv.page(fs, ctx)
	local def = ctx.def
	local size = extract_size(fs) or { w = 8, h = 9 }
	local el, p, titles, current = sfinv_titles_with_ours(ctx, {})
	local tabhead = el and build_tabheader(p, titles, current) or ""
	local inv = ""
	if def.show_inventory then
		inv = "list[current_player;main;0,5.2;8,1;]"
			.. "list[current_player;main;0,6.35;8,3;8]"
			.. "listring[current_player;main]"
	end
	ctx.height = size.h
	ctx.width = size.w
	return table.concat({
		"size[" .. size.w .. "," .. size.h .. "]",
		tabhead,
		pad_content(def, def.build(ctx)),
		inv,
	})
end

function sfinv.resolve(fields)
	local idx = tonumber(fields.sfinv_nav_tabs)
	if not idx then
		return nil
	end
	local native_count = 0
	local p = parse_tabheader(state.raw)
	if p then
		native_count = #tabheader_titles(p)
	end
	if idx >= 1 and idx <= native_count then
		return "native"
	end
	local count = 0
	for _, def in ipairs(tabs) do
		if def.active() then
			count = count + 1
			if count == idx - native_count then
				return def.id
			end
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Generic integration (no native tab system)
-- ---------------------------------------------------------------------------

local generic = {}

local function generic_bar(ctx)
	local entries = { { id = "main", title = "Main", icon = nil } }
	for _, def in ipairs(ctx.tabs) do
		if def.active() then
			entries[#entries + 1] = def
		end
	end
	local parts = {}
	for i, e in ipairs(entries) do
		parts[#parts + 1] = row_tab_block("al_tab_" .. e.id, e.title, e.icon, i, ctx.active == e.id)
	end
	return table.concat(parts)
end

function generic.wrap(fs, ctx)
	return fs .. generic_bar(ctx)
end

function generic.page(fs, ctx)
	local def = ctx.def
	local size = extract_size(fs) or { w = 8, h = 9 }
	local inv = ""
	if def.show_inventory then
		inv = table.concat({
			"list[current_player;main;0.5," .. (size.h - 4.2) .. ";9,3;9]",
			"list[current_player;main;0.5," .. (size.h - 0.95) .. ";9,1;]",
			"listring[current_player;main]",
		})
	end
	ctx.height = size.h
	ctx.width = size.w
	return table.concat({
		"formspec_version[6]",
		"no_prepend[]",
		"size[" .. size.w .. "," .. size.h .. "]",
		"bgcolor[#000000cc;true]",
		inv,
		pad_content(def, def.build(ctx)),
		generic_bar(ctx),
	})
end

function generic.resolve(fields)
	if fields["al_tab_main"] ~= nil then
		return "main"
	end
	for _, def in ipairs(tabs) do
		if fields["al_tab_" .. def.id] ~= nil then
			return def.id
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Integration selection
-- ---------------------------------------------------------------------------

local function select_integration(fs)
	-- Sniff the native tab system from the formspec itself; this is robust
	-- to a stale game cache across reconnects. The mineclone* creative
	-- inventory (size[13,...]) never matches the survival detection below,
	-- so a real mineclone survival formspec always lands on `mineclonia`.
	if mineclonia.detect(fs) then
		return mineclonia
	end
	if sfinv.detect(fs) then
		return sfinv
	end
	-- Mineclone* but not the survival inventory (e.g. creative mode):
	-- pass through and let the native form handle everything.
	if get_game() == "mineclone" then
		return nil
	end
	return generic
end

-- ---------------------------------------------------------------------------
-- Rendering pipeline
-- ---------------------------------------------------------------------------

local function build_form()
	local int = state.integration
	if not int then
		return state.raw
	end
	local ctx = {
		active = state.active,
		tabs = tabs,
		def = tabs_by_id[state.active],
	}
	if state.active == "main" then
		return int.wrap(state.raw, ctx)
	end
	if not ctx.def then
		state.active = "main"
		return int.wrap(state.raw, ctx)
	end
	return int.page(state.raw, ctx)
end

local function reshow()
	if not state.form_open then
		return
	end
	core.show_formspec(state.formname, build_form())
end

local function handle_fields(formname, fields)
	if formname ~= state.formname then
		return
	end
	local int = state.integration
	local res = int and int.resolve(fields) or nil
	if res == "native" then
		state.active = "main"
		core.send_inventory_fields("", fields)
		return
	end
	if type(res) == "string" then
		if res == "main" or tabs_by_id[res] then
			state.active = res
		end
		reshow()
		return
	end
	-- Route to the active tab first: `button_exit` elements deliver their
	-- action together with `quit`, so the action must be processed before
	-- treating the submission as a plain form close.
	local def = tabs_by_id[state.active]
	if def and def.handle then
		if def.handle(fields) then
			if fields.quit then
				state.form_open = false
			end
			return
		end
	end
	if fields.quit then
		state.form_open = false
		return
	end
	core.send_inventory_fields("", fields)
end

-- ---------------------------------------------------------------------------
-- Hook registration
-- ---------------------------------------------------------------------------

core.register_on_receiving_inventory_form(function(formname, formspec)
	if formname ~= "" then
		return formspec
	end
	state.raw = formspec
	state.integration = select_integration(formspec)
	if not state.integration and state.form_open then
		state.form_open = false
		core.close_formspec(state.formname)
	end
	if state.form_open then
		reshow()
	end
	return formspec
end)

core.register_on_inventory_open(function()
	local int = state.integration
	if int and state.raw ~= "" then
		state.form_open = true
		core.show_formspec(state.formname, build_form())
		return true
	end
	return false
end)

core.register_on_formspec_input(function(formname, fields)
	handle_fields(formname, fields)
end)

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

function invtabs.register_tab(def)
	assert(def and def.id and def.title, "invtabs.register_tab: id and title required")
	assert(type(def.build) == "function", "invtabs.register_tab: build function required")
	if tabs_by_id[def.id] then
		error("invtabs.register_tab: tab already registered: " .. def.id, 2)
	end
	if def.active == nil then
		def.active = function() return true end
	end
	if def.handle == nil then
		def.handle = function() end
	end
	if def.show_inventory == nil then
		def.show_inventory = true
	end
	tabs[#tabs + 1] = def
	tabs_by_id[def.id] = def
	if state.form_open then
		reshow()
	end
end

function invtabs.get_tabs()
	local out = {}
	for _, def in ipairs(tabs) do
		out[#out + 1] = {
			id = def.id,
			title = def.title,
			active = def.active(),
		}
	end
	return out
end

function invtabs.get_active()
	return state.active
end

function invtabs.remove_tab(id)
	local def = tabs_by_id[id]
	if not def then
		return false
	end
	for i, d in ipairs(tabs) do
		if d == def then
			table.remove(tabs, i)
			break
		end
	end
	tabs_by_id[id] = nil
	if state.active == id then
		state.active = "main"
		if state.form_open then
			reshow()
		end
	end
	return true
end

function invtabs.set_active(id)
	if id ~= "main" and not tabs_by_id[id] then
		return false
	end
	state.active = id
	if state.form_open then
		reshow()
	end
	return true
end

function invtabs.get_game()
	return get_game()
end

function invtabs.is_open()
	return state.form_open
end

-- Test/debug hook: build the wrapped formspec for an arbitrary raw server
-- formspec without opening the inventory. Returns the wrapped string.
-- Does not mutate the framework's runtime state.
-- `forced` optionally pins the integration: "mineclonia", "sfinv",
-- "generic", or nil/"auto" to auto-detect from the formspec and game.
function invtabs._build(formspec, active, forced)
	local saved = {
		raw = state.raw,
		integration = state.integration,
		active = state.active,
	}
	state.raw = formspec
	if forced == "mineclonia" then
		state.integration = mineclonia
	elseif forced == "sfinv" then
		state.integration = sfinv
	elseif forced == "generic" then
		state.integration = generic
	else
		state.integration = select_integration(formspec)
	end
	state.active = active or "main"
	local out = build_form()
	state.raw = saved.raw
	state.integration = saved.integration
	state.active = saved.active
	return out
end

-- Test/debug hook: simulate formspec input to the inventory tab form.
function invtabs._handle(fields)
	handle_fields(state.formname, fields)
end

-- Test/debug hook: expose internal state for diagnostics.
function invtabs._debug()
	local int_name = "nil"
	if state.integration == mineclonia then int_name = "mineclonia"
	elseif state.integration == sfinv then int_name = "sfinv"
	elseif state.integration == generic then int_name = "generic" end
	return {
		game = get_game(),
		integration = int_name,
		raw_len = #state.raw,
		raw_head = state.raw:sub(1, 160),
		active = state.active,
		form_open = state.form_open,
	}
end

core.inv_tabs = invtabs

return invtabs
