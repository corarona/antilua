function core.toggle_favorite(setting)
	local favs = core.get_favorites()
	local idx = {}
	for i, v in ipairs(favs) do idx[v] = true end
	if idx[setting] then
		local new_favs = {}
		for _, v in ipairs(favs) do
			if v ~= setting then table.insert(new_favs, v) end
		end
		core.settings:set("cheat_menu_favorites", table.concat(new_favs, ","))
	else
		table.insert(favs, setting)
		core.settings:set("cheat_menu_favorites", table.concat(favs, ","))
	end
end

function core.is_favorite(setting)
	local favs = core.get_favorites()
	for _, v in ipairs(favs) do
		if v == setting then return true end
	end
	return false
end

function core.get_favorites()
	local str = core.settings:get("cheat_menu_favorites") or ""
	if str == "" then return {} end
	local t = {}
	for v in str:gmatch("[^,]+") do
		table.insert(t, v)
	end
	return t
end

function core.clear_favorites()
	core.settings:set("cheat_menu_favorites", "")
end

-- One-shot actions from across the ANTILUA mods exposed through the Quick
-- Access Palette (~). The provider runs each time the palette opens and only
-- emits entries whose backing mod/feature is loaded.

if core.register_quick_menu_provider then
	core.register_quick_menu_provider(function()
		local function mod(name)
			local g = rawget(_G, name)
			if g then
				return g
			end
			if core.get_modpath_real and core.get_modpath_real(name) ~= nil then
				return true
			end
			return nil
		end
		local function cmd(name)
			local t = core.registered_chatcommands
			return t and t[name]
		end
		local function player_pos()
			return core.localplayer and core.localplayer:get_pos()
		end

		local entries = {}
		local function add(label, action, fields)
			local e = { label = label, action = action }
			if fields then
				if fields.keywords then e.keywords = fields.keywords end
				if fields.description then e.description = fields.description end
			end
			entries[#entries + 1] = e
		end

		-- Waypoints (poi) + autopilot warp (basic_moves)
		local poi = mod("poi")
		if poi then
			local add_here = cmd("add_waypoint_here")
			if add_here then
				add("Waypoint Here", function() add_here.func("") end,
				{ keywords = { "wp", "mark", "add" } })
			end
			add("Show Nearest Waypoint", function()
				poi.display_waypoint(poi.get_nearest_name())
			end)
			local clear_wp = cmd("clear_waypoint")
			if clear_wp then
				add("Hide Waypoints", function() clear_wp.func("") end)
			end
			if poi.last_pos then
				add("TP to Last Waypoint (Client)", function()
					if core.localplayer then
						core.localplayer:set_pos(poi.last_pos)
					end
				end)
				add("TP to Last Waypoint (Server)", function()
					local p = poi.last_pos
					core.send_chat_message("/teleport " .. p.x .. "," .. p.y .. "," .. p.z)
				end)
			end
			local autofly = mod("autofly")
			if autofly then
				add("Warp to Nearest Waypoint", function()
					autofly.warp(poi.get_nearest_name())
				end)
			end

			-- Individual waypoints as palette entries. With
			-- poi_show_all_waypoints enabled the names carry a server:port:
			-- prefix so waypoints from every server are listed.
			for _, name in ipairs(poi.getwps()) do
				local n = name
				local pos = poi.get_waypoint(n)
				if pos then
					local entry = {
						label = n,
						action = function() poi.select_waypoint(n) end,
						keywords = { "wp", "waypoint", poi.get_group(n) or "" },
						description = "Select and show waypoint (" .. pos.x .. ", " .. pos.y .. ", " .. pos.z .. ")",
						is_enabled = function() return poi.last_name == n end,
					}
					entries[#entries + 1] = entry
				end
			end
		end

		-- Rhythm burst teleport (rhythmtp)
		local rhythmtp = mod("rhythmtp")
		if rhythmtp then
			add("Rhythm TP Forward", function() rhythmtp.go_forward() end)
			add("Cancel Rhythm TP", function() rhythmtp.stop() end)
		end

		-- Nearest oysterity rail portal
		local rail = cmd("oy_railportal")
		if rail then
			add("Find Nearest Rail Portal", function() rail.func("") end)
		end

		-- wasplib utilities
		local ws = mod("ws")
		if ws then
			add("Constraint Pos1 Here", function()
				local p = player_pos()
				if p then ws.set_pos1(p) end
			end)
			add("Constraint Pos2 Here", function()
				local p = player_pos()
				if p then ws.set_pos2(p) end
			end)
			add("Reset Constraints", function() ws.reset_constraints() end)
			add("Make Block from Wielded", function() ws.make_blocks() end)
		end

		-- Eat food right now (autoeat)
		local autoeat = mod("autoeat")
		if autoeat then
			add("Eat Food Now", function() autoeat.eat() end)
		end

		-- Particle cleanup
		if core.clear_all_particles then
			add("Clear All Particles", function() core.clear_all_particles() end)
		end

		-- Schembuilder operations + generic chat-command actions
		local function add_cmd(name, label, param)
			local c = cmd(name)
			if c then
				add(label, function() c.func(param or "") end)
			end
		end
		add_cmd("schembrowse", "Open Schematic Browser")
		add_cmd("spos1", "Set Schem Pos1 Here")
		add_cmd("spos2", "Set Schem Pos2 Here")
		add_cmd("schemclear", "Clear Schem Build")
		add_cmd("schemundo", "Undo Schem Placement")
		add_cmd("schemresume", "Resume Schem Build")

		-- Info / stats / housekeeping commands
		add_cmd("entityinfo", "Inspect Pointed Thing")
		add_cmd("stats", "Show Session Stats")
		add_cmd("blockstats", "Show Block Stats")
		add_cmd("cheat_rearrange", "Rearrange Cheat Panels")
		add_cmd("nlshow", "Nodelist: Show HUD")
		add_cmd("nlhide", "Nodelist: Hide HUD")
		add_cmd("nlawi", "Nodelist: Add Wielded")
		add_cmd("nlapn", "Nodelist: Add Pointed Node")
		add_cmd("mapblock_age", "Analyze Mapblock Age")
		add_cmd("mapblock_age_clear", "Clear Age Markers")
		add_cmd("bx_logout", "Logout BlockExchange")
		add_cmd("profile", "Save Cheat Profile (Server)", "save")
		add_cmd("profile", "Load Cheat Profile (Server)", "load")

		-- Hidden feature toggles (settings not exposed as cheats)
		local function add_toggle(label, setting, fields)
			local e = { label = label, toggle = setting }
			if fields then
				if fields.keywords then e.keywords = fields.keywords end
			end
			entries[#entries + 1] = e
		end
		add_toggle("Fly (Free Move)", "free_move", { keywords = { "fly" } })
		if poi then
			add_toggle("Show All Waypoints", "poi_show_all_waypoints",
				{ keywords = { "wp", "waypoint" } })
		end
		if mod("chat_logger") then
			add_toggle("Log Chat to File", "chat_logging")
		end
		if mod("schembuilder") then
			add_toggle("Schem Build: Hollow", "schembuilder_hollow")
			add_toggle("Schem Build: Wireframe Box", "schembuilder_wireframe_draw3d")
		end
		if mod("devtools") then
			add_toggle("Auto-Take Entity Inv", "einv_taker")
		end

		-- wasplib tool / loot wrappers
		if ws then
			add("Select Best Tool for Pointed Node", function()
				local pt = core.get_pointed_thing()
				if pt and pt.type == "node" and ws.select_best_tool then
					ws.select_best_tool(pt.under)
				end
			end)
			add("Clear HUD Markers", function() ws.clear_wps() end)
		end
		local nlist = mod("nlist")
		if ws and nlist and nlist.get and ws.loot_list then
			add("Loot Nearby Containers (List)", function()
				ws.loot_list(nlist.get(nlist.selected), 5, 16)
			end)
		end

		-- Stop every running bot (sbots)
		local sbots = mod("sbots")
		if sbots then
			add("Stop All Bots", function()
				for _, b in ipairs(sbots.get_active_bots()) do
					core.settings:set_bool(b.name:lower(), false)
				end
			end)
		end

		-- Lua IDE (dte)
		local dte = mod("dte")
		if dte and dte.show_view then
			add("Open Lua IDE", function() dte.show_view(0) end)
		end

		-- Autocraft GUI
		local autocraft = cmd("autocraft")
		if autocraft then
			add("Open Autocraft GUI", function() autocraft.func("") end)
		end

		return entries
	end)
end
