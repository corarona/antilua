-- Tests for AutoMiner mod and rhythmtp API

function test_autominer(T)
	T.run("rhythmtp.is_moving exists", function()
		T.assert(type(rhythmtp.is_moving) == "function")
	end)

	T.run("rhythmtp.get_target exists", function()
		T.assert(type(rhythmtp.get_target) == "function")
	end)

	T.run("rhythmtp.stop exists", function()
		T.assert(type(rhythmtp.stop) == "function")
	end)

	T.run("rhythmtp.go_to exists", function()
		T.assert(type(rhythmtp.go_to) == "function")
	end)

	T.run("rhythmtp.go_forward exists", function()
		T.assert(type(rhythmtp.go_forward) == "function")
	end)

	T.run("rhythmtp API returns correct types", function()
		T.assert(rhythmtp.is_moving() == false, "is_moving should be false initially")
		T.assert(rhythmtp.get_target() == false, "get_target should be false initially")
	end)

	T.run("autominer cheat setting exists", function()
		T.assert(core.settings:get("autominer") ~= nil)
	end)

	T.run("autominer default settings exist", function()
		T.assert(core.settings:get("autominer.lava_nodes") ~= nil)
		T.assert(core.settings:get("autominer.search_range") ~= nil)
		T.assert(core.settings:get("autominer.min_hp") ~= nil)
		T.assert(core.settings:get("autominer.lava_range") ~= nil)
	end)

	T.run("autominer lava_nodes default contains mcl_core entries", function()
		local s = core.settings:get("autominer.lava_nodes")
		T.assert(type(s) == "string")
		T.assert(s:find("mcl_core:lava_source") ~= nil)
		T.assert(s:find("default:lava_source") ~= nil)
	end)
end
