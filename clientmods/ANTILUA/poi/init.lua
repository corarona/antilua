poi = {}
local storage = core.get_mod_storage("poi")
local stprefix = "POI-singleplayer:"

if core.settings:get("poi_show_all_waypoints") == nil then
	core.settings:set("poi_show_all_waypoints", "false")
end
if core.settings:get("poi_screenshots") == nil then
	core.settings:set("poi_screenshots", "false")
end

local function show_all_enabled()
	return core.settings:get_bool("poi_show_all_waypoints")
end

local DISTANCE_NEAR = 256

local formspec_list = {}
local selected_name
local shown_huds = {}
local shown_markers = {}
local lpos
local sort_by_distance = false
local filter_group = ""
local poi_search = ""

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
	-- Clear navigation state so a reconnected session doesn't target a POI
	-- from a previous server.
	poi.last_name = nil
	poi.last_pos = nil
	poi.target = nil
	poi.eta = nil
	poi.etatime = nil
	for title in pairs(shown_huds) do
		if core.localplayer then ws.hud_remove_waypoint(title) end
	end
	shown_huds = {}
	for display in pairs(shown_markers) do
		if core.ui.minimap and core.ui.minimap.remove_marker then
			core.ui.minimap:remove_marker(shown_markers[display])
		end
	end
	shown_markers = {}
end

ws.on_connect(function()
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

local function ss_key(name)
	if show_all_enabled() and name:find(":") then
		return "POI-" .. tostring(name) .. "_ss"
	end
	return stprefix .. tostring(name) .. "_ss"
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
	local fields = storage:to_table().fields
	for key in pairs(fields) do
		if key:sub(1, #prefix) == prefix then
			wp[key] = true
		end
	end
	-- Drop metadata keys (_ss/_color/_group) only when the waypoint they
	-- belong to actually exists, so waypoints whose names legitimately end
	-- in one of those suffixes stay visible.
	for key in pairs(wp) do
		local short = key:sub(#prefix + 1)
		local base, suffix = short:match("^(.*)_([a-z]+)$")
		if base and (suffix == "ss" or suffix == "color" or suffix == "group")
				and wp[prefix .. base] then
			wp[key] = nil
		end
	end
	local out = {}
	for key in pairs(wp) do
		table.insert(out, key:sub(#prefix + 1))
	end
	table.sort(out)
	return out
end

function poi.set_waypoint(pos, name)
	pos = ws.pos_to_string(pos)
	if not pos then return end
	storage:set_string(full_key(name), pos)
	-- Capturing a screenshot writes a PNG to disk on every add; make it
	-- opt-in so /add_waypoint_here, death auto-waypoints and other mods
	-- that add waypoints in bulk don't pay that cost.
	if core.settings:get_bool("poi_screenshots") then
		-- Scene-only capture (no HUD/chat/debug overlays). Async: the
		-- callback fires once the next frame has been rendered.
		core.make_screenshot({ scene_only = true }, function(ss)
			if ss and ss ~= "" then
				local base = ss:match("[^/\\]+$") or ss
				-- Keep a per-server copy (data/server/<server>/poi) that the
				-- waypoint thumbnail is loaded from.
				local ok, data = pcall(core.read_file, ss)
				if ok and data then
					local dir = core.get_serverdata_path() .. "/poi"
					core.mkdir(dir)
					core.write_file(dir .. "/" .. base, data)
				end
				storage:set_string(ss_key(name), base)
			end
		end)
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
	storage:set_string(ss_key(name), "")
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

-- Colors auto-assigned to waypoint groups. Stable per group name so the same
-- group always gets the same color; the "Death" group stays red.
local GROUP_COLORS = {
	0x00ff00, 0x00ffff, 0xff00ff, 0xffff00, 0xff8800,
	0x00ccff, 0xff66aa, 0x88ff00, 0xffcc00, 0xcc66ff, 0x66ffcc,
}

local function hash_string(s)
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + s:byte(i)) % 0x7fffffff
	end
	return h
end

-- Deterministic color for a waypoint group, or nil when ungrouped.
function poi.group_color(group)
	if not group or group == "" then return nil end
	if group == "Death" then return 0xff0000 end
	return GROUP_COLORS[(hash_string(group) % #GROUP_COLORS) + 1]
end

local WP_DOT = "● "

function poi.color_int(name)
	local hex = poi.get_color(name)
	if hex == "" then hex = "00ff00" end
	return tonumber(hex, 16) or 0x00ff00
end

local function show_wp_hud(pos, title)
	-- Colored by the waypoint's group (falling back to its own color), shown
	-- as a small dot followed by the name.
	local color = poi.group_color(poi.get_group(title)) or poi.color_int(title)
	local display = WP_DOT .. title
	ws.hud_waypoint(display, pos, color, "m")
	shown_huds[display] = true
	-- Mirror displayed waypoints onto the minimap so they stay visible while
	-- looking at the map (group color, or the waypoint's own color).
	if core.ui.minimap and core.ui.minimap.add_marker then
		if shown_markers[display] then
			core.ui.minimap:remove_marker(shown_markers[display])
			shown_markers[display] = nil
		end
		shown_markers[display] = core.ui.minimap:add_marker({
			pos = pos,
			color = string.format("#%06x", color),
		})
	end
end

local function remove_wp_hud(title)
	-- show_wp_hud stores everything under the "● " prefixed display key, so
	-- accept both a bare title and an already-prefixed one.
	local display = title:find(WP_DOT, 1, true) and title or (WP_DOT .. title)
	if shown_huds[display] then
		ws.hud_remove_waypoint(display)
		shown_huds[display] = nil
	end
	if shown_markers[display] then
		if core.ui.minimap and core.ui.minimap.remove_marker then
			core.ui.minimap:remove_marker(shown_markers[display])
		end
		shown_markers[display] = nil
	end
end

function poi.set_hud_wp(pos, title)
	pos = ws.string_to_pos(pos)
	if not pos then return end
	title = title or ws.pos_to_string(pos)
	poi.last_name = title
	poi.last_pos = pos
	show_wp_hud(pos, title)
	return true
end

function poi.display(pos, name)
	name = name or ws.pos_to_string(pos)
	pos = ws.string_to_pos(pos)
	poi.set_hud_wp(pos, name)
	return true
end

-- Return the minimap marker id currently shown for a displayed waypoint, or
-- nil when the waypoint isn't displayed (or the minimap is unavailable).
function poi.get_displayed_marker(title)
	return shown_markers[WP_DOT .. title]
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

function poi.select_waypoint(name)
	local pos = poi.get_waypoint(name)
	if not pos then return false end
	selected_name = name
	return poi.display_waypoint(name)
end

function poi.get_nearest_name()
	if not core.localplayer then return nil end
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
	if not core.localplayer then return nil end
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
ws.on_death(function()
	if not core.localplayer then return end
	local my_death = death_counter
	death_counter = death_counter + 1
	local pos = core.localplayer:get_pos()
	poi.death_pos = vector.new(pos)
	if core.settings:get_bool("auto_death_waypoint", true) then
		poi.last_pos = pos
		local name = "Death - " .. os.date("%Y-%m-%d %H:%M:%S")
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
			if not dpos or not core.localplayer then return end
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

-- Default waypoint name for a position: the node below + timestamp, e.g.
-- "stone_2026-08-05_14-30". Shared by the chat command and the "Add Here"
-- formspec button.
local function default_wp_name(pos)
	local ts = os.date("%Y-%m-%d_%H-%M")
	local node = core.get_node_or_nil(vector.offset(pos, 0, -1, 0))
	local hint = (node and node.name:match(":(.+)$")) or "waypoint"
	return hint .. "_" .. ts
end

local function wp_distance(name)
	local pos = poi.get_waypoint(name)
	if not pos then return math.huge end
	if not core.localplayer then return math.huge end
	local lp = core.localplayer:get_pos()
	if not lp then return math.huge end
	return vector.distance(lp, pos)
end

local function get_screenshot(name)
	local ss = storage:get_string(ss_key(name))
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

-- Waypoints limited to the currently selected filter group (or all when the
-- filter is "All"). Used by the list view and the "Show all" HUD button.
local function get_group_waypoints()
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
	return wps
end

local function get_filtered_sorted_waypoints()
	local wps = get_group_waypoints()
	if poi_search ~= "" then
		local filtered = {}
		for _, name in ipairs(wps) do
			if ws.fuzzy_match(name, poi_search) then
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
		"background9[1,1;1,1;blank.png;true;7]"
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
	sb:add(
		af.dropdown(3, 0.25, 2.5, "group_filter", filter_items, filter_sel),
		af.searchbar(6, 0.25, 4.5, "poi_search", { default = poi_search, placeholder = "Search:", button_width = 1.2 })
	)
	-- Below the group dropdown: display every waypoint in the selected group
	-- (or all waypoints when the filter is "All") as HUD waypoints.
	sb:add(af.button_exit(3, 0.8, 2.5, 0.5, "show_all", "Show all"))
end

local function build_waypoint_list(sb, af, waypoints)
	-- If the selected waypoint was filtered out, drop it so the details panel
	-- and the textlist highlight agree on the same (re)selected entry.
	if selected_name then
		local in_list = false
		for _, n in ipairs(waypoints) do
			if n == selected_name then in_list = true break end
		end
		if not in_list then selected_name = nil end
	end
	local tl_entries = {}
	for id, name in ipairs(waypoints) do
		formspec_list[id] = name
		local entry = name
		-- Always show the distance so the list is useful without toggling the
		-- A-Z/Dist sort; the sort still reorders the entries by distance.
		local d = wp_distance(name)
		if d ~= math.huge then
			entry = entry .. " (" .. math.floor(d) .. "m)"
		end
		-- Colored by the waypoint's group (falling back to its own color) via
		-- the textlist #rrggbb item prefix.
		local color = poi.group_color(poi.get_group(name)) or poi.color_int(name)
		table.insert(tl_entries, "#" .. string.format("%06x", color) .. af.escape(entry))
	end
	local sel = 1
	if not selected_name and #waypoints > 0 then
		selected_name = waypoints[1]
	end
	for id, name in ipairs(waypoints) do
		if name == selected_name then sel = id end
	end
	-- Start below the header (search bar) so it doesn't overlap the list or
	-- the screenshot.
	sb:add("textlist[0.25,1.4;8.5,5.3;wp_list;" .. table.concat(tl_entries, ",") .. ";" .. sel .. "]")
	if selected_name then
		local ss = get_screenshot(selected_name)
		if ss then
			sb:add(af.image(9.25, 1.4, 2.5, 1.79, ss))
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
		af.button(3.2, 7.5, 1.4, 0.5, "add_here", "Add Here"),
		af.button(9, 7.5, 1.3, 0.5, "rename", "Rename"),
		af.button(10.5, 7.5, 1.3, 0.5, "delete", "Delete"),
		af.button(11.8, 7.5, 1.5, 0.5, "clear_all", "Clear All")
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

-- Builds only the poi content (no formspec chrome: no size/version/bgcolor).
-- Used both for the standalone formspec and when embedded as an inventory tab.
function poi.build_formspec_content()
	local af = core.al_formspec
	local sb = af.new()
	local wps = get_filtered_sorted_waypoints()
	build_header(sb, af)
	build_waypoint_list(sb, af, wps)
	build_details_panel(sb, af, selected_name)
	build_actions(sb, af)
	return sb:get()
end

local function poi_show_standalone()
	local af = core.al_formspec
	local sb = af.begin("size[13.5,10]")
	sb:add(poi.build_formspec_content())
	return core.show_formspec("poi-csm", sb:get())
end

local poi_redraw = poi_show_standalone

function poi.display_formspec()
	return poi_redraw()
end

-- Redirect where poi re-renders itself. The inventory tab sets this to
-- re-show the tab page instead of the standalone formspec.
function poi.set_redraw(fn)
	poi_redraw = fn or poi_show_standalone
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

local function show_add_here_fs()
	local af = core.al_formspec
	local pos = core.localplayer and core.localplayer:get_pos()
	local sb = af.begin("size[6,3]")
	sb:add(
		af.label(0.35, 0.2, "Add waypoint at current position"),
		af.field(0.3, 1.3, 6, 1, "new_wp_name", "Name", pos and default_wp_name(pos) or ""),
		af.button(0, 2, 3, 1, "cancel", "Cancel"),
		af.button(3, 2, 3, 1, "add_here_confirm", "Add")
	)
	return core.show_formspec("poi-csm", sb:get())
end

local function show_delete_fs(name)
	local af = core.al_formspec
	return core.show_formspec("poi-csm", af.confirm_dialog(
		[[Are you sure you want to delete "]] .. name .. [["?]],
		"delete_confirm", "cancel"))
end

local function show_clear_all_fs()
	local af = core.al_formspec
	return core.show_formspec("poi-csm", af.confirm_dialog(
		"Hide ALL displayed waypoints?",
		"clear_all_confirm", "cancel", { yes_label = "Hide All" }))
end

-- Handles poi formspec input. Used by both the standalone formspec
-- ("poi-csm") and the inventory tab. Returns true when it consumed the fields.
function poi.handle_fields(fields)
	-- Widget handlers run on every formspec submission (all widget values are
	-- always present), so each only acts when its value actually changed, and
	-- returns true when it did. This lets the dispatch loop below skip stale
	-- widgets (e.g. group_filter, which is always present) instead of letting
	-- them swallow later handlers like wp_group/wp_color.
	local handlers = {
		group_filter = function()
			-- The dropdown submits the selected item's value text (e.g. "Mine"
			-- or "All"), not its index.
			local group = fields.group_filter
			if group == "All" then group = "" end
			if group ~= filter_group then
				filter_group = group
				poi.display_formspec()
				return true
			end
			return false
		end,
		poi_show_all = function()
			local enabled = fields.poi_show_all == "true"
			if enabled ~= core.settings:get_bool("poi_show_all_waypoints") then
				core.settings:set_bool("poi_show_all_waypoints", enabled)
				poi.display_formspec()
				return true
			end
			return false
		end,
		wp_group = function()
			if fields.key_enter_field == "wp_group" and fields.wp_group then
				poi.set_group(selected_name, fields.wp_group)
				-- Refresh the HUD dot so it picks up the new group color.
				if selected_name and shown_huds[WP_DOT .. selected_name] then
					local pos = poi.get_waypoint(selected_name)
					if pos then show_wp_hud(pos, selected_name) end
				end
				poi.display_formspec()
				return true
			end
			return false
		end,
		wp_color = function()
			-- The dropdown submits the color's value text (e.g. "Red"), not
			-- its index.
			local c
			for _, col in ipairs(WP_COLORS) do
				if col.name == fields.wp_color then c = col break end
			end
			if c and selected_name then
				local cur = poi.get_color(selected_name)
				if cur == "" then cur = "00ff00" end
				if c.hex ~= cur then
					poi.set_color(selected_name, c.hex)
					-- Refresh the HUD dot so it picks up the new color
					-- without disturbing the rest of the display.
					if shown_huds[WP_DOT .. selected_name] then
						local pos = poi.get_waypoint(selected_name)
						if pos then show_wp_hud(pos, selected_name) end
					end
					poi.display_formspec()
					return true
				end
			end
			return false
		end,
	}

	local name
	if fields.wp_list then
		local event = core.explode_textlist_event(fields.wp_list)
		if event.index then name = formspec_list[event.index] end
	end
	-- A submitted textlist that was never clicked reports index 0 (INV
	-- event); fall back to the auto-selected entry so buttons like the
	-- transports work without having to click the list first.
	if not name then name = selected_name end

	if fields.wp_list and name and name ~= selected_name then
		selected_name = name
		poi.display_formspec()
		return true
	end

	for _, v in ipairs(poi.registered_transports) do
		if fields[v.name] then
			if not name then
				ws.notify("Please select a waypoint first.", ws.NOTIFY_ERROR)
			elseif v.func(poi.get_waypoint(name), name) then
				ws.notify("Error with " .. v.name, ws.NOTIFY_ERROR)
			end
			return true
		end
	end

	-- Search: handle Enter in search field
	if fields.key_enter_field == "poi_search" then
		poi_search = fields.poi_search or ""
		poi.display_formspec()
		return true
	end

	local action_map = {
		__poi_search_search = function()
			poi_search = fields.poi_search or ""
			poi.display_formspec()
		end,
		display = function()
			if not name then
				ws.notify("Please select a waypoint first.", ws.NOTIFY_ERROR)
			elseif not poi.display_waypoint(name) then
				ws.notify("Error displaying waypoint!", ws.NOTIFY_ERROR)
			end
		end,
		show_all = function()
			local shown = 0
			for _, wpname in ipairs(get_group_waypoints()) do
				local pos = poi.get_waypoint(wpname)
				if pos then
					poi.display(pos, wpname)
					shown = shown + 1
				end
			end
			if shown > 0 then
				ws.notify("Showing " .. shown .. " waypoint(s).", ws.NOTIFY_INFO)
			else
				ws.notify("No waypoints to display.", ws.NOTIFY_ERROR)
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
		add_here = function() show_add_here_fs() end,
		add_here_confirm = function()
			local wname = fields.new_wp_name or ""
			if #wname < 1 then
				ws.notify("Waypoint name cannot be empty.", ws.NOTIFY_ERROR)
			elseif not core.localplayer then
				ws.notify("No player position available.", ws.NOTIFY_ERROR)
			elseif poi.set_waypoint(core.localplayer:get_pos(), wname) then
				selected_name = wname
				poi.select_waypoint(wname)
				ws.notify("Waypoint added.", ws.NOTIFY_SUCCESS)
			else
				ws.notify("Error adding waypoint!", ws.NOTIFY_ERROR)
			end
			poi.display_formspec()
		end,
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
		clear_all = function() show_clear_all_fs() end,
		clear_all_confirm = function()
			for title in pairs(shown_huds) do
				remove_wp_hud(title)
			end
			shown_huds = {}
			poi.last_name = nil
			poi.last_pos = nil
			poi.display_formspec()
		end,
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
			if handler() then
				return true
			end
		end
	end

	return true
end

core.register_on_formspec_input(function(formname, fields)
	if formname ~= "poi-csm" then return end
	return poi.handle_fields(fields)
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
		if not core.string_to_pos(pos_str) then
			return false, "Invalid position: " .. pos_str
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
			name = default_wp_name(pos)
		end
		return poi.set_waypoint(pos, name), "Waypoint added."
	end,
})
ws.register_chatcommand_alias("add_waypoint_here", "wah", "add_wph")

core.register_chatcommand("clear_waypoint", {
	description = "Hide the displayed waypoint.",
	func = function()
		if shown_huds and next(shown_huds) then
			for title in pairs(shown_huds) do
				remove_wp_hud(title)
			end
			shown_huds = {}
			return true, "Waypoints hidden."
		end
		return false, "No waypoints are currently displayed."
	end,
})
ws.register_chatcommand_alias("clear_waypoint", "cwp", "cls")

core.register_chatcommand("wpdisplay", {
	params = "<pos> <name>",
	description = "Display a waypoint at the given position.",
	func = function(param)
		local pos_str, name = param, nil
		local s, e = param:find(" ")
		if s then
			pos_str = param:sub(1, s - 1)
			name = param:sub(e + 1)
			if name == "" then name = nil end
		end
		if not core.string_to_pos(pos_str) then
			return false, "Invalid position: " .. pos_str
		end
		poi.display(pos_str, name)
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

--
-- Cheat registrations
--

core.register_cheat("ShowNames", { category = "Render", setting = "poi_shownames",
	description = "Show names on POIs" })
core.register_cheat("POIs", { category = "Misc",
	description = "Open POI management formspec",
	func = poi.display_formspec })

ws.on_death(function()
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

--
-- Inventory tab (registered directly: the mod loader orders the `inventory`
-- mod before poi because poi optionally depends on it)
--

if core.inv_tabs and core.inv_tabs.register_tab then
	core.inv_tabs.register_tab({
		id = "poi",
		title = "Waypoints",
		build = function()
			return poi.build_formspec_content()
		end,
		handle = function(fields)
			return poi.handle_fields(fields)
		end,
		-- The poi layout is self-contained with its own margins; don't draw
		-- the player inventory under it and don't add the generic padding.
		show_inventory = false,
		pad = false,
	})
	-- Re-render inside the tab page when poi asks to redraw, falling back to
	-- the standalone formspec when the tab isn't open.
	poi.set_redraw(function()
		if core.inv_tabs.is_open() then
			core.inv_tabs.set_active("poi")
		else
			poi_show_standalone()
		end
	end)
end
