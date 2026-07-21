poi = {}
local storage = core.get_mod_storage("poi")
local stprefix = "POI-singleplayer:"

if core.settings:get("poi_show_all_waypoints") == nil then
	core.settings:set("poi_show_all_waypoints", "false")
end

local function show_all_enabled()
	return core.settings:get_bool("poi_show_all_waypoints")
end

local DISTANCE_NEAR = 256

local formspec_list = {}
local selected_name
local hud_wp
local shown_huds = {}
local lpos
local sort_by_distance = false
local filter_group = ""

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

local function reset_gui_state()
	selected_name = nil
	formspec_list = {}
	filter_group = ""
	sort_by_distance = false
	lpos = nil
	for _, id in pairs(shown_huds) do
		if core.localplayer then core.localplayer:hud_remove(id) end
	end
	shown_huds = {}
	if hud_wp then
		if core.localplayer then core.localplayer:hud_remove(hud_wp) end
		hud_wp = nil
	end
end

core.register_on_connect(function()
	local info = core.get_server_info()
	if info and info.address and info.address ~= "" then
		stprefix = "POI-" .. info.address .. ":" .. info.port .. ":"
	else
		stprefix = "POI-singleplayer:"
	end
	reset_gui_state()
end)

core.register_on_disconnect(function()
	reset_gui_state()
end)

--
-- Internal helpers
--

local function update_speed()
	if not core.localplayer then return end
	local cpos = core.localplayer:get_pos()
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
	if show_all_enabled() and name:find(":") then
		return "POI-" .. tostring(name)
	end
	return stprefix .. tostring(name)
end

local function color_key(name)
	if show_all_enabled() and name:find(":") then
		return "POI-" .. tostring(name) .. "_color"
	end
	return stprefix .. tostring(name) .. "_color"
end

local function group_key(name)
	if show_all_enabled() and name:find(":") then
		return "POI-" .. tostring(name) .. "_group"
	end
	return stprefix .. tostring(name) .. "_group"
end

function poi.get_color(name)
	return storage:get_string(color_key(name))
end

function poi.set_color(name, color)
	storage:set_string(color_key(name), color)
end

function poi.get_group(name)
	return storage:get_string(group_key(name))
end

function poi.set_group(name, group)
	storage:set_string(group_key(name), group or "")
end

function poi.getwps()
	local prefix = show_all_enabled() and "POI-" or stprefix
	local wp = {}
	for name, _ in pairs(storage:to_table().fields) do
		if name:sub(1, #prefix) == prefix then
			local short = name:sub(#prefix + 1)
			if not short:match("_ss$") and not short:match("_color$") and not short:match("_group$") then
				table.insert(wp, short)
			end
		end
	end
	table.sort(wp)
	return wp
end

function poi.set_waypoint(pos, name)
	pos = ws.pos_to_string(pos)
	if not pos then return end
	storage:set_string(full_key(name), pos)
	local ss = core.make_screenshot()
	if ss and ss ~= "" then
		storage:set_string(stprefix .. tostring(name) .. "_ss", ss)
	end
	return true
end

function poi.get_waypoint(name)
	return ws.string_to_pos(storage:get_string(full_key(name)))
end

function poi.delete_waypoint(name)
	storage:set_string(full_key(name), "")
	storage:set_string(color_key(name), "")
	storage:set_string(group_key(name), "")
	storage:set_string(stprefix .. tostring(name) .. "_ss", "")
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
		local grp = poi.get_group(oldname)
		if grp ~= "" then
			poi.set_group(newname, grp)
		end
		poi.delete_waypoint(oldname)
	end
	return true
end

function poi.check_vector(v)
	if type(v) ~= "table" then return false end
	return type(v.x) == "number" and type(v.y) == "number" and type(v.z) == "number"
		and v.x == v.x and v.y == v.y and v.z == v.z
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
	return tonumber(hex, 16) or 0x00ff00
end

function poi.set_hud_wp(pos, title)
	pos = ws.string_to_pos(pos)
	if not pos then return end
	title = title or ws.pos_to_string(pos)
	poi.last_name = title
	poi.last_pos = pos
	local color = poi.color_int(title)
	if shown_huds[title] then
		core.localplayer:hud_change(shown_huds[title], "name", title)
		core.localplayer:hud_change(shown_huds[title], "world_pos", pos)
		core.localplayer:hud_change(shown_huds[title], "number", color)
	else
		hud_wp = core.localplayer:hud_add({
			type = "waypoint",
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
	local lp = core.localplayer:get_pos()
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
	local lp = core.localplayer:get_pos()
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

local death_counter = 0
core.register_on_death(function()
	if not core.localplayer then return end
	local my_death = death_counter
	death_counter = death_counter + 1
	if core.settings:get_bool("auto_death_waypoint", true) then
		local pos = core.localplayer:get_pos()
		poi.death_pos = vector.new(pos)
		poi.last_pos = pos
		local name = "Death - " .. os.date("%Y-%m-%d %H:%M")
		poi.last_name = name
		poi.set_waypoint(pos, name)
		poi.display(pos, name)
		poi.set_color(name, "ff0000")
		poi.set_group(name, "Death")
		local max = tonumber(core.settings:get("auto_death_waypoint_max")) or 10
		trim_death_waypoints(max)
	end
	if core.settings:get_bool("death_tp") then
		local dpos = poi.death_pos and vector.new(poi.death_pos)
		core.after(0.5, function()
			if death_counter ~= my_death + 1 then return end
			core.localplayer:set_pos(dpos)
			core.after(0.1, function()
				if death_counter ~= my_death + 1 then return end
				local n = core.get_node_or_nil(dpos)
				if n and n.name == "bones:bones" then
					ws.dig(dpos)
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
ws.rg("DeathTP", { category = "Player", setting = "death_tp",
	description = "Teleport to death location",
	daughters = { "autorespawn" } })

--
-- Formspec
--

local function wp_distance(name)
	local pos = poi.get_waypoint(name)
	if not pos then return math.huge end
	local lp = core.localplayer:get_pos()
	if not lp then return math.huge end
	return vector.distance(lp, pos)
end

local function get_screenshot(name)
	local prefix = show_all_enabled() and name:find(":") and "POI-" or stprefix
	local ss = storage:get_string(prefix .. tostring(name) .. "_ss")
	return (ss ~= "") and ss or nil
end

local function get_unique_groups()
	local prefix = show_all_enabled() and "POI-" or stprefix
	local groups = {}
	for key, value in pairs(storage:to_table().fields) do
		if key:sub(1, #prefix) == prefix and key:match("_group$") then
			if value and value ~= "" then
				groups[value] = true
			end
		end
	end
	local sorted = {}
	for g in pairs(groups) do
		table.insert(sorted, g)
	end
	table.sort(sorted)
	return sorted
end

--
-- Formspec builders
--

local function get_filtered_sorted_waypoints()
	local wps = poi.getwps()
	if filter_group ~= "" then
		local filtered = {}
		for _, name in ipairs(wps) do
			if poi.get_group(name) == filter_group then
				table.insert(filtered, name)
			end
		end
		wps = filtered
	end
	if sort_by_distance then
		local with_dist = {}
		for i, name in ipairs(wps) do
			with_dist[i] = {name = name, dist = wp_distance(name)}
		end
		table.sort(with_dist, function(a, b) return a.dist < b.dist end)
		wps = {}
		for _, entry in ipairs(with_dist) do
			table.insert(wps, entry.name)
		end
	end
	return wps
end

local function build_header(sb, af)
	sb:add(
		"background9[1,1;1,1;blank.png;true;7]",
		af.label(0.25, 0.5, "Waypoint list")
	)
	sb:add("checkbox[0.25,0.2;poi_show_all;Show all servers;"
		.. (core.settings:get_bool("poi_show_all_waypoints") and "true" or "false") .. "]")
	local groups = get_unique_groups()
	local filter_items = {"All"}
	for _, g in ipairs(groups) do
		table.insert(filter_items, g)
	end
	local filter_sel = 1
	for i, g in ipairs(filter_items) do
		if g == filter_group then filter_sel = i end
	end
	sb:add(af.dropdown(3, 0.25, 2.5, "group_filter", filter_items, filter_sel))
end

local function build_waypoint_list(sb, af, waypoints)
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
		table.insert(tl_entries, "##" .. af.escape(entry))
	end
	local sel = 1
	if not selected_name and #waypoints > 0 then
		selected_name = waypoints[1]
	end
	for id, name in ipairs(waypoints) do
		if name == selected_name then sel = id end
	end
	sb:add("textlist[0.25,0.75;8.5,6;wp_list;" .. table.concat(tl_entries, ",") .. ";" .. sel .. "]")
	if selected_name then
		local ss = get_screenshot(selected_name)
		if ss then
			sb:add(af.image(9.25, 0.75, 3.5, 2.5, ss))
		end
	end
end

local function build_details_panel(sb, af, name)
	if not name then return end
	local pos = poi.get_waypoint(name)
	if pos then
		sb:add(af.label(0.25, 7.25, "Waypoint position: " .. pos.x .. ", " .. pos.y .. ", " .. pos.z))
	end

	local cur_hex = poi.get_color(name)
	if cur_hex == "" then cur_hex = "00ff00" end
	local sel_idx = 1
	for i, c in ipairs(WP_COLORS) do
		if c.hex == cur_hex then sel_idx = i end
	end
	local color_names = {}
	for _, c in ipairs(WP_COLORS) do
		table.insert(color_names, c.name)
	end
	sb:add(af.dropdown(3, 7.5, 1.8, "wp_color", color_names, sel_idx))

	local cur_group = poi.get_group(name)
	sb:add(af.field(5, 7.25, 3.5, 0.5, "wp_group", "Group", cur_group))
end

local function build_actions(sb, af)
	local sort_label = sort_by_distance and "Dist" or "A-Z"
	sb:add(
		af.button(0.5, 7.5, 1, 0.5, "sort_toggle", sort_label),
		af.button_exit(1.7, 7.5, 1, 0.5, "display", "Show"),
		af.button(9, 7.5, 1.3, 0.5, "rename", "Rename"),
		af.button(10.5, 7.5, 1.3, 0.5, "delete", "Delete")
	)
	local sp, y = 0.5, 8.25
	for _, v in ipairs(poi.registered_transports) do
		sb:add(af.button_exit(sp, y, 1, 0.5, v.name, v.name))
		sp = sp + 1
		if sp > 10 then
			y = y + 0.75
			sp = 0.5
		end
	end
end

function poi.display_formspec()
	local af = core.al_formspec
	local sb = af.begin("size[13.5,10]")
	local wps = get_filtered_sorted_waypoints()
	build_header(sb, af)
	build_waypoint_list(sb, af, wps)
	build_details_panel(sb, af, selected_name)
	build_actions(sb, af)
	return core.show_formspec("poi-csm", sb:get())
end

--
-- Globalstep (speed/ETA)
--

local speed_timer = 1

core.register_globalstep(function(dtime)
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
	local af = core.al_formspec
	local sb = af.begin("size[6,3]")
	sb:add(
		af.label(0.35, 0.2, "Rename waypoint"),
		af.field(0.3, 1.3, 6, 1, "new_name", "New name", name),
		af.button(0, 2, 3, 1, "cancel", "Cancel"),
		af.button(3, 2, 3, 1, "rename_confirm", "Rename")
	)
	return core.show_formspec("poi-csm", sb:get())
end

local function show_delete_fs(name)
	local af = core.al_formspec
	local sb = af.begin("size[6,2]")
	sb:add(
		af.label(0.35, 0.25, [[Are you sure you want to delete "]] .. name .. [["?]]),
		af.button(0, 1, 3, 1, "cancel", "Cancel"),
		af.button(3, 1, 3, 1, "delete_confirm", "Delete")
	)
	return core.show_formspec("poi-csm", sb:get())
end

core.register_on_formspec_input(function(formname, fields)
	if formname ~= "poi-csm" then return end

	local handlers = {
		group_filter = function()
			local filter_names = {"All"}
			for _, g in ipairs(get_unique_groups()) do table.insert(filter_names, g) end
			local idx = tonumber(fields.group_filter)
			if idx and filter_names[idx] then
				filter_group = (filter_names[idx] == "All") and "" or filter_names[idx]
				poi.display_formspec()
			end
		end,
		poi_show_all = function()
			core.settings:set_bool("poi_show_all_waypoints", fields.poi_show_all == "true")
			poi.display_formspec()
		end,
		wp_group = function()
			if fields.key_enter_field == "wp_group" and fields.wp_group then
				poi.set_group(selected_name, fields.wp_group)
				poi.display_formspec()
			end
		end,
		wp_color = function()
			local idx = tonumber(fields.wp_color)
			if idx then
				local c = WP_COLORS[idx]
				if c then
					poi.set_color(name, c.hex)
					for title, id in pairs(shown_huds) do
						core.localplayer:hud_remove(id)
					end
					shown_huds = {}
					hud_wp = nil
				end
			end
			poi.display_formspec()
		end,
	}

	local name
	if fields.wp_list then
		local event = core.explode_textlist_event(fields.wp_list)
		if event.index then name = formspec_list[event.index] end
	else
		name = selected_name
	end

	if fields.wp_list and name and name ~= selected_name then
		selected_name = name
		poi.display_formspec()
		return true
	end

	for _, v in ipairs(poi.registered_transports) do
		if fields[v.name] then
			if v.func(poi.get_waypoint(name), name) then
				ws.notify("Error with " .. v.name, ws.NOTIFY_ERROR)
			end
			return true
		end
	end

	local action_map = {
		display = function()
			if not name then
				ws.notify("Please select a waypoint first.", ws.NOTIFY_ERROR)
			elseif not poi.display_waypoint(name) then
				ws.notify("Error displaying waypoint!", ws.NOTIFY_ERROR)
			end
		end,
		delete = function()
			if not name then
				ws.notify("Please select a waypoint first.", ws.NOTIFY_ERROR)
			else
				show_delete_fs(name)
			end
		end,
		sort_toggle = function()
			sort_by_distance = not sort_by_distance
			poi.display_formspec()
		end,
		rename = function() show_rename_fs(name) end,
		rename_confirm = function()
			if not (fields.new_name and #fields.new_name > 0) then
				ws.notify("New name required", ws.NOTIFY_ERROR)
			elseif poi.rename_waypoint(name, fields.new_name) then
				selected_name = fields.new_name
			else
				ws.notify("Error renaming waypoint!", ws.NOTIFY_ERROR)
			end
			poi.display_formspec()
		end,
		delete_confirm = function()
			poi.delete_waypoint(name)
			selected_name = nil
			poi.display_formspec()
		end,
		cancel = function() poi.display_formspec() end,
	}

	for field_name, handler in pairs(action_map) do
		if fields[field_name] ~= nil then
			handler()
			return true
		end
	end

	for _, field_name in ipairs({"group_filter", "poi_show_all", "wp_color", "wp_group"}) do
		local handler = handlers[field_name]
		if handler and fields[field_name] ~= nil and not fields[field_name]:match("^$") then
			handler()
			return true
		end
	end

	return true
end)

--
-- Chat commands
--

core.register_chatcommand("waypoints", {
	description = "Open the waypoint GUI",
	func = function() poi.display_formspec() end,
})
ws.register_chatcommand_alias("waypoints", "wp", "wps", "waypoint")

core.register_chatcommand("add_waypoint", {
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

core.register_chatcommand("add_waypoint_here", {
	params = "[name]",
	description = "Mark the current position as a waypoint.",
	func = function(param)
		local pos = core.localplayer:get_pos()
		local name
		if tostring(param) ~= "" then
			name = param
		else
			local ts = os.date("%Y-%m-%d_%H-%M")
			local node = core.get_node_or_nil(vector.offset(pos, 0, -1, 0))
			local hint = (node and node.name:match(":(.+)$")) or "waypoint"
			name = hint .. "_" .. ts
		end
		return poi.set_waypoint(pos, name), "Waypoint added."
	end,
})
ws.register_chatcommand_alias("add_waypoint_here", "wah", "add_wph")

core.register_chatcommand("clear_waypoint", {
	description = "Hide the displayed waypoint.",
	func = function()
		if poi.flying then poi.flying = false end
		if hud_wp then
			core.localplayer:hud_remove(hud_wp)
			hud_wp = nil
			shown_huds = {}
			return true, "Waypoint hidden."
		end
		return false, "No waypoint is currently displayed."
	end,
})
ws.register_chatcommand_alias("clear_waypoint", "cwp", "cls")

core.register_chatcommand("wpdisplay", {
	params = "<pos> <name>",
	description = "Display a waypoint at the given position.",
	func = function(pos, name)
		poi.display(pos, name)
	end,
})
ws.register_chatcommand_alias("wpdisplay", "wpd")

core.register_chatcommand("dump_pois", {
	description = "Debug: print all stored waypoints.",
	func = function()
		for name, pos in pairs(storage:to_table().fields) do
			core.log(name .. " : " .. pos)
		end
	end,
})

--
-- Server-specific extras (loaded conditionally, may not exist)
--
pcall(dofile, core.get_modpath(core.get_current_modname()) .. "/oysterity_rail.lua")

--
-- Cheat registrations
--

core.register_cheat("ShowNames", { category = "Render", setting = "poi_shownames",
	description = "Show names on POIs" })
core.register_cheat("POIs", { category = "Misc",
	description = "Open POI management formspec",
	func = poi.display_formspec })

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
