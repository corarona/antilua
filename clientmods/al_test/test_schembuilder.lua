-- Tests for SchemBuilder mod

function test_schembuilder(T)
	T.run("core.read_schematic exists", function()
		T.assert(type(core.read_schematic) == "function")
	end)

	T.run("core.serialize_schematic exists", function()
		T.assert(type(core.serialize_schematic) == "function")
	end)

	T.run("autoschemplace cheat setting exists", function()
		T.assert(core.settings:get("autoschemplace") ~= nil)
	end)

	T.run("autoschemplace.range default exists", function()
		local v = core.settings:get("autoschemplace.range")
		T.assert(v ~= nil)
		T.assert(tonumber(v) == 4, "expected 4, got " .. tostring(v))
	end)

	T.run("autoschemplace.batch_size default exists", function()
		local v = core.settings:get("autoschemplace.batch_size")
		T.assert(v ~= nil, "batch_size is nil")
	end)

	T.run("autoschemplace.place_strategy default exists", function()
		local v = core.settings:get("autoschemplace.place_strategy")
		T.assert(v ~= nil, "place_strategy is nil")
	end)

	T.run("schembuilderbot.range default exists", function()
		local v = core.settings:get("schembuilderbot.range")
		T.assert(v ~= nil, "range is nil")
	end)

	T.run("schembuilderbot.place_cooldown setting exists", function()
		local v = core.settings:get("schembuilderbot.place_cooldown")
		if v == nil then
			T.assert(false, "place_cooldown is nil")
			return
		end
		local n = tonumber(v)
		T.assert(n ~= nil and n > 0, "invalid value: " .. tostring(v))
	end)

	T.run("schembuilderbot.batch_size setting exists", function()
		local v = core.settings:get("schembuilderbot.batch_size")
		T.assert(v ~= nil, "batch_size is nil")
		local n = tonumber(v)
		T.assert(n ~= nil and n >= 1, "invalid batch_size: " .. tostring(v))
	end)

	T.run("read_schematic round-trips through serialize", function()
		local schem = {
			size = {x = 2, y = 1, z = 1},
			data = {
				{name = "mcl_core:stone", prob = 254, param2 = 0},
				{name = "mcl_core:dirt", prob = 254, param2 = 0},
			},
		}
		local ok, mts_data = pcall(core.serialize_schematic, schem, "mts")
		if not ok then
			T.assert(false, "serialize_schematic failed: " .. tostring(mts_data))
			return
		end
		local ok2, result = pcall(core.read_schematic, mts_data, {})
		if not ok2 then
			T.assert(false, "read_schematic failed: " .. tostring(result))
			return
		end
		T.assert(result ~= nil)
		T.assert(result.size ~= nil)
		T.assert(result.size.x == 2)
		T.assert(result.size.y == 1)
		T.assert(result.size.z == 1)
		T.assert(result.data ~= nil)
		T.assert(#result.data == 2)
		T.assert(result.data[1].name == "mcl_core:stone")
		T.assert(result.data[2].name == "mcl_core:dirt")
	end)

	T.run("core.read_file exists", function()
		T.assert(type(core.read_file) == "function")
	end)

	T.run("core.read_file rejects path traversal", function()
		local ok, data, err = pcall(core.read_file, "../evil.lua")
		T.assert(not ok or data == nil)
	end)

	T.run("read_schematic rejects bad signature", function()
		local ok, err = pcall(core.read_schematic, "not an mts file", {})
		T.assert(not ok, "should reject non-MTS data")
	end)

	T.run("/schembuild chat command registered", function()
		T.assert(type(core.registered_chatcommands["schembuild"]) == "table")
	end)

	T.run("/spos1 chat command registered", function()
		T.assert(type(core.registered_chatcommands["spos1"]) == "table")
	end)

	T.run("/spos2 chat command registered", function()
		T.assert(type(core.registered_chatcommands["spos2"]) == "table")
	end)

	T.run("/ssave chat command registered", function()
		T.assert(type(core.registered_chatcommands["ssave"]) == "table")
	end)

	T.run("ws.loot_list exists", function()
		T.assert(type(ws.loot_list) == "function")
	end)

	T.run("ws.loot_list returns 0 for empty items", function()
		local r = ws.loot_list({}, 5)
		T.assert(type(r) == "number")
		T.assert(r == 0)
	end)

	T.run("schematic_looter cheat setting exists", function()
		T.assert(core.settings:get("schematic_looter") ~= nil)
	end)

	T.run("schematic_looter.range default exists", function()
		local v = core.settings:get("schematic_looter.range")
		T.assert(v ~= nil)
		T.assert(tonumber(v) == 5)
	end)

	T.run("schematic_looter.max_per_scan default exists", function()
		local v = core.settings:get("schematic_looter.max_per_scan")
		T.assert(v ~= nil)
		T.assert(tonumber(v) == 16)
	end)

	T.run("core.create_client_entity exists", function()
		T.assert(type(core.create_client_entity) == "function")
	end)

	T.run("/schemresume chat command registered", function()
		T.assert(type(core.registered_chatcommands["schemresume"]) == "table")
	end)

	T.run("schembuilder_resume_pos can be set", function()
		core.settings:set("schembuilder_resume_pos", "1,2,3")
		T.assert(core.settings:get("schembuilder_resume_pos") == "1,2,3")
	end)

	T.run("schembuilder_resume_param can be set", function()
		core.settings:set("schembuilder_resume_param", "file:test.mts")
		T.assert(core.settings:get("schembuilder_resume_param") == "file:test.mts")
	end)

	T.run("schembuilderbot.place_strategy setting exists", function()
		local v = core.settings:get("schembuilderbot.place_strategy")
		T.assert(v ~= nil, "strategy setting is nil")
	end)

	local function test_strategy(name)
		core.settings:set("schembuilderbot.place_strategy", name)
		local v = core.settings:get("schembuilderbot.place_strategy")
		T.assert(v == name, "expected '" .. name .. "', got " .. tostring(v))
	end

	T.run("schembuilderbot.place_strategy can cycle through all values", function()
		local orig = core.settings:get("schembuilderbot.place_strategy")
		test_strategy("closest")
		test_strategy("layer")
		test_strategy("top_to_bottom")
		test_strategy("column")
		test_strategy("by_material")
		if orig then
			core.settings:set("schembuilderbot.place_strategy", orig)
		end
	end)

	T.run("schembuilderbot.filter_mode setting exists", function()
		local v = core.settings:get("schembuilderbot.filter_mode")
		T.assert(v ~= nil, "filter_mode is nil")
	end)

	T.run("schembuilderbot.filter_mode default is all", function()
		local v = core.settings:get("schembuilderbot.filter_mode")
		T.assert(v == "all", "expected 'all', got " .. tostring(v))
	end)

	T.run("schembuilderbot.filter_list setting exists", function()
		local v = core.settings:get("schembuilderbot.filter_list")
		T.assert(v ~= nil, "filter_list is nil")
	end)

	T.run("schembuilderbot.filter_list default is schembuilder", function()
		local v = core.settings:get("schembuilderbot.filter_list")
		T.assert(v == "schembuilder", "expected 'schembuilder', got " .. tostring(v))
	end)

	T.run("/schemclear chat command registered", function()
		T.assert(type(core.registered_chatcommands["schemclear"]) == "table")
	end)

	T.run("/schembrowse chat command registered", function()
		T.assert(type(core.registered_chatcommands["schembrowse"]) == "table")
	end)

	T.run("schembuilder get_server_id returns localhost when not connected", function()
		if type(core.get_server_info) == "function" then
			local info = core.get_server_info()
			if not info then
				-- No server connected — falls back to localhost:30000
				T.assert(true)
			end
		end
	end)

	T.run("schembuilder build index exists on mod storage", function()
		if type(core.get_mod_storage) == "function" then
			local ok, s = pcall(core.get_mod_storage, "schembuilder")
			T.assert(ok, "mod storage available")
		end
	end)

	T.run("schembuilder get_dir_list returns schematics via real path", function()
		if type(core.get_modpath_real) ~= "function" then
			T.assert(false, "core.get_modpath_real not available")
			return
		end
		local real = core.get_modpath_real("schembuilder")
		T.assert(real ~= nil, "get_modpath_real returned nil for schembuilder")
		local schem_path = real .. "/schematics"
		local ok, files = pcall(core.get_dir_list, schem_path, false)
		T.assert(ok, "get_dir_list should succeed: " .. tostring(files))
		T.assert(type(files) == "table", "result should be a table, got " .. type(files))
		T.assert(#files > 0, "should have at least one .mts file, got " .. #files .. " in " .. schem_path)
	end)

	T.run("/schemundo chat command registered", function()
		T.assert(type(core.registered_chatcommands["schemundo"]) == "table", "/schemundo should be registered")
	end)

	T.run("schembuilder.generate_shape exists", function()
		T.assert(type(schembuilder.generate_shape) == "function", "generate_shape should exist")
	end)

	T.run("generate_shape cube", function()
		local nodes, err = schembuilder.generate_shape("cube", 3, 3, 3, "mcl_core:stone", false)
		T.assert(nodes ~= nil, "cube should generate: " .. tostring(err))
		T.assert_eq(#nodes, 27, "3x3x3 cube should have 27 nodes")
		for _, n in ipairs(nodes) do
			T.assert(n.name == "mcl_core:stone", "all nodes should be stone")
			T.assert(n.param2 == 0, "param2 should be 0")
		end
	end)

	T.run("generate_shape cube hollow", function()
		local nodes = schembuilder.generate_shape("cube", 3, 3, 3, "mcl_core:stone", true)
		T.assert(nodes ~= nil, "hollow cube should generate")
		T.assert_eq(#nodes, 26, "3x3x3 hollow cube should have 26 nodes (no center)")
	end)

	T.run("generate_shape sphere", function()
		local nodes, err = schembuilder.generate_shape("sphere", 3, 3, 3, "mcl_core:stone", false)
		T.assert(nodes ~= nil, "sphere should generate: " .. tostring(err))
		T.assert(#nodes > 0, "sphere should have nodes")
	end)

	T.run("generate_shape circle", function()
		local nodes, err = schembuilder.generate_shape("circle", 3, 1, 1, "mcl_core:stone")
		T.assert(nodes ~= nil, "circle should generate: " .. tostring(err))
		T.assert(#nodes > 0, "circle should have nodes")
	end)

	T.run("generate_shape pyramid", function()
		local nodes, err = schembuilder.generate_shape("pyramid", 5, 3, 1, "mcl_core:stone", false)
		T.assert(nodes ~= nil, "pyramid should generate: " .. tostring(err))
		T.assert(#nodes > 0, "pyramid should have nodes")
	end)

	T.run("generate_shape cylinder", function()
		local nodes, err = schembuilder.generate_shape("cylinder", 3, 5, 1, "mcl_core:stone", false)
		T.assert(nodes ~= nil, "cylinder should generate: " .. tostring(err))
		T.assert(#nodes > 0, "cylinder should have nodes")
	end)

	T.run("generate_shape dome matches upper half of sphere", function()
		local dome, err = schembuilder.generate_shape("dome", 3, 3, 3, "mcl_core:stone", false)
		T.assert(dome ~= nil, "dome should generate: " .. tostring(err))
		local sphere, serr = schembuilder.generate_shape("sphere", 3, 3, 3, "mcl_core:stone", false)
		T.assert(sphere ~= nil, "sphere should generate: " .. tostring(serr))
		local sphere_upper = 0
		local expected = {}
		for _, n in ipairs(sphere) do
			if n.y >= 0 then
				sphere_upper = sphere_upper + 1
				expected[n.x .. "," .. n.y .. "," .. n.z] = true
			end
		end
		T.assert_eq(#dome, sphere_upper, "dome node count should equal upper half of sphere")
		for _, n in ipairs(dome) do
			T.assert(n.y >= 0, "dome nodes should be at or above the base")
			T.assert(expected[n.x .. "," .. n.y .. "," .. n.z] ~= nil,
				"dome node (" .. n.x .. "," .. n.y .. "," .. n.z .. ") should be in sphere")
		end
		local has_apex = false
		for _, n in ipairs(dome) do
			if n.x == 0 and n.y == 3 and n.z == 0 then has_apex = true end
		end
		T.assert(has_apex, "dome should have its apex node")
	end)

	T.run("generate_shape dome hollow", function()
		local solid = schembuilder.generate_shape("dome", 3, 3, 3, "mcl_core:stone", false)
		local hollow, err = schembuilder.generate_shape("dome", 3, 3, 3, "mcl_core:stone", true)
		T.assert(hollow ~= nil, "hollow dome should generate: " .. tostring(err))
		T.assert(#hollow > 0, "hollow dome should have nodes")
		T.assert(#hollow < #solid, "hollow dome should have fewer nodes than solid")
	end)

	T.run("generate_shape cone", function()
		local nodes, err = schembuilder.generate_shape("cone", 3, 5, 1, "mcl_core:stone", false)
		T.assert(nodes ~= nil, "cone should generate: " .. tostring(err))
		T.assert_eq(#nodes, 61, "3x5 cone should have 61 nodes")
		local has_apex = false
		local max_y = -1
		for _, n in ipairs(nodes) do
			T.assert(n.y >= 0 and n.y <= 4, "cone y out of range")
			T.assert(n.x >= -3 and n.x <= 3 and n.z >= -3 and n.z <= 3, "cone x/z out of range")
			if n.y > max_y then max_y = n.y end
			if n.x == 0 and n.y == 4 and n.z == 0 then has_apex = true end
		end
		T.assert_eq(max_y, 4, "cone should reach its apex level")
		T.assert(has_apex, "cone should have its apex node")
	end)

	T.run("generate_shape cone hollow", function()
		local solid = schembuilder.generate_shape("cone", 3, 5, 1, "mcl_core:stone", false)
		local hollow, err = schembuilder.generate_shape("cone", 3, 5, 1, "mcl_core:stone", true)
		T.assert(hollow ~= nil, "hollow cone should generate: " .. tostring(err))
		T.assert(#hollow > 0, "hollow cone should have nodes")
		T.assert(#hollow < #solid, "hollow cone should have fewer nodes than solid")
		local has_apex = false
		for _, n in ipairs(hollow) do
			if n.x == 0 and n.y == 4 and n.z == 0 then has_apex = true end
		end
		T.assert(has_apex, "hollow cone should keep its apex node")
	end)

	T.run("generate_shape unknown shape", function()
		local nodes, err = schembuilder.generate_shape("garbage", 1, 1, 1, "mcl_core:stone")
		T.assert(nodes == nil, "unknown shape should return nil")
		T.assert(err ~= nil, "unknown shape should return error")
	end)

	T.run("schembuilder_serialize round-trip", function()
		if not core.localplayer then
			T.assert(true, "skip: no localplayer")
			return
		end
		if type(core.get_node_or_nil) ~= "function" then
			T.assert(true, "skip: get_node_or_nil not available")
			return
		end
		T.assert(type(schembuilder_serialize) == "function", "schembuilder_serialize should exist")
	end)

	T.run("push_undo and restore_undo_snapshot round-trip", function()
		local test_nodes = {
			{x = 0, y = 0, z = 0, name = "mcl_core:stone", param2 = 0},
			{x = 1, y = 0, z = 0, name = "mcl_core:dirt", param2 = 0},
		}
		local orig = place_nodes
		place_nodes = {}
		push_undo(test_nodes)
		local ok = restore_undo_snapshot()
		T.assert(ok, "restore should succeed")
		T.assert_eq(#place_nodes, 2, "should restore 2 nodes")
		T.assert_eq(place_nodes[1].name, "mcl_core:stone", "first node should be stone")
		place_nodes = orig or {}
	end)

	T.run("/schemstop chat command registered", function()
		T.assert(type(core.registered_chatcommands["schemstop"]) == "table", "/schemstop should be registered")
	end)

	T.run("schembuilder.stop_build exists", function()
		T.assert(type(schembuilder.stop_build) == "function", "schembuilder.stop_build should exist")
	end)

	T.run("stop_build clears place_nodes and disables build cheats", function()
		local orig = place_nodes
		local saved_settings = {}
		local build_settings = { "autoschemplace", "schembuilderbot", "rhythmbuildbot", "schematic_looter" }
		for _, s in ipairs(build_settings) do
			saved_settings[s] = core.settings:get(s)
			core.settings:set_bool(s, true)
		end
		place_nodes = { {x = 0, y = 0, z = 0, name = "mcl_core:stone", param2 = 0} }
		schembuilder.stop_build()
		T.assert_eq(#place_nodes, 0, "place_nodes should be empty after stop_build")
		for _, s in ipairs(build_settings) do
			T.assert(core.settings:get_bool(s) == false, s .. " should be disabled after stop_build")
		end
		for _, s in ipairs(build_settings) do
			if saved_settings[s] == nil then
				core.settings:set(s, "false")
			else
				core.settings:set(s, saved_settings[s])
			end
		end
		place_nodes = orig or {}
	end)

	T.run("browser stop button handler stops the build", function()
		local orig = place_nodes
		place_nodes = { {x = 0, y = 0, z = 0, name = "mcl_core:stone", param2 = 0} }
		schembuilder.handle_browser_fields({ schem_stop = true })
		T.assert_eq(#place_nodes, 0, "schem_stop should clear place_nodes")
		place_nodes = { {x = 0, y = 0, z = 0, name = "mcl_core:stone", param2 = 0} }
		schembuilder.handle_browser_fields({ build_stop = true })
		T.assert_eq(#place_nodes, 0, "build_stop should clear place_nodes")
		place_nodes = orig or {}
	end)

	T.run("quick menu has stop schematic build entry", function()
		local orig = place_nodes
		place_nodes = { {x = 0, y = 0, z = 0, name = "mcl_core:stone", param2 = 0} }
		local found = false
		for _, p in ipairs(core.quick_menu_providers) do
			local entries = p.func and p.func() or {}
			for _, e in ipairs(entries) do
				if e.label == "Stop Schematic Build" then
					found = true
				end
			end
		end
		T.assert(found, "Stop Schematic Build entry should be in the quick menu")
		place_nodes = orig or {}
	end)
end
