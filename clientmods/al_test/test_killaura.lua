-- Tests for killaura mod

function test_killaura(T)
	T.run("killaura cheat setting exists", function()
		T.assert(core.settings:get("killaura") ~= nil)
	end)

	T.run("killaura.hph default exists", function()
		local v = core.settings:get("killaura.hph")
		T.assert(v ~= nil)
		T.assert(tonumber(v) == 1)
	end)

	T.run("killaura.hit_y default exists", function()
		local v = core.settings:get("killaura.hit_y")
		T.assert(v ~= nil)
	end)

	T.run("killaura.range default exists", function()
		local v = core.settings:get("killaura.range")
		T.assert(v ~= nil)
		T.assert(tonumber(v) == 10)
	end)

	T.run("killaura.target_mode default exists", function()
		local v = core.settings:get("killaura.target_mode")
		T.assert(v ~= nil)
		T.assert(v == "players_enemies")
	end)

	T.run("killaura.punch_object exists", function()
		T.assert(type(killaura.punch_object) == "function")
	end)

	T.run("killaura.get exists and returns defaults", function()
		T.assert(type(killaura.get) == "function")
		T.assert(killaura.get("hph") == 1)
		T.assert(type(killaura.get("hit_y")) == "number")
	end)

	T.run("Killaura registered in Combat category", function()
		local combat = core.cheats["Combat"]
		T.assert(combat ~= nil, "Combat category exists")
		local found = false
		for name, _ in pairs(combat) do
			if name:lower() == "killaura" then
				found = true
				break
			end
		end
		T.assert(found, "Killaura found in Combat category")
	end)
end
