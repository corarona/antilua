-- Tests for combat mod (killaura + PatrolGuard)

function test_combat(T)
	T.run("killaura cheat setting exists", function()
		T.assert(core.settings:get("killaura") ~= nil)
	end)

	T.run("killaura.range setting exists", function()
		local v = core.settings:get("killaura.range")
		T.assert(v ~= nil, "killaura.range should exist")
	end)

	T.run("killaura.attack_mobs setting exists", function()
		local v = core.settings:get("killaura.attack_mobs")
		T.assert(v ~= nil, "killaura.attack_mobs should exist")
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

	T.run("killaura.range accepts boundary values", function()
		core.settings:set("killaura.range", "1")
		T.assert_eq(tonumber(core.settings:get("killaura.range")), 1, "range min should work")
		core.settings:set("killaura.range", "30")
		T.assert_eq(tonumber(core.settings:get("killaura.range")), 30, "range max should work")
		core.settings:set("killaura.range", "5")
	end)

	-- PatrolGuard tests are deferred because the bot is registered
	-- in combat's on_mods_loaded callback (fires after al_test's)
	T.defer("PatrolGuard bot registered", function()
		T.assert(core.settings:get("patrolguard") ~= nil, "patrolguard setting should exist")
	end)

	T.defer("patrolguard settings exist", function()
		T.assert(core.settings:get("patrolguard.scan_range") ~= nil)
		T.assert(core.settings:get("patrolguard.patrol_radius") ~= nil)
	end)
end
