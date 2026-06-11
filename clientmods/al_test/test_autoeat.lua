-- Tests for autoeat mod

function test_autoeat(T)
	T.run("autoeat setting exists", function()
		T.assert(core.settings:get("autoeat") ~= nil, "autoeat setting should exist")
	end)

	T.run("autoeat toggles without error", function()
		local orig = core.settings:get("autoeat")
		core.settings:set("autoeat", "true")
		T.assert_eq(core.settings:get("autoeat"), "true", "autoeat should be true")
		core.settings:set("autoeat", "false")
		if orig then core.settings:set("autoeat", orig) end
	end)
end
