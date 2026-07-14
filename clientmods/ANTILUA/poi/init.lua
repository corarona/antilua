poi = {}
local storage = core.get_mod_storage("poi")
local stprefix = "POI-singleplayer:"

if core.settings:get("poi_show_all_waypoints") == nil then
	core.settings:set("poi_show_all_waypoints", "false")
end

core.register_on_connect(function()
	local info = core.get_server_info()
	if info and info.address then
		stprefix = "POI-" .. info.address .. ":" .. info.port .. ":"
	end
end)

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

core.register_on_death(function()
	if not core.localplayer then return end
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
		core.after(0.5, function()
			core.localplayer:set_pos(poi.death_pos)
			core.after(0.1, function()
				local n = core.get_node_or_nil(poi.death_pos)
				if n and n.name == "bones:bones" then
					ws.dig(poi.death_pos)
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

function poi.display_formspec()
	local af = core.al_formspec
	local raw_wps = poi.getwps()
	local sb = af.begin("size[13.5,10]")

	sb:add(
		"background9[1,1;1,1;blank.png;true;7]",
		af.label(0.25, 0.5, "Waypoint list")
	)

	sb:add("checkbox[0.25,0.2;poi_show_all;Show all servers;"
		.. (core.settings:get_bool("poi_show_all_waypoints") and "true" or "false") .. "]")

	-- Group filter dropdown
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

	-- Filter waypoints by group
	local waypoints = raw_wps
	if filter_group ~= "" then
		waypoints = {}
		for _, name in ipairs(raw_wps) do
			if poi.get_group(name) == filter_group then
				table.insert(waypoints, name)
			end
		end
	end

	-- Sort waypoints
	if sort_by_distance then
		table.sort(waypoints, function(a, b)
			return wp_distance(a) < wp_distance(b)
		end)
	end

	-- Build textlist from waypoints (left side)
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

	-- Screenshot thumbnail (right side)
	if selected_name then
		local ss = get_screenshot(selected_name)
		if ss then
			sb:add(af.image(9.25, 0.75, 3.5, 2.5, ss))
		end
	end

	-- Action buttons
	local sort_label = sort_by_distance and "Dist" or "A-Z"
	sb:add(
		af.button(0.5, 7.5, 1, 0.5, "sort_toggle", sort_label),
		af.button_exit(1.7, 7.5, 1, 0.5, "display", "Show")
	)

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
		sb:add(af.dropdown(3, 7.5, 1.8, "wp_color", color_names, sel_idx))
	end

	sb:add(
		af.button(9, 7.5, 1.3, 0.5, "rename", "Rename"),
		af.button(10.5, 7.5, 1.3, 0.5, "delete", "Delete")
	)

	-- Waypoint position label and group field
	if selected_name then
		local pos = poi.get_waypoint(selected_name)
		if pos then
			sb:add(af.label(0.25, 7.25, "Waypoint position: " .. pos.x .. ", " .. pos.y .. ", " .. pos.z))
		end
		local cur_group = poi.get_group(selected_name)
		sb:add(af.field(5, 7.25, 3.5, 0.5, "wp_group", "Group", cur_group))
	end

	-- Transport buttons
	local sp, y = 0.5, 8.25
	for _, v in ipairs(poi.registered_transports) do
		sb:add(af.button_exit(sp, y, 1, 0.5, v.name, v.name))
		sp = sp + 1
		if sp > 10 then
			y = y + 0.75
			sp = 0.5
		end
	end

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

	-- Group filter: check before everything else since it's always
	-- submitted alongside other dropdowns like wp_color
	if fields.group_filter then
		local filter_names = {"All"}
		local groups = get_unique_groups()
		for _, g in ipairs(groups) do
			table.insert(filter_names, g)
		end
		local idx = tonumber(fields.group_filter)
		if idx and filter_names[idx] then
			local new_filter = filter_names[idx]
			filter_group = (new_filter == "All") and "" or new_filter
			poi.display_formspec()
			return true
		end
	end

	-- Show all servers checkbox
	if fields.poi_show_all ~= nil then
		core.settings:set_bool("poi_show_all_waypoints", fields.poi_show_all == "true")
		poi.display_formspec()
		return true
	end

	local name
	if fields.wp_list then
		local event = core.explode_textlist_event(fields.wp_list)
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

	-- Textlist selection change (must come before other field checks,
	-- because dropdown fields are always submitted and would short-circuit)
	if fields.wp_list and name ~= selected_name then
		selected_name = name
		poi.display_formspec()
		return true
	end

	-- Transport buttons
	for _, v in ipairs(poi.registered_transports) do
		if fields[v.name] then
			if not v.func(poi.get_waypoint(name), name) then
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
	elseif fields.key_enter_field == "wp_group" and fields.wp_group then
		poi.set_group(selected_name, fields.wp_group)
		poi.display_formspec()
	elseif fields.wp_color then
		local idx = tonumber(fields.wp_color)
		if idx then
			local c = WP_COLORS[idx]
			if c then
				poi.set_color(name, c.hex)
				shown_huds = {}
				if hud_wp then
					core.localplayer:hud_remove(hud_wp)
					hud_wp = nil
				end
			end
		end
		poi.display_formspec()
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
-- Oysterity Nether Railway Network
--

local RAIL_PORTAL_SPACING = 200
local RAIL_PORTAL_MAX = 3800
local RAIL_RINGS = {420, 666, 1337, 2666, 3860}
local RAIL_PORTAL_Y_NETHER = -28946.5
local RAIL_PORTAL_Y_OVERWORLD = 1

local function ring_perimeter_point(R, d)
	local side = math.floor(d / (2 * R))
	local offset = d % (2 * R)
	if side == 0 then
		return R, -R + offset
	elseif side == 1 then
		return R - offset, R
	elseif side == 2 then
		return -R, R - offset
	else
		return -R + offset, -R
	end
end

local function find_nearest_rail_portal(nx, nz)
	local best_dsq = math.huge
	local best_x, best_z = 0, 0

	-- Axis portals: (200n, 0) and (0, 200n)
	for n = -19, 19 do
		local ax, az = n * RAIL_PORTAL_SPACING, 0
		local dsq = (nx - ax)^2 + (nz - az)^2
		if dsq < best_dsq then
			best_dsq = dsq
			best_x, best_z = ax, az
		end
		ax, az = 0, n * RAIL_PORTAL_SPACING
		dsq = (nx - ax)^2 + (nz - az)^2
		if dsq < best_dsq then
			best_dsq = dsq
			best_x, best_z = ax, az
		end
	end

	-- Ring portals: square perimeters every 200 nodes
	for _, R in ipairs(RAIL_RINGS) do
		local perimeter = 8 * R
		for d = 0, perimeter - RAIL_PORTAL_SPACING, RAIL_PORTAL_SPACING do
			local px, pz = ring_perimeter_point(R, d)
			local dsq = (nx - px)^2 + (nz - pz)^2
			if dsq < best_dsq then
				best_dsq = dsq
				best_x, best_z = px, pz
			end
		end
	end

	return best_x, best_z
end

core.register_chatcommand("railportal", {
	params = "[x,[y,]z]",
	description = "Find nearest oysterity nether railway portal. Uses current pos if no args.",
	func = function(param)
		local x, y, z
		local is_nether = false

		if param == nil or param == "" then
			local pos = core.localplayer:get_pos()
			if not pos then
				return false, "Could not get player position."
			end
			x, y, z = pos.x, pos.y, pos.z
		else
			param = param:gsub(",", " ")
			local parts = {}
			for p in param:gmatch("%S+") do
				table.insert(parts, p)
			end
			if #parts == 2 then
				x = tonumber(parts[1])
				z = tonumber(parts[2])
				y = nil
			elseif #parts >= 3 then
				x = tonumber(parts[1])
				y = tonumber(parts[2])
				z = tonumber(parts[3])
			else
				return false, "Usage: .railportal [x,[y,]z]"
			end
			if not x or not z then
				return false, "Invalid coordinates."
			end
		end

		if y then
			is_nether = y < -20000
		end

		-- Convert to nether coordinates
		if not is_nether then
			x = x / 8
			z = z / 8
		end

		local px, pz = find_nearest_rail_portal(x, z)

		if is_nether then
			x, z = px, pz
			y = RAIL_PORTAL_Y_NETHER
		else
			x = math.floor(px * 8)
			z = math.floor(pz * 8)
			y = RAIL_PORTAL_Y_OVERWORLD
		end

		local pos = {x = x, y = y, z = z}
		local dim = is_nether and "Nether" or "Overworld"

		poi.set_waypoint(pos, "Rail Portal")
		poi.display_waypoint("Rail Portal")

		return true, dim .. " Rail Portal at " .. x .. ", " .. y .. ", " .. z
	end,
})

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
