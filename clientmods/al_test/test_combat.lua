-- Tests for combat mod (killaura + PatrolGuard)

function test_combat(T)
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

	T.run("killaura.target_mode can be set and read", function()
		local orig = core.settings:get("killaura.target_mode")
		core.settings:set("killaura.target_mode", "hunter")
		T.assert_eq(core.settings:get("killaura.target_mode"), "hunter",
			"target_mode should round-trip through settings")
		core.settings:set("killaura.target_mode", orig or "aggressive")
	end)

	T.run("killaura.get exists and returns defaults", function()
		T.assert(type(killaura.get) == "function")
		T.assert(killaura.get("hph") == 1)
		T.assert(type(killaura.get("hit_y")) == "number")
		T.assert(killaura.get("range") == 10)
	end)

	T.run("killaura.get returns nil for unknown keys", function()
		T.assert(killaura.get("nonexistent_key_xyz") == nil)
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

	T.run("killaura.target_mode accepts new strategy values", function()
		local modes = {"aggressive", "neutral", "retaliate", "guard", "hunter"}
		for _, mode in ipairs(modes) do
			core.settings:set("killaura.target_mode", mode)
			local v = core.settings:get("killaura.target_mode")
			T.assert_eq(v, mode, "target_mode should be settable to " .. mode)
		end
	end)

	T.run("killaura settings persist through toggle", function()
		local orig = core.settings:get("killaura.hph")
		core.settings:set("killaura.hph", "5")
		T.assert_eq(tonumber(core.settings:get("killaura.hph")), 5, "hph should be 5")
		core.settings:set("killaura.hph", orig or "1")
	end)

	T.run("killaura.range accepts boundary values", function()
		core.settings:set("killaura.range", "1")
		T.assert_eq(tonumber(core.settings:get("killaura.range")), 1, "range min should work")
		core.settings:set("killaura.range", "30")
		T.assert_eq(tonumber(core.settings:get("killaura.range")), 30, "range max should work")
		core.settings:set("killaura.range", "10")
	end)

	T.run("killaura.mace_fall_distance default is 10", function()
		local v = core.settings:get("killaura.mace_fall_distance")
		T.assert(v ~= nil, "killaura.mace_fall_distance setting should exist")
		T.assert_eq(tonumber(v), 10, "mace_fall_distance default should be 10")
	end)

	T.run("killaura.make_filter exists", function()
		T.assert(type(killaura.make_filter) == "function")
		T.assert(type(killaura.make_filter("aggressive")) == "function")
	end)

	T.run("killaura.resolve_mode maps old names", function()
		T.assert_eq(killaura.resolve_mode("players_enemies"), "neutral")
		T.assert_eq(killaura.resolve_mode("players_all"), "aggressive")
		T.assert_eq(killaura.resolve_mode("mobs"), "neutral")
		T.assert_eq(killaura.resolve_mode("all"), "aggressive")
		T.assert_eq(killaura.resolve_mode("aggressive"), "aggressive")
		T.assert_eq(killaura.resolve_mode(nil), "aggressive")
	end)

	-- PatrolGuard tests are deferred because the bot is registered
	-- in combat's on_mods_loaded callback (fires after al_test's)
	T.defer("PatrolGuard bot registered", function()
		T.assert(core.settings:get("patrolguard") ~= nil, "patrolguard setting exists")
		local bots = core.cheats["Bots"]
		if bots then
			local found = false
			for name, _ in pairs(bots) do
				if name:lower() == "patrolguard" then
					found = true
					break
				end
			end
			T.assert(found, "PatrolGuard found in Bots category")
		end
	end)

	T.defer("patrolguard settings exist", function()
		T.assert(core.settings:get("patrolguard.scan_range") ~= nil)
		T.assert(core.settings:get("patrolguard.patrol_radius") ~= nil)
	end)
end
