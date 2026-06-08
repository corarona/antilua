poi = {}
local storage = minetest.get_mod_storage("poi")
local info = minetest.get_server_info()
local stprefix = "POI-" .. info.address .. "-"

local DISTANCE_NEAR = 256

local formspec_list = {}
local selected_name
local hud_wp
local shown_huds = {}
local lpos
local sort_by_distance = false

local WP_COLORS = {
	{ name = "Green",  hex = "00ff00" },
	{ name = "Red",    hex = "ff0000" },
	{ name = "Blue",   hex = "0000ff" },
	{ name = "Yellow", hex = "ffff00" },
	{ name = "Cyan",   hex = "00ffff" },
	{ name = "Magenta",hex = "ff00ff" },
	{ name = "White",  hex = "ffffff" },
}

poi.registered_transports = {}
poi.speed = 0
poi.last_name = nil
poi.last_pos = nil

--
-- Internal helpers
--

local function update_speed()
	if not minetest.localplayer then return end
	local cpos = minetest.localplayer:get_pos()
	if lpos and cpos then
		poi.speed = ws.round2(vector.distance(cpos, lpos), 2)
	end
	lpos = cpos
end

local function calculate_eta(tpos)
	local dst = vector.distance(ws.dircoord(0, 0, 0), tpos)
	if poi.speed == 0 then return -1 end
	return ws.round2(dst / poi.speed / 60, 2)
end

--
-- Public API: waypoint storage
--

local function full_key(name)
	return stprefix .. tostring(name)
end

local function color_key(name)
	return stprefix .. tostring(name) .. "_color"
end

function poi.get_color(name)
	return storage:get_string(color_key(name))
end

function poi.set_color(name, color)
	storage:set_string(color_key(name), color)
end

function poi.getwps()
	local wp = {}
	for name, _ in pairs(storage:to_table().fields) do
		if name:sub(1, #stprefix) == stprefix then
			table.insert(wp, name:sub(#stprefix + 1))
		end
	end
	table.sort(wp)
	return wp
end

function poi.set_waypoint(pos, name)
	pos = ws.pos_to_string(pos)
	if not pos then return end
	storage:set_string(full_key(name), pos)
	return true
end

function poi.get_waypoint(name)
	return ws.string_to_pos(storage:get_string(full_key(name)))
end

function poi.delete_waypoint(name)
	storage:set_string(full_key(name), "")
	storage:set_string(color_key(name), "")
end

function poi.rename_waypoint(oldname, newname)
	oldname, newname = tostring(oldname), tostring(newname)
	local pos = poi.get_waypoint(oldname)
	if not pos or not poi.set_waypoint(pos, newname) then return end
	if oldname ~= newname then
		local col = poi.get_color(oldname)
		if col ~= "" then
			poi.set_color(newname, col)
		end
		poi.delete_waypoint(oldname)
	end
	return true
end

function poi.has_wp_near(pos)
	for _, name in ipairs(poi.getwps()) do
		local wpos = poi.get_waypoint(name)
		if wpos and vector.distance(pos, wpos) <= DISTANCE_NEAR then
			return true
		end
	end
end

--
-- Public API: display
--

function poi.color_int(name)
	local hex = poi.get_color(name)
	if hex == "" then hex = "00ff00" end
	return tonumber(hex .. "ff", 16) or 0x00ff00ff
end

function poi.set_hud_wp(pos, title)
	pos = ws.string_to_pos(pos)
	if not pos then return end
	title = title or ws.pos_to_string(pos)
	poi.last_name = title
	poi.last_pos = pos
	local color = poi.color_int(title)
	if shown_huds[title] then
		minetest.localplayer:hud_change(shown_huds[title], "name", title)
		minetest.localplayer:hud_change(shown_huds[title], "world_pos", pos)
		minetest.localplayer:hud_change(shown_huds[title], "number", color)
	else
		hud_wp = minetest.localplayer:hud_add({
			hud_elem_type = "waypoint",
			name = title,
			text = "m",
			number = color,
			world_pos = pos,
		})
	end
	shown_huds[title] = hud_wp
	return true
end

function poi.display(pos, name)
	name = name or ws.pos_to_string(pos)
	pos = ws.string_to_pos(pos)
	poi.set_hud_wp(pos, name)
	return true
end

function poi.display_waypoint(name)
	local pos = poi.get_waypoint(name)
	if not pos then return end
	poi.last_name = name
	poi.last_pos = pos
	ws.aim(poi.last_pos)
	poi.display(pos, name)
	return true
end

function poi.get_nearest_name()
	local nearest, odst = nil, 500
	local lp = minetest.localplayer:get_pos()
	for _, name in ipairs(poi.getwps()) do
		local wpos = poi.get_waypoint(name)
		if wpos then
			local dst = vector.distance(lp, wpos)
			if dst < odst then
				odst = dst
				nearest = name
			end
		end
	end
	return nearest or poi.get_quad()
end

function poi.get_quad()
	local lp = minetest.localplayer:get_pos()
	local quad = lp.z < 0 and "South" or "North"
	return lp.x < 0 and quad .. "-west" or quad .. "-east"
end

--
-- Transport system
--

function poi.register_transport(name, func)
	table.insert(poi.registered_transports, { name = name, func = func })
end

--
-- Death handling
--

local function trim_death_waypoints(max)
	local prefix = "Death - "
	local death_wps = {}
	for _, name in ipairs(poi.getwps()) do
		if name:sub(1, #prefix) == prefix then
			table.insert(death_wps, name)
		end
	end
	table.sort(death_wps)
	while #death_wps > max do
		poi.delete_waypoint(death_wps[1])
		table.remove(death_wps, 1)
	end
end

minetest.register_on_death(function()
	if not minetest.localplayer then return end
	if core.settings:get_bool("auto_death_waypoint", true) then
		local pos = minetest.localplayer:get_pos()
		poi.death_pos = vector.new(pos)
		poi.last_pos = pos
		local name = "Death - " .. os.date("%Y-%m-%d %H:%M")
		poi.last_name = name
		poi.set_waypoint(pos, name)
		poi.display(pos, name)
		poi.set_color(name, "ff0000")
		local max = tonumber(core.settings:get("auto_death_waypoint_max")) or 10
		trim_death_waypoints(max)
	end
	if core.settings:get_bool("death_tp") then
		minetest.after(0.5, function()
			minetest.localplayer:set_pos(poi.death_pos)
			core.after(0.1, function()
				local n = core.get_node_or_nil(poi.death_pos)
				if n and n.name == "bones:bones" then
					ws.dig_node(poi.death_pos)
				end
			end)
		end)
	end
end)

core.register_cheat("DeathWaypoints", {
	category = "Player",
	setting = "auto_death_waypoint",
	description = "Auto-create a waypoint at death location",
})
core.register_cheat("DeathWaypointLimit", {
	category = "Player",
	setting = "auto_death_waypoint_max",
	description = "Max death waypoints to keep",
})
ws.rg("DeathTP", "Player", "death_tp", function() end, function() end, function() end, { "autorespawn" })

--
-- Formspec
--

local function wp_distance(name)
	local pos = poi.get_waypoint(name)
	if not pos then return math.huge end
	local lp = minetest.localplayer:get_pos()
	if not lp then return math.huge end
	return vector.distance(lp, pos)
end

function poi.display_formspec()
	local raw_wps = poi.getwps()
	local parts = {}

	table.insert(parts, "formspec_version[4]")
	table.insert(parts, "size[12,10]")
	table.insert(parts, "no_prepend[]")
	table.insert(parts, "background9[1,1;1,1;blank.png;true;7]")
	table.insert(parts, "bgcolor[#000000AA;false]")
	table.insert(parts, "label[0.25,0.5;Waypoint list]")

	-- Sort waypoints
	local waypoints = raw_wps
	if sort_by_distance then
		table.sort(waypoints, function(a, b)
			return wp_distance(a) < wp_distance(b)
		end)
	end

	-- Build textlist from waypoints
	formspec_list = {}
	local tl_entries = {}
	for id, name in ipairs(waypoints) do
		formspec_list[id] = name
		local entry = name
		if sort_by_distance then
			local d = wp_distance(name)
			if d ~= math.huge then
				entry = entry .. " (" .. math.floor(d) .. "m)"
			end
		end
		table.insert(tl_entries, "##" .. minetest.formspec_escape(entry))
	end
	local tl = "textlist[0.25,0.75;11.5,6;wp_list;"
	tl = tl .. table.concat(tl_entries, ",")
	local sel = 1
	if not selected_name and #waypoints > 0 then
		selected_name = waypoints[1]
	end
	for id, name in ipairs(waypoints) do
		if name == selected_name then sel = id end
	end
	tl = tl .. ";" .. sel .. "]"
	table.insert(parts, tl)

	-- Action buttons
	local sort_label = sort_by_distance and "Dist" or "A-Z"
	table.insert(parts, "button[0.5,7.5;1,0.5;sort_toggle;" .. sort_label .. "]")
	table.insert(parts, "button_exit[1.7,7.5;1,0.5;display;Show]")

	-- Color dropdown (only when a waypoint is selected)
	if selected_name then
		local cur_hex = poi.get_color(selected_name)
		if cur_hex == "" then cur_hex = "00ff00" end
		local sel_idx = 1
		for i, c in ipairs(WP_COLORS) do
			if c.hex == cur_hex then sel_idx = i end
		end
		local color_names = {}
		for _, c in ipairs(WP_COLORS) do
			table.insert(color_names, c.name)
		end
		table.insert(parts, "dropdown[3,7.5;1.8,0.5;wp_color;" .. table.concat(color_names, ",") .. ";" .. sel_idx .. "]")
	end

	table.insert(parts, "button[9,7.5;1.3,0.5;rename;Rename]")
	table.insert(parts, "button[10.5,7.5;1.3,0.5;delete;Delete]")

	-- Waypoint position label
	if selected_name then
		local pos = poi.get_waypoint(selected_name)
		if pos then
			local label = "Waypoint position: "
				.. minetest.formspec_escape(pos.x .. ", " .. pos.y .. ", " .. pos.z)
			table.insert(parts, "label[0.25,7.25;" .. label .. "]")
		end
	else
		table.insert(parts, "button_exit[0,10.5;5.25,0.5;quit;Close dialog]")
		table.insert(parts, "label[0,6.75;No waypoints. Add one with \".wa\".]")
	end

	-- Transport buttons
	local sp, y = 0.5, 8.25
	for _, v in ipairs(poi.registered_transports) do
		table.insert(parts, "button_exit[" .. sp .. "," .. y .. ";1,0.5;" .. v.name .. ";" .. v.name .. "]")
		sp = sp + 1
		if sp > 10 then
			y = y + 0.75
			sp = 0.5
		end
	end

	return minetest.show_formspec("poi-csm", table.concat(parts))
end

--
-- Globalstep (speed/ETA)
--

local speed_timer = 1

minetest.register_globalstep(function(dtime)
	speed_timer = speed_timer - dtime
	if speed_timer > 0 then return end
	speed_timer = 1
	update_speed()
	if poi.last_pos then
		poi.etatime = calculate_eta(poi.last_pos)
	end
	poi.target = poi.last_pos
	poi.eta = poi.etatime
end)

--
-- Formspec input handler
--

local function show_rename_fs(name)
	return minetest.show_formspec("poi-csm", table.concat({
		"formspec_version[4]",
		"size[6,3]",
		"no_prepend[]",
		"bgcolor[#000000AA;false]",
		"label[0.35,0.2;Rename waypoint]",
		"field[0.3,1.3;6,1;new_name;New name;" .. minetest.formspec_escape(name) .. "]",
		"button[0,2;3,1;cancel;Cancel]",
		"button[3,2;3,1;rename_confirm;Rename]",
	}))
end

local function show_delete_fs(name)
	return minetest.show_formspec("poi-csm", table.concat({
		"formspec_version[4]",
		"size[6,2]",
		"no_prepend[]",
		"bgcolor[#000000AA;false]",
		"label[0.35,0.25;Are you sure you want to delete \"" .. name .. "\"?]",
		"button[0,1;3,1;cancel;Cancel]",
		"button[3,1;3,1;delete_confirm;Delete]",
	}))
end

minetest.register_on_formspec_input(function(formname, fields)
	if formname ~= "poi-csm" then return end

	local name
	if fields.wp_list then
		local event = minetest.explode_textlist_event(fields.wp_list)
		if event.index then
			name = formspec_list[event.index]
		end
	else
		name = selected_name
	end

	if not name then
		if fields.display or fields.delete then
			ws.notify("Please select a waypoint first.", ws.NOTIFY_ERROR)
		end
		return true
	end

	-- Transport buttons
	for _, v in ipairs(poi.registered_transports) do
		if fields[v.name] then
			if v.func(poi.get_waypoint(name), name) then
				ws.notify("Error with " .. v.name, ws.NOTIFY_ERROR)
			end
			return true
		end
	end

	if fields.display then
		if not poi.display_waypoint(name) then
			ws.notify("Error displaying waypoint!", ws.NOTIFY_ERROR)
		end
	elseif fields.sort_toggle then
		sort_by_distance = not sort_by_distance
		poi.display_formspec()
	elseif fields.wp_color then
		local idx = tonumber(fields.wp_color)
		if idx then
			local c = WP_COLORS[idx]
			if c then
				poi.set_color(name, c.hex)
				shown_huds = {}
				if hud_wp then
					minetest.localplayer:hud_remove(hud_wp)
					hud_wp = nil
				end
			end
		end
		poi.display_formspec()
	elseif fields.rename then
		show_rename_fs(name)
	elseif fields.rename_confirm then
		if fields.new_name and #fields.new_name > 0 then
			if poi.rename_waypoint(name, fields.new_name) then
				selected_name = fields.new_name
			else
				ws.notify("Error renaming waypoint!", ws.NOTIFY_ERROR)
			end
		else
			ws.notify("New name required", ws.NOTIFY_ERROR)
		end
		poi.display_formspec()
	elseif fields.delete then
		show_delete_fs(name)
	elseif fields.delete_confirm then
		poi.delete_waypoint(name)
		selected_name = nil
		poi.display_formspec()
	elseif fields.cancel then
		poi.display_formspec()
	elseif name ~= selected_name then
		selected_name = name
		poi.display_formspec()
	end

	return true
end)

--
-- Chat commands
--

minetest.register_chatcommand("waypoints", {
	description = "Open the waypoint GUI",
	func = function() poi.display_formspec() end,
})
ws.register_chatcommand_alias("waypoints", "wp", "wps", "waypoint")

minetest.register_chatcommand("add_waypoint", {
	params = "<pos> <name>",
	description = "Add a waypoint at the given position.",
	func = function(param)
		local s, e = param:find(" ")
		if not s then
			return false, "Usage: .add_waypoint <pos> <name>"
		end
		local pos_str = param:sub(1, s - 1)
		local name = param:sub(e + 1)
		if #name < 1 then
			return false, "Waypoint name cannot be empty."
		end
		return poi.set_waypoint(pos_str, name), "Waypoint added."
	end,
})
ws.register_chatcommand_alias("add_waypoint", "wa", "add_wp")

minetest.register_chatcommand("add_waypoint_here", {
	params = "[name]",
	description = "Mark the current position as a waypoint.",
	func = function(param)
		local pos = minetest.localplayer:get_pos()
		local name
		if tostring(param) ~= "" then
			name = param
		else
			local ts = os.date("%Y-%m-%d_%H-%M")
			local node = minetest.get_node(vector.offset(pos, 0, -1, 0))
			local hint = (node and node.name:match(":(.+)$")) or "waypoint"
			name = hint .. "_" .. ts
		end
		return poi.set_waypoint(pos, name), "Waypoint added."
	end,
})
ws.register_chatcommand_alias("add_waypoint_here", "wah", "add_wph")

minetest.register_chatcommand("clear_waypoint", {
	description = "Hide the displayed waypoint.",
	func = function()
		if poi.flying then poi.flying = false end
		if hud_wp then
			minetest.localplayer:hud_remove(hud_wp)
			hud_wp = nil
			shown_huds = {}
			return true, "Waypoint hidden."
		end
		return false, "No waypoint is currently displayed."
	end,
})
ws.register_chatcommand_alias("clear_waypoint", "cwp", "cls")

minetest.register_chatcommand("wpdisplay", {
	params = "<pos> <name>",
	description = "Display a waypoint at the given position.",
	func = function(pos, name)
		poi.display(pos, name)
	end,
})
ws.register_chatcommand_alias("wpdisplay", "wpd")

minetest.register_chatcommand("dump_pois", {
	description = "Debug: print all stored waypoints.",
	func = function()
		for name, pos in pairs(storage:to_table().fields) do
			minetest.log(name .. " : " .. pos)
		end
	end,
})

--
-- Cheat registrations
--

core.register_cheat("ShowNames", { category = "Render", setting = "poi_shownames" })
core.register_cheat("POIs", { category = "Misc", func = poi.display_formspec })

core.register_on_death(function()
	if not core.settings:get_bool("auto_screenshot") then return end
	core.after(0.5, function()
		core.make_screenshot()
		ws.notify("Screenshot saved", ws.NOTIFY_INFO, { toast = false })
	end)
end)

core.register_cheat("AutoScreenshot", {
	category = "Player",
	setting = "auto_screenshot",
	description = "Auto-screenshot on death",
})
