-- Tests for DragonfireClient API registrations

function test_api_registration_no_player(T)
	-- Verify core table has expected basic functions
	T.run("core.settings exists", function()
		T.assert(type(core.settings) == "userdata" or type(core.settings) == "table",
			"core.settings should exist")
	end)

	T.run("core.close_formspec exists", function()
		T.assert(type(core.close_formspec) == "function",
			"core.close_formspec should be a function")
	end)

	-- core.registered_items / core.registered_nodes
	T.run("core.registered_items exists", function()
		T.assert(type(core.registered_items) == "table",
			"core.registered_items should be a table")
	end)

	T.run("core.registered_nodes exists", function()
		T.assert(type(core.registered_nodes) == "table",
			"core.registered_nodes should be a table")
	end)

	-- core.cheats table (from builtin/client/cheats.lua)
	T.run("core.cheats table exists", function()
		T.assert(type(core.cheats) == "table",
			"core.cheats should be a table")
	end)

	T.run("core.cheats has categories", function()
		T.assert(next(core.cheats) ~= nil,
			"core.cheats should have entries")
	end)

	-- Noise types (registered as globals, not on core)
	T.run("PseudoRandom global exists", function()
		T.assert(type(PseudoRandom) == "function",
			"PseudoRandom should be a global function")
		local ok, pr = pcall(PseudoRandom, 42)
		T.assert(ok and pr, "PseudoRandom(42) should create a random object")
	end)

	T.run("PcgRandom global exists", function()
		T.assert(type(PcgRandom) == "function",
			"PcgRandom should be a global function")
		local ok, pr = pcall(PcgRandom, 42)
		T.assert(ok and pr, "PcgRandom(42) should create a random object")
	end)

	T.run("SecureRandom global exists", function()
		T.assert(type(SecureRandom) == "function",
			"SecureRandom should be a global function")
		local ok, sr = pcall(SecureRandom)
		T.assert(ok and sr, "SecureRandom() should create a random object")
	end)

	-- VoxelManip
	T.run("get_voxel_manip exists", function()
		T.assert(type(core.get_voxel_manip) == "function",
			"core.get_voxel_manip should exist")
		-- May return nil without map context, but shouldn't crash
		local ok, vm = pcall(core.get_voxel_manip)
		T.assert(ok, "core.get_voxel_manip should not crash")
	end)

	-- Noise
	T.run("get_perlin exists", function()
		T.assert(type(core.get_perlin) == "function",
			"core.get_perlin should exist")
	end)

	-- HTTP API
	T.run("core.request_http_api exists", function()
		T.assert(type(core.request_http_api) == "function",
			"core.request_http_api should be a function")
	end)

	-- Client-side formspec
	T.run("core.show_formspec exists", function()
		T.assert(type(core.show_formspec) == "function",
			"core.show_formspec should be a function")
	end)

	-- Camera
	T.run("core.camera object exists", function()
		T.assert(type(core.camera) == "userdata" or type(core.camera) == "table",
			"core.camera should exist")
	end)

	-- Settings roundtrip
	T.run("settings read/write cheat settings", function()
		local saved = core.settings:get("airjump")
		core.settings:set("airjump", "true")
		T.assert_eq(core.settings:get("airjump"), "true",
			"airjump setting should roundtrip")
		core.settings:set("airjump", saved or "false")
	end)

	-- ==========================================
	-- FEATURES NOT YET PORTED FROM DF (known failures)
	-- ==========================================

	T.known_failure("core.get_inventory exists", function()
		T.assert(type(core.get_inventory) == "function",
			"core.get_inventory should be a function")
	end)

	T.known_failure("core.drop_selected_item exists", function()
		T.assert(type(core.drop_selected_item) == "function",
			"core.drop_selected_item should be a function")
	end)

	T.known_failure("core.get_send_speed exists", function()
		T.assert(type(core.get_send_speed) == "function",
			"core.get_send_speed should be a function")
	end)

	T.known_failure("core.dig_node exists", function()
		T.assert(type(core.dig_node) == "function",
			"core.dig_node should be a function")
	end)

	T.known_failure("core.interact exists", function()
		T.assert(type(core.interact) == "function",
			"core.interact should be a function")
	end)

	T.known_failure("core.make_screenshot exists", function()
		T.assert(type(core.make_screenshot) == "function",
			"core.make_screenshot should be a function")
	end)

	-- LocalPlayer extensions (need localplayer ref)
	T.defer("LocalPlayer:get_yaw exists", function()
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

	-- Client-side chat commands
	T.run("chatcommands .wielded registered", function()
		T.assert(type(core.registered_chatcommands) == "table",
			"core.registered_chatcommands should exist")
		if core.registered_chatcommands then
			T.assert(core.registered_chatcommands.wielded ~= nil,
				".wielded command should be registered")
			T.assert(core.registered_chatcommands.players ~= nil,
				".players command should be registered")
			T.assert(core.registered_chatcommands.kill ~= nil,
				".kill command should be registered")
		end
	end)

	T.known_failure("chatcommands .teleport registered", function()
		T.assert(core.registered_chatcommands.teleport ~= nil,
			".teleport command should be registered")
	end)

	T.known_failure("chatcommands .set registered", function()
		T.assert(core.registered_chatcommands.set ~= nil,
			".set command should be registered")
	end)

	T.known_failure("chatcommands .dig registered", function()
		T.assert(core.registered_chatcommands.dig ~= nil,
			".dig command should be registered")
	end)

	T.known_failure("chatcommands .place registered", function()
		T.assert(core.registered_chatcommands.place ~= nil,
			".place command should be registered")
	end)
end
