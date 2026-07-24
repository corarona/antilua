-- Tests for FishBot mod

function test_fishbot(T)
	T.run("fishbot cheat setting exists", function()
		T.assert(core.settings:get("fishbot") ~= nil)
	end)

	T.run("fishbot.bobber_range default exists", function()
		local v = core.settings:get("fishbot.bobber_range")
		T.assert(v ~= nil)
		T.assert(tonumber(v) == 10)
	end)

	T.run("FishBot registered in Bots category", function()
		local bots = core.cheats["Bots"]
		T.assert(bots ~= nil, "Bots category exists")
		local found = false
		for name, _ in pairs(bots) do
			if name:lower() == "fishbot" then
				found = true
				break
			end
		end
		T.assert(found, "FishBot found in Bots category")
	end)
end
