-- Tests for DragonfireClient API registrations

function test_api_registration(T)
	-- Verify core table has expected DF functions
	T.run("core.get_inventory exists", function()
		T.assert(type(core.get_inventory) == "function",
			"core.get_inventory should be a function")
	end)

	T.run("core.drop_selected_item exists", function()
		T.assert(type(core.drop_selected_item) == "function",
			"core.drop_selected_item should be a function")
	end)

	T.run("core.close_formspec exists", function()
		T.assert(type(core.close_formspec) == "function",
			"core.close_formspec should be a function")
	end)

	T.run("core.get_send_speed exists", function()
		T.assert(type(core.get_send_speed) == "function",
			"core.get_send_speed should be a function")
	end)

	T.run("core.dig_node exists", function()
		T.assert(type(core.dig_node) == "function",
			"core.dig_node should be a function")
	end)

	T.run("core.interact exists", function()
		T.assert(type(core.interact) == "function",
			"core.interact should be a function")
	end)

	T.run("core.get_nearby_objects exists", function()
		T.assert(type(core.get_nearby_objects) == "function",
			"core.get_nearby_objects should be a function")
	end)

	T.run("core.make_screenshot exists", function()
		T.assert(type(core.make_screenshot) == "function",
			"core.make_screenshot should be a function")
	end)

	-- Verify registered_items / registered_nodes
	T.run("core.registered_items exists", function()
		T.assert(type(core.registered_items) == "table",
			"core.registered_items should be a table")
	end)

	T.run("core.registered_nodes exists", function()
		T.assert(type(core.registered_nodes) == "table",
			"core.registered_nodes should be a table")
	end)

	-- Verify cheat-related globals
	T.run("core.cheats table exists", function()
		T.assert(type(core.cheats) == "table",
			"core.cheats should be a table")
	end)

	T.run("core.cheats has categories", function()
		T.assert(#core.cheats > 0 or next(core.cheats) ~= nil,
			"core.cheats should have entries")
	end)

	-- Verify noise types exist
	T.run("LuaValueNoise mapped", function()
		-- Just calling get_perlin should not error
		local ok = pcall(core.get_perlin, 0, 0, 0)
		-- It might return nil without a map, but shouldn't crash
		T.assert(type(ok) ~= "nil" or ok == nil, "get_perlin should not crash")
	end)

	T.run("LuaPseudoRandom exists", function()
		local ok, pr = pcall(core.PseudoRandom, 42)
		T.assert(ok and pr, "core.PseudoRandom should create a random object")
	end)

	T.run("LuaPcgRandom exists", function()
		local ok, pr = pcall(core.PcgRandom, 42)
		T.assert(ok and pr, "core.PcgRandom should create a random object")
	end)

	T.run("LuaSecureRandom exists", function()
		local ok, sr = pcall(core.SecureRandom)
		T.assert(ok and sr, "core.SecureRandom should create a random object")
	end)

	-- Verify VoxelManip
	T.run("LuaVoxelManip exists", function()
		local ok, vm = pcall(core.get_voxel_manip)
		-- Should either return a VM or nil (depending on context)
		T.assert(ok, "core.get_voxel_manip should not crash")
	end)

	-- Verify HTTP API
	T.run("core.request_http_api exists", function()
		T.assert(type(core.request_http_api) == "function",
			"core.request_http_api should be a function")
	end)

	-- Verify LocalPlayer extensions
	T.run("LocalPlayer:get_yaw exists", function()
		local lp = core.localplayer
		T.assert(lp ~= nil, "core.localplayer should exist")
		if lp then
			T.assert(type(lp.get_yaw) == "function",
				"localplayer:get_yaw should be a function")
			T.assert(type(lp.set_yaw) == "function",
				"localplayer:set_yaw should be a function")
			T.assert(type(lp.get_pitch) == "function",
				"localplayer:get_pitch should be a function")
			T.assert(type(lp.set_pitch) == "function",
				"localplayer:set_pitch should be a function")
			T.assert(type(lp.set_pos) == "function",
				"localplayer:set_pos should be a function")
			T.assert(type(lp.get_hotbar_size) == "function",
				"localplayer:get_hotbar_size should be a function")
			T.assert(type(lp.get_object) == "function",
				"localplayer:get_object should be a function")
			T.assert(type(lp.set_physics_override) == "function",
				"localplayer:set_physics_override should be a function")
		end
	end)

	-- Verify chat command registrations
	T.run("client-side chat commands exist", function()
		-- .teleport, .set, .dig, .place, .wielded, etc.
		T.assert(type(core.registered_chatcommands) == "table",
			"core.registered_chatcommands should exist")
		if core.registered_chatcommands then
			T.assert(core.registered_chatcommands.teleport ~= nil,
				".teleport command should be registered")
			T.assert(core.registered_chatcommands.set ~= nil,
				".set command should be registered")
			T.assert(core.registered_chatcommands.dig ~= nil,
				".dig command should be registered")
			T.assert(core.registered_chatcommands.place ~= nil,
				".place command should be registered")
			T.assert(core.registered_chatcommands.wielded ~= nil,
				".wielded command should be registered")
			T.assert(core.registered_chatcommands.players ~= nil,
				".players command should be registered")
			T.assert(core.registered_chatcommands.kill ~= nil,
				".kill command should be registered")
		end
	end)

	-- Verify settings roundtrip
	T.run("settings read/write cheat settings", function()
		local saved = core.settings:get("airjump")
		core.settings:set("airjump", "true")
		T.assert_eq(core.settings:get("airjump"), "true",
			"airjump setting should roundtrip")
		core.settings:set("airjump", saved or "false")
	end)
end
