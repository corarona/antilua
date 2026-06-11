-- Tests for SchemBuilder mod

function test_schembuilder(T)
	T.run("core.read_schematic exists", function()
		T.assert(type(core.read_schematic) == "function")
	end)

	T.run("core.serialize_schematic exists", function()
		T.assert(type(core.serialize_schematic) == "function")
	end)

	T.run("placelitem cheat setting exists", function()
		T.assert(core.settings:get("placelitem") ~= nil)
	end)

	T.run("placelitem.range default exists", function()
		local v = core.settings:get("placelitem.range")
		T.assert(v ~= nil)
		T.assert(tonumber(v) == 4)
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

	T.run("schembuilderbot.strategy setting exists", function()
		local v = core.settings:get("schembuilderbot.strategy")
		T.assert(v ~= nil, "strategy setting is nil")
	end)

	T.run("schembuilderbot.strategy can be set to layer then restored to closest", function()
		core.settings:set("schembuilderbot.strategy", "layer")
		local v = core.settings:get("schembuilderbot.strategy")
		T.assert(v == "layer", "expected 'layer', got " .. tostring(v))
		core.settings:set("schembuilderbot.strategy", "closest")
		v = core.settings:get("schembuilderbot.strategy")
		T.assert(v == "closest", "expected 'closest', got " .. tostring(v))
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
end
