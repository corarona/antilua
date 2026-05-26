-- Tests for DragonfireClient API registrations

function test_api_registration_no_player(T)
	T.run("core.settings exists", function()
		T.assert(type(core.settings) == "userdata" or type(core.settings) == "table",
			"core.settings should exist")
	end)

	T.run("core.close_formspec exists", function()
		T.assert(type(core.close_formspec) == "function",
			"core.close_formspec should be a function")
	end)

	T.run("core.registered_items exists", function()
		T.assert(type(core.registered_items) == "table",
			"core.registered_items should be a table")
	end)

	T.run("core.registered_nodes exists", function()
		T.assert(type(core.registered_nodes) == "table",
			"core.registered_nodes should be a table")
	end)

	T.run("core.cheats table exists", function()
		T.assert(type(core.cheats) == "table",
			"core.cheats should be a table")
	end)

	T.run("core.cheats has categories", function()
		T.assert(next(core.cheats) ~= nil,
			"core.cheats should have entries")
	end)

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

	T.run("core.request_http_api exists", function()
		T.assert(type(core.request_http_api) == "function",
			"core.request_http_api should be a function")
	end)

	T.run("core.show_formspec exists", function()
		T.assert(type(core.show_formspec) == "function",
			"core.show_formspec should be a function")
	end)

	T.run("settings read/write cheat settings", function()
		local saved = core.settings:get("airjump")
		core.settings:set("airjump", "true")
		T.assert_eq(core.settings:get("airjump"), "true",
			"airjump setting should roundtrip")
		core.settings:set("airjump", saved or "false")
	end)

	-- Known failures (features not yet ported from DF)
	T.known_failure("get_voxel_manip exists (needs ModApiEnv client init)", function()
		T.assert(type(core.get_voxel_manip) == "function")
	end)

	T.known_failure("get_perlin exists (needs ModApiEnv client init)", function()
		T.assert(type(core.get_perlin) == "function")
	end)

	T.run("core.get_inventory exists", function()
		T.assert(type(core.get_inventory) == "function")
	end)

	T.run("core.drop_selected_item exists", function()
		T.assert(type(core.drop_selected_item) == "function")
	end)

	T.run("core.dig_node exists", function()
		T.assert(type(core.dig_node) == "function")
	end)

	T.run("core.interact exists", function()
		T.assert(type(core.interact) == "function")
	end)

	T.run("core.make_screenshot exists", function()
		T.assert(type(core.make_screenshot) == "function")
	end)

	-- Chat commands (from builtin/client/chatcommands.lua)
	T.run("chatcommands .players registered", function()
		T.assert(core.registered_chatcommands.players ~= nil)
	end)

	T.run("chatcommands .wielded registered", function()
		T.assert(core.registered_chatcommands.wielded ~= nil)
	end)

	T.run("chatcommands .teleport registered", function()
		T.assert(core.registered_chatcommands.teleport ~= nil)
	end)

	T.run("chatcommands .kill registered", function()
		T.assert(core.registered_chatcommands.kill ~= nil)
	end)

	T.run("chatcommands .dig registered", function()
		T.assert(core.registered_chatcommands.dig ~= nil)
	end)

	T.run("chatcommands .place registered", function()
		T.assert(core.registered_chatcommands.place ~= nil)
	end)

	T.run("chatcommands .setyaw registered", function()
		T.assert(core.registered_chatcommands.setyaw ~= nil)
	end)

	T.run("chatcommands .setpitch registered", function()
		T.assert(core.registered_chatcommands.setpitch ~= nil)
	end)

	-- LocalPlayer extensions (now ported from DF, deferred until localplayer ready)
	T.defer("LocalPlayer:get_yaw exists", function()
		T.assert(type(core.localplayer.get_yaw) == "function")
	end)
	T.defer("LocalPlayer:set_yaw exists", function()
		T.assert(type(core.localplayer.set_yaw) == "function")
	end)
	T.defer("LocalPlayer:get_pitch exists", function()
		T.assert(type(core.localplayer.get_pitch) == "function")
	end)
	T.defer("LocalPlayer:set_pitch exists", function()
		T.assert(type(core.localplayer.set_pitch) == "function")
	end)
	T.defer("LocalPlayer:set_pos exists", function()
		T.assert(type(core.localplayer.set_pos) == "function")
	end)
	T.defer("LocalPlayer:get_hotbar_size exists", function()
		T.assert(type(core.localplayer.get_hotbar_size) == "function")
	end)
	T.defer("LocalPlayer:get_object exists", function()
		T.assert(type(core.localplayer.get_object) == "function")
	end)
	T.defer("LocalPlayer:set_physics_override exists", function()
		T.assert(type(core.localplayer.set_physics_override) == "function")
	end)

	-- Camera (deferred until on_camera_ready)
	T.defer("core.camera object exists", function()
		T.assert(core.camera ~= nil,
			"core.camera should exist after on_camera_ready")
	end)
end
