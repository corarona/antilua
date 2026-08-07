-- Tests for ExploreBot mod

function test_explorebot(T)
	T.run("explorebot cheat setting exists", function()
		T.assert(core.settings:get("explorebot") ~= nil)
	end)

	T.run("ExploreBot registered in Bots category", function()
		local bots = core.cheats["Bots"]
		T.assert(bots ~= nil, "Bots category exists")
		local found = false
		for name, _ in pairs(bots) do
			if name:lower() == "explorebot" then
				found = true
				break
			end
		end
		T.assert(found, "ExploreBot found in Bots category")
	end)

	T.run("explorebot default settings exist", function()
		T.assert(core.settings:get("explorebot.step") ~= nil)
		T.assert(core.settings:get("explorebot.max_radius") ~= nil)
		T.assert(core.settings:get("explorebot.hover_height") ~= nil)
		T.assert(core.settings:get("explorebot.speed") ~= nil)
		T.assert(core.settings:get("explorebot.capture_timeout") ~= nil)
	end)

	T.run("explorebot settings round-trip", function()
		local orig = core.settings:get("explorebot.step")
		core.settings:set("explorebot.step", "32")
		T.assert_eq(tonumber(core.settings:get("explorebot.step")), 32,
			"step should round-trip")
		core.settings:set("explorebot.step", orig or "16")
	end)

	T.run("explorebot bigmap dependency exists", function()
		T.assert(type(core.al_bigmap) == "table", "core.al_bigmap is a table")
		T.assert(type(core.al_bigmap.has_block) == "function",
			"has_block should be a function")
		T.assert(type(core.al_bigmap.get_pixel) == "function",
			"get_pixel should be a function")
	end)
end
