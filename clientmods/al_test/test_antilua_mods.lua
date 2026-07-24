-- Tests for ANTILUA modpack mods

function test_antilua_wasplib(T)
	T.run("ws namespace exists", function()
		T.assert(type(ws) == "table", "ws should be a table")
	end)

	T.run("ws.s exists", function()
		T.assert(type(ws.s) == "function", "ws.s should be a function")
	end)

	T.run("ws.dircoord exists", function()
		T.assert(type(ws.dircoord) == "function", "ws.dircoord should be a function")
	end)

	T.run("ws.switch_to_item exists", function()
		T.assert(type(ws.switch_to_item) == "function", "ws.switch_to_item should be a function")
	end)

	T.run("ws.place exists", function()
		T.assert(type(ws.place) == "function", "ws.place should be a function")
	end)

	T.run("ws.dig exists", function()
		T.assert(type(ws.dig) == "function", "ws.dig should be a function")
	end)

	T.run("ws.rg exists", function()
		T.assert(type(ws.rg) == "function", "ws.rg should be a function")
	end)
end

function test_antilua_lockview(T)
	T.run("lockview cheat setting exists", function()
		local val = core.settings:get("lockview")
		T.assert(val ~= nil, "setting 'lockview' should exist")
	end)
end

function test_antilua_headsaver(T)
	T.run("headsaver cheat setting exists", function()
		local val = core.settings:get("headsaver")
		T.assert(val ~= nil, "setting 'headsaver' should exist")
	end)
end

-- anti_tower removed during modpack consolidation

function test_antilua_autoevade(T)
	T.run("autoevade cheat setting exists", function()
		local val = core.settings:get("autoevade")
		T.assert(val ~= nil, "setting 'autoevade' should exist")
	end)
end

function test_antilua_extracted_features(T)
	T.run("ws.make_blocks exists", function()
		T.assert(type(ws.make_blocks) == "function", "ws.make_blocks should be a function")
	end)
end

function test_ws_rg_new_api(T)
	T.run("ws.rg with table def registers setting", function()
		local setting = "test_rg_table"
		ws.rg("TestRGTable", {
			category = "Test",
			setting = setting,
			on_step = function() end,
		})
		local val = core.settings:get(setting)
		T.assert(val ~= nil, "setting '" .. setting .. "' should exist after ws.rg with table")
	end)

	T.run("ws.rg table def on_step receives self and dtime", function()
		local called = false
		local received_self = nil
		local received_dtime = nil
		ws.rg("TestRGArgs", {
			category = "Test",
			setting = "test_rg_args",
			on_step = function(self, dtime)
				called = true
				received_self = self
				received_dtime = dtime
			end,
		})
		T.assert(type(ws.registered_globalhacks) == "table", "globalhacks table exists")
	end)

	T.run("ws.rg table def defaults via metatable", function()
		ws.rg("TestRGDefaults", {
			category = "Test",
			setting = "test_rg_defaults",
		})
		T.assert(type(core.settings:get("test_rg_defaults")) == "string",
			"setting should exist with default value")
	end)
end

function test_always_day(T)
	T.run("register_on_time_of_day exists", function()
		T.assert(type(core.register_on_time_of_day) == "function",
			"register_on_time_of_day should be a function")
	end)

	T.run("always_day setting defaults to false", function()
		T.assert(type(core.settings:get("always_day")) == "string",
			"always_day setting should exist")
	end)
end

function test_clean_hud(T)
	T.run("register_on_hud_add exists", function()
		T.assert(type(core.register_on_hud_add) == "function",
			"register_on_hud_add should be a function")
	end)

	T.run("clean_hud setting defaults to false", function()
		T.assert(type(core.settings:get("clean_hud")) == "string",
			"clean_hud setting should exist")
	end)
end

function test_formspec_blocker(T)
	T.run("register_on_receiving_formspec exists", function()
		T.assert(type(core.register_on_receiving_formspec) == "function")
	end)
	T.run("formspec_blocker setting exists", function()
		T.assert(type(core.settings:get("formspec_blocker")) == "string")
	end)
end

function test_movement_display(T)
	T.run("movement_display setting exists", function()
		T.assert(type(core.settings:get("movement_display")) == "string")
	end)
end

function test_formspec_modifier(T)
	T.run("register_on_receiving_inventory_form exists", function()
		T.assert(type(core.register_on_receiving_inventory_form) == "function")
	end)
end

function test_session_stats(T)
	T.run("session_stats registers .stats command", function()
		T.assert(type(core.registered_chatcommands["stats"]) == "table",
			".stats command should exist")
		T.assert(type(core.registered_chatcommands["stats"].func) == "function",
			".stats command should have a function")
	end)

	T.run("session_stats callbacks exist", function()
		T.assert(type(core.registered_on_connect) == "table",
			"registered_on_connect should exist")
	end)
end
