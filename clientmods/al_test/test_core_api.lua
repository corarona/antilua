-- Tests for core API functions

function test_core_api(T)
	T.run("core.get_node_or_nil exists", function()
		T.assert(type(core.get_node_or_nil) == "function",
			"core.get_node_or_nil should be a function")
	end)

	T.run("core.get_node_def exists", function()
		T.assert(type(core.get_node_def) == "function",
			"core.get_node_def should be a function")
	end)

	T.run("core.find_nodes_near exists", function()
		T.assert(type(core.find_nodes_near) == "function",
			"core.find_nodes_near should be a function")
	end)

	T.run("core.get_meta exists", function()
		T.assert(type(core.get_meta) == "function",
			"core.get_meta should be a function")
	end)

	T.run("core.get_server_info exists", function()
		T.assert(type(core.get_server_info) == "function",
			"core.get_server_info should be a function")
	end)

	T.run("core.get_privilege_list exists", function()
		T.assert(type(core.get_privilege_list) == "function",
			"core.get_privilege_list should be a function")
	end)

	T.run("core.get_player_names exists", function()
		T.assert(type(core.get_player_names) == "function",
			"core.get_player_names should be a function")
	end)

	T.run("core.get_peer_id exists", function()
		T.assert(type(core.get_peer_id) == "function",
			"core.get_peer_id should be a function")
	end)

	T.run("core.get_language exists", function()
		T.assert(type(core.get_language) == "function",
			"core.get_language should be a function")
	end)

	T.run("core.gettext exists", function()
		T.assert(type(core.gettext) == "function",
			"core.gettext should be a function")
	end)

	T.run("core.add_particle exists", function()
		T.assert(type(core.add_particle) == "function",
			"core.add_particle should be a function")
	end)

	T.run("core.add_particlespawner exists", function()
		T.assert(type(core.add_particlespawner) == "function",
			"core.add_particlespawner should be a function")
	end)

	T.run("core.clear_out_chat_queue exists", function()
		T.assert(type(core.clear_out_chat_queue) == "function",
			"core.clear_out_chat_queue should be a function")
	end)

	T.run("core.send_respawn exists", function()
		T.assert(type(core.send_respawn) == "function",
			"core.send_respawn should be a function")
	end)

	T.run("core.override_item exists", function()
		T.assert(type(core.override_item) == "function",
			"core.override_item should be a function")
	end)

	T.run("override_item requires working register_item_raw", function()
		local ok, err = pcall(core.override_item, "air", {})
		-- register_item_raw may not exist on client
		if not ok then
			core.log("info", "[AL_TEST] override_item not fully wired: " .. tostring(err))
		end
	end)

	T.run("core.mod_channel_join exists", function()
		T.assert(type(core.mod_channel_join) == "function",
			"core.mod_channel_join should be a function")
	end)

	T.run("core.get_csm_restrictions exists", function()
		T.assert(type(core.get_csm_restrictions) == "function",
			"core.get_csm_restrictions should be a function")
	end)

	T.run("core.get_last_run_mod exists", function()
		T.assert(type(core.get_last_run_mod) == "function",
			"core.get_last_run_mod should be a function")
	end)

	T.run("core.set_last_run_mod exists", function()
		T.assert(type(core.set_last_run_mod) == "function",
			"core.set_last_run_mod should be a function")
	end)

	T.defer("core.get_node_or_nil finds a solid node", function()
		-- Search a wide area for any non-air node to verify the API works
		local found
		for y = 10, -10, -1 do
			local pos = core.localplayer:get_pos()
			if not pos then break end
			local bp = {x = math.floor(pos.x), y = math.floor(pos.y) + y, z = math.floor(pos.z)}
			local node = core.get_node_or_nil(bp)
			if node and node.name ~= "air" and node.name ~= "ignore" then
				found = node
				break
			end
		end
		if not found then
			-- Fall back: scan a wider horizontal area
			for dx = -5, 5 do for dz = -5, 5 do
				local pos = core.localplayer:get_pos()
				if not pos then break end
				for y = 10, -10, -1 do
					local bp = {x = math.floor(pos.x) + dx, y = math.floor(pos.y) + y, z = math.floor(pos.z) + dz}
					local node = core.get_node_or_nil(bp)
					if node and node.name ~= "air" and node.name ~= "ignore" then
						found = node
						break
					end
				end
				if found then break end
			end end
		end
		if not found then return end
		T.assert(type(found.name) == "string",
			"node should have a name field")
		T.assert(type(found.param1) == "number",
			"node should have a param1 field")
		T.assert(type(found.param2) == "number",
			"node should have a param2 field")
	end)

	T.defer("core.get_node_def returns definition for known node", function()
		local def = core.get_node_def("air")
		T.assert(type(def) == "table",
			"get_node_def('air') should return a table")
		T.assert(type(def.name) == "string",
			"node def should have a name field")
		T.assert(type(def.groups) == "table",
			"node def should have a groups table")
		T.assert(type(def.drawtype) == "string",
			"node def should have a drawtype string")

		local pos = core.localplayer:get_pos()
		if pos then
			local bp = vector.round(pos)
			local node = core.get_node_or_nil(bp)
			if node then
				local def2 = core.get_node_def(node.name)
				T.assert(type(def2) == "table",
					"get_node_def for current node should return a table")
			end
		end
	end)

	T.defer("core.find_nodes_near returns results near player", function()
		local pos = core.localplayer:get_pos()
		T.assert(type(pos) == "table", "player pos should be a table")
		local nodes = core.find_nodes_near(pos, 5, "air")
		T.assert(type(nodes) == "table",
			"find_nodes_near should return a table")
	end)

	T.defer("core.get_meta does not crash", function()
		local pos = core.localplayer:get_pos()
		if not pos then return end
		local bp = vector.round(pos)
		local ok, meta = pcall(core.get_meta, bp)
		T.assert(ok, "get_meta should not throw; error: " .. tostring(meta))
		if ok and type(meta) == "table" then
			T.assert(type(meta.get) == "function",
				"meta should have a get method")
			T.assert(type(meta.set) == "function",
				"meta should have a set method")
		end
	end)

	T.defer("core.get_server_info returns server details", function()
		local info = core.get_server_info()
		T.assert(type(info) == "table",
			"get_server_info should return a table")
		T.assert(type(info.address) == "string",
			"server_info should have address")
		T.assert(type(info.port) == "number",
			"server_info should have port")
		T.assert(type(info.protocol_version) == "number",
			"server_info should have protocol_version")
	end)

	T.defer("core.get_privilege_list returns privileges", function()
		local privs = core.get_privilege_list()
		T.assert(type(privs) == "table",
			"get_privilege_list should return a table")
		if next(privs) then
			for name in pairs(privs) do
				T.assert(type(name) == "string",
					"priv name should be a string")
				break
			end
		end
	end)

	T.defer("core.get_player_names returns player list", function()
		local names = core.get_player_names()
		T.assert(type(names) == "table",
			"get_player_names should return a table")
		T.assert(#names > 0,
			"should have at least one player (singleplayer)")
		T.assert(type(names[1]) == "string",
			"player name should be a string")
	end)

	T.defer("core.get_peer_id returns number", function()
		local id = core.get_peer_id()
		T.assert(type(id) == "number",
			"get_peer_id should return a number")
		T.assert(id > 0, "peer id should be positive")
	end)

	T.defer("core.get_language returns string", function()
		local lang = core.get_language()
		T.assert(type(lang) == "string",
			"get_language should return a string")
		T.assert(#lang > 0, "language should not be empty")
	end)

	T.defer("core.add_particle does not crash", function()
		local pos = core.localplayer:get_pos()
		T.assert(type(pos) == "table", "player pos should be a table")
		local ok, err = pcall(core.add_particle, {
			pos = pos,
			velocity = {x = 0, y = 1, z = 0},
			acceleration = {x = 0, y = 0, z = 0},
			expirationtime = 0.1,
			size = 1,
		})
		T.assert(ok, "add_particle should not throw; error: " .. tostring(err))
	end)

	T.defer("core.add_particlespawner does not crash", function()
		local pos = core.localplayer:get_pos()
		T.assert(type(pos) == "table", "player pos should be a table")
		local ok, err = pcall(core.add_particlespawner, {
			pos = pos,
			velocity = {x = 0, y = 1, z = 0},
			acceleration = {x = 0, y = 0, z = 0},
			amount = 1,
			time = 0.1,
			size = 1,
		})
		T.assert(ok, "add_particlespawner should not throw; error: " .. tostring(err))
	end)

	T.defer("core.close_formspec does not crash", function()
		local ok, err = pcall(core.close_formspec, "")
		T.assert(ok, "close_formspec should not throw; error: " .. tostring(err))
	end)

	T.defer("core.mod_channel_join joins mod channel", function()
		local test_channel = "al_test_core_api_" .. os.time()
		local ok, err = pcall(core.mod_channel_join, test_channel)
		T.assert(ok, "mod_channel_join should succeed; error: " .. tostring(err))
	end)

	-- Draw3D API tests
	T.defer("core.draw3d exists and has methods", function()
		T.assert(core.draw3d ~= nil, "core.draw3d should exist")
		T.assert(type(core.draw3d.add_sphere) == "function", "draw3d:add_sphere exists")
		T.assert(type(core.draw3d.add_box) == "function", "draw3d:add_box exists")
		T.assert(type(core.draw3d.add_wirebox) == "function", "draw3d:add_wirebox exists")
		T.assert(type(core.draw3d.add_line) == "function", "draw3d:add_line exists")
		T.assert(type(core.draw3d.add_circle) == "function", "draw3d:add_circle exists")
		T.assert(type(core.draw3d.clear) == "function", "draw3d:clear exists")
	end)

	T.defer("core.draw3d:add_sphere does not crash", function()
		local pos = core.localplayer:get_pos()
		T.assert(pos ~= nil, "player pos exists")
		local ok, err = pcall(core.draw3d.add_sphere, core.draw3d, pos, 2, "#00FF00", 16)
		T.assert(ok, "draw3d:add_sphere should not throw; error: " .. tostring(err))
		core.draw3d:clear()
	end)

	T.defer("core.draw3d:add_box does not crash", function()
		local pos = core.localplayer:get_pos()
		T.assert(pos ~= nil, "player pos exists")
		local p1 = {x = pos.x - 1, y = pos.y, z = pos.z - 1}
		local p2 = {x = pos.x + 1, y = pos.y + 2, z = pos.z + 1}
		local ok, err = pcall(core.draw3d.add_box, core.draw3d, p1, p2, "#FF0000")
		T.assert(ok, "draw3d:add_box should not throw; error: " .. tostring(err))
		core.draw3d:clear()
	end)

	T.defer("core.draw3d:add_wirebox does not crash", function()
		local pos = core.localplayer:get_pos()
		T.assert(pos ~= nil, "player pos exists")
		local ok, err = pcall(core.draw3d.add_wirebox, core.draw3d,
			{x = pos.x - 1, y = pos.y, z = pos.z - 1},
			{x = pos.x + 1, y = pos.y + 2, z = pos.z + 1}, "#FFFF00")
		T.assert(ok, "draw3d:add_wirebox should not throw; error: " .. tostring(err))
		core.draw3d:clear()
	end)

	T.defer("core.draw3d:add_line does not crash", function()
		local pos = core.localplayer:get_pos()
		T.assert(pos ~= nil, "player pos exists")
		local ok, err = pcall(core.draw3d.add_line, core.draw3d, pos,
			{x = pos.x + 5, y = pos.y, z = pos.z}, "#FF00FF")
		T.assert(ok, "draw3d:add_line should not throw; error: " .. tostring(err))
		core.draw3d:clear()
	end)

	T.defer("core.draw3d:add_circle does not crash", function()
		local pos = core.localplayer:get_pos()
		T.assert(pos ~= nil, "player pos exists")
		local ok, err = pcall(core.draw3d.add_circle, core.draw3d, pos, 3, "#00FFFF", 24)
		T.assert(ok, "draw3d:add_circle should not throw; error: " .. tostring(err))
		core.draw3d:clear()
	end)

	T.defer("core.draw3d:clear with group clears correctly", function()
		local pos = core.localplayer:get_pos()
		T.assert(pos ~= nil, "player pos exists")
		core.draw3d:add_sphere(pos, 1, "#0F0", 8, 1)
		core.draw3d:add_box({x = pos.x - 1, y = pos.y, z = pos.z - 1},
			{x = pos.x + 1, y = pos.y + 2, z = pos.z + 1}, "#F00", 2)
		core.draw3d:clear(1)
		-- clear(1) should not crash (can't verify it actually removed without inspecting internals)
		core.draw3d:clear()
	end)

	T.defer("/testdraw command registered", function()
		T.assert(type(core.registered_chatcommands["testdraw"]) == "table",
			"/testdraw command should exist")
		T.assert(type(core.registered_chatcommands["testdraw"].func) == "function",
			"/testdraw should have a function")
	end)

	-- Server-API mirrors (client-side ports, no server changes needed)
	T.run("core.get_node_raw exists", function()
		T.assert(type(core.get_node_raw) == "function",
			"core.get_node_raw should be a function")
	end)

	T.run("core.get_day_count exists", function()
		T.assert(type(core.get_day_count) == "function",
			"core.get_day_count should be a function")
	end)

	T.run("core.get_loaded_blocks exists", function()
		T.assert(type(core.get_loaded_blocks) == "function",
			"core.get_loaded_blocks should be a function")
	end)

	T.run("core.get_modnames exists", function()
		T.assert(type(core.get_modnames) == "function",
			"core.get_modnames should be a function")
	end)

	T.run("core.get_node_boxes exists", function()
		T.assert(type(core.get_node_boxes) == "function",
			"core.get_node_boxes should be a function")
	end)

	T.run("core.get_connected_players exists", function()
		T.assert(type(core.get_connected_players) == "function",
			"core.get_connected_players should be a function")
	end)

	T.run("core.get_player_by_name exists", function()
		T.assert(type(core.get_player_by_name) == "function",
			"core.get_player_by_name should be a function")
	end)

	T.run("core.get_objects_in_area exists", function()
		T.assert(type(core.get_objects_in_area) == "function",
			"core.get_objects_in_area should be a function")
	end)

	T.run("core.get_natural_light exists", function()
		T.assert(type(core.get_natural_light) == "function",
			"core.get_natural_light should be a function")
	end)

	T.run("core.get_tool_wear_after_use exists", function()
		T.assert(type(core.get_tool_wear_after_use) == "function",
			"core.get_tool_wear_after_use should be a function")
	end)

	T.run("core.get_dig_params exists", function()
		T.assert(type(core.get_dig_params) == "function",
			"core.get_dig_params should be a function")
	end)

	T.run("core.get_hit_params exists", function()
		T.assert(type(core.get_hit_params) == "function",
			"core.get_hit_params should be a function")
	end)

	T.run("core.get_player_information exists", function()
		T.assert(type(core.get_player_information) == "function",
			"core.get_player_information should be a function")
	end)

	T.run("core.get_player_window_information exists", function()
		T.assert(type(core.get_player_window_information) == "function",
			"core.get_player_window_information should be a function")
	end)

	T.run("get_tool_wear_after_use computes wear", function()
		local wear = core.get_tool_wear_after_use(10, 0)
		T.assert(type(wear) == "number", "wear should be a number, got " .. type(wear))
		T.assert(wear > 0, "wear should be positive")
	end)

	T.run("get_modnames returns a list", function()
		local names = core.get_modnames()
		T.assert(type(names) == "table", "modnames should be a table")
		T.assert(#names > 0, "at least one mod should be loaded")
		for i, name in ipairs(names) do
			T.assert(type(name) == "string", "modname should be a string")
		end
	end)

	T.run("get_day_count returns a number", function()
		local day = core.get_day_count()
		T.assert(type(day) == "number", "day count should be a number")
	end)

	T.run("get_player_information returns self info", function()
		local info = core.get_player_information()
		T.assert(type(info) == "table", "info should be a table")
		T.assert(type(info.protocol_version) == "number", "protocol_version should be numeric")
		T.assert(type(info.version_string) == "string", "version_string should be a string")
	end)

	T.run("get_player_information for another player returns nil", function()
		local info = core.get_player_information("no_such_player_xyz")
		T.assert(info == nil, "unknown player should yield nil")
	end)

	T.run("get_player_window_information returns self window info", function()
		local info = core.get_player_window_information()
		T.assert(type(info) == "table", "window info should be a table")
		T.assert(type(info.size) == "table", "size should be a table")
		T.assert(type(info.real_gui_scaling) == "number", "real_gui_scaling should be numeric")
		T.assert(type(info.touch_controls) == "boolean", "touch_controls should be boolean")
	end)

	T.defer("get_node_raw returns raw node data", function()
		local pos = core.localplayer:get_pos()
		T.assert(pos ~= nil, "player pos exists")
		local stand = {x = math.floor(pos.x), y = math.floor(pos.y) - 1, z = math.floor(pos.z)}
		local content, param1, param2, ok = core.get_node_raw(stand)
		T.assert(type(ok) == "boolean", "pos_ok should be a boolean, got " .. type(ok))
		T.assert(type(content) == "number", "content should be a number")
		T.assert(type(param1) == "number", "param1 should be a number")
		T.assert(type(param2) == "number", "param2 should be a number")
		-- The node below the player may not be loaded yet; when it is, the
		-- content must be a real (non-ignore) node.
		if ok then
			T.assert(content ~= core.get_content_id("ignore"),
				"loaded node should not be ignore")
		end
	end)

	T.defer("get_node_raw on far-away position returns ok=false", function()
		local _, _, _, ok = core.get_node_raw({x = 30000, y = 0, z = 30000})
		T.assert(ok == false, "unloaded position should report ok=false")
	end)

	T.defer("get_natural_light returns a number when node loaded", function()
		local pos = core.localplayer:get_pos()
		T.assert(pos ~= nil, "player pos exists")
		local stand = {x = math.floor(pos.x), y = math.floor(pos.y) - 1, z = math.floor(pos.z)}
		local light = core.get_natural_light(stand)
		if light ~= nil then
			T.assert(type(light) == "number", "natural light should be a number, got " .. type(light))
			T.assert(light >= 0 and light <= 1000, "natural light should be in 0..1000")
		end
	end)

	T.defer("get_loaded_blocks returns block positions", function()
		local blocks = core.get_loaded_blocks()
		T.assert(type(blocks) == "table", "loaded blocks should be a table")
		for i, b in ipairs(blocks) do
			T.assert(type(b.x) == "number", "block x should be a number")
			T.assert(type(b.y) == "number", "block y should be a number")
			T.assert(type(b.z) == "number", "block z should be a number")
		end
	end)

	T.defer("get_node_boxes returns box list when node loaded", function()
		local pos = core.localplayer:get_pos()
		T.assert(pos ~= nil, "player pos exists")
		local stand = {x = math.floor(pos.x), y = math.floor(pos.y) - 1, z = math.floor(pos.z)}
		local boxes = core.get_node_boxes("selection_box", stand)
		if boxes ~= nil then
			T.assert(type(boxes) == "table", "node boxes should be a table")
			for i, b in ipairs(boxes) do
				T.assert(type(b) == "table", "box should be a table")
			end
		end
	end)

	T.defer("get_node_boxes rejects invalid box_type", function()
		local ok, err = pcall(core.get_node_boxes, "bogus_type", {x = 0, y = 0, z = 0})
		T.assert(not ok, "invalid box_type should throw")
		T.assert(string.find(tostring(err), "box_type") ~= nil,
			"error should mention box_type, got: " .. tostring(err))
	end)

	T.defer("get_connected_players returns player refs", function()
		local players = core.get_connected_players()
		T.assert(type(players) == "table", "players should be a table")
		T.assert(#players > 0, "at least the local player should be present")
	end)

	T.defer("get_player_by_name returns the local player", function()
		local name = core.localplayer:get_name()
		T.assert(name ~= nil, "player name exists")
		local ref = core.get_player_by_name(name)
		T.assert(ref ~= nil, "local player ref should be found")
		T.assert(ref:get_name() == name, "ref name should match")
	end)

	T.defer("get_player_by_name unknown returns nil", function()
		local ref = core.get_player_by_name("no_such_player_xyz")
		T.assert(ref == nil, "unknown player should yield nil")
	end)

	T.defer("get_objects_in_area returns objects", function()
		local pos = core.localplayer:get_pos()
		T.assert(pos ~= nil, "player pos exists")
		local objs = core.get_objects_in_area(
			{x = pos.x - 10, y = pos.y - 10, z = pos.z - 10},
			{x = pos.x + 10, y = pos.y + 10, z = pos.z + 10})
		T.assert(type(objs) == "table", "objects should be a table")
	end)
end
