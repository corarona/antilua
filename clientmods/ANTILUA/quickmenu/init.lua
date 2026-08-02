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
			return rawget(_G, name)
		end
		local function cmd(name)
			local t = core.registered_chatcommands
			return t and t[name]
		end
		local function player_pos()
			return core.localplayer and core.localplayer:get_pos()
		end

		local entries = {}
		local function add(label, action)
			entries[#entries + 1] = { label = label, action = action }
		end

		-- Waypoints (poi) + autopilot warp (basic_moves)
		local poi = mod("poi")
		if poi then
			local add_here = cmd("add_waypoint_here")
			if add_here then
				add("Waypoint Here", function() add_here.func("") end)
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

		-- Schembuilder operations
		local function schem_cmd(name, label)
			local c = cmd(name)
			if c then
				add(label, function() c.func("") end)
			end
		end
		schem_cmd("schembrowse", "Open Schematic Browser")
		schem_cmd("spos1", "Set Schem Pos1 Here")
		schem_cmd("spos2", "Set Schem Pos2 Here")
		schem_cmd("schemclear", "Clear Schem Build")
		schem_cmd("schemundo", "Undo Schem Placement")
		schem_cmd("schemresume", "Resume Schem Build")

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
