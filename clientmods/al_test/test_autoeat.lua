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

	T.run("get_hunger returns full when no hunger bar", function()
		autoeat._reset()
		T.assert_eq(autoeat.get_hunger(), 20, "get_hunger should default to 20")
	end)

	T.run("hud_add of hunger bar sets initial hunger", function()
		autoeat._reset()
		autoeat._on_hud_add({ server_id = 7, text = "hbhunger_icon.png", number = 12, item = 20 })
		T.assert_eq(autoeat.get_hunger(), 12, "initial hunger should be 12")
	end)

	T.run("hud_change number updates hunger", function()
		autoeat._reset()
		autoeat._on_hud_add({ server_id = 7, text = "hbhunger_icon.png", number = 12, item = 20 })
		autoeat._on_hud_change(7, 4, "", { x = 0, y = 0 }, { x = 0, y = 0, z = 0 }, 5)
		T.assert_eq(autoeat.get_hunger(), 5, "hunger should update to 5")
	end)

	T.run("hud_change for other elements is ignored", function()
		autoeat._reset()
		autoeat._on_hud_add({ server_id = 7, text = "hbhunger_icon.png", number = 12, item = 20 })
		autoeat._on_hud_change(99, 4, "", { x = 0, y = 0 }, { x = 0, y = 0, z = 0 }, 2)
		T.assert_eq(autoeat.get_hunger(), 12, "unrelated element should not change hunger")
	end)

	T.run("hud_change item 0 treats hunger as full", function()
		autoeat._reset()
		autoeat._on_hud_add({ server_id = 7, text = "hbhunger_icon.png", number = 4, item = 20 })
		autoeat._on_hud_change(7, 5, "", { x = 0, y = 0 }, { x = 0, y = 0, z = 0 }, 0)
		T.assert_eq(autoeat.get_hunger(), 20, "hidden bar should be treated as full")
	end)

	T.run("hud_remove resets hunger", function()
		autoeat._reset()
		autoeat._on_hud_add({ server_id = 7, text = "hbhunger_icon.png", number = 12, item = 20 })
		autoeat._on_hud_remove(7)
		T.assert_eq(autoeat.get_hunger(), 20, "removed bar should reset to full")
	end)

	T.run("progress_bar hunger bar is scaled", function()
		autoeat._reset()
		autoeat._on_hud_add({ server_id = 8, text = "hbhunger_bar.png", number = 80, item = 20 })
		T.assert_eq(autoeat.get_hunger(), 10, "progress bar 80/160 should be hunger 10")
	end)

	T.run("custom statbar length is normalized", function()
		autoeat._reset()
		autoeat._on_hud_add({ server_id = 9, text = "hbhunger_icon.png", number = 12, item = 16 })
		T.assert_eq(autoeat.get_hunger(), 15, "12/16 pips should be hunger 15")
	end)

	T.run("hunger_threshold setting exists", function()
		T.assert(core.settings:get("autoeat.hunger_threshold") ~= nil, "hunger_threshold should exist")
	end)

	T.run("eat_on_taking_damage setting defaults to true", function()
		T.assert_eq(core.settings:get("autoeat.eat_on_taking_damage"), "true",
			"eat_on_taking_damage should default to true")
	end)

	T.run("eat_on_taking_damage toggles", function()
		local orig = core.settings:get("autoeat.eat_on_taking_damage")
		core.settings:set("autoeat.eat_on_taking_damage", "false")
		T.assert_eq(core.settings:get("autoeat.eat_on_taking_damage"), "false")
		core.settings:set("autoeat.eat_on_taking_damage", "true")
		if orig then core.settings:set("autoeat.eat_on_taking_damage", orig) end
	end)

	T.run("damage handler no-ops when autoeat disabled", function()
		autoeat._reset()
		local orig = core.settings:get("autoeat")
		core.settings:set("autoeat", "false")
		local ok = pcall(autoeat._on_damage_taken, 5)
		T.assert(ok, "damage handler should not error when autoeat is disabled")
		core.settings:set("autoeat", "true")
		if orig then core.settings:set("autoeat", orig) end
	end)

	T.run("poison detection: name", function()
		T.assert(autoeat._is_poison_food("mcl_farming:potato_poison", { groups = { food = 1 } }),
			"poison in item name should be detected")
	end)

	T.run("poison detection: description", function()
		T.assert(autoeat._is_poison_food("mcl_farming:poisonous_potato",
			{ groups = { food = 1 }, description = "Poisonous Potato" }),
			"poison in description should be detected")
	end)

	T.run("poison detection: short_description", function()
		T.assert(autoeat._is_poison_food("some_mod:weird_food",
			{ groups = { food = 1 }, short_description = "Poisonous snack" }),
			"poison in short_description should be detected")
	end)

	T.run("poison detection: case insensitive", function()
		T.assert(autoeat._is_poison_food("some_mod:PoisonApple",
			{ groups = { food = 1 } }),
			"capitalized poison should be detected")
	end)

	T.run("poison detection: clean food passes", function()
		T.assert(not autoeat._is_poison_food("mcl_core:apple",
			{ groups = { food = 1 }, description = "Apple" }),
			"clean food should not be flagged")
	end)

	T.run("poison detection: nil description is safe", function()
		T.assert(not autoeat._is_poison_food("mcl_core:apple", { groups = { food = 1 } }),
			"missing description should not error")
	end)

	T.run("eat() runs without error", function()
		local ok = pcall(autoeat.eat)
		T.assert(ok, "eat() should not error")
	end)
end
