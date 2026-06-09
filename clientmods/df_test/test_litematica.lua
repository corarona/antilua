-- Tests for litematica mod

function test_litematica(T)
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

	T.run("/liteload chat command registered", function()
		T.assert(type(core.registered_chatcommands["liteload"]) == "table")
	end)

	T.run("/litepos1 chat command registered", function()
		T.assert(type(core.registered_chatcommands["litepos1"]) == "table")
	end)

	T.run("/litepos2 chat command registered", function()
		T.assert(type(core.registered_chatcommands["litepos2"]) == "table")
	end)

	T.run("/litesave chat command registered", function()
		T.assert(type(core.registered_chatcommands["litesave"]) == "table")
	end)
end
