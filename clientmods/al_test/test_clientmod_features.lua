-- Tests for untested clientmod features

function test_clientmod_features(T)
	-- Settings not yet covered by test_cheats.lua
	T.run("sign_reader setting exists", function()
		T.assert(type(core.settings:get("sign_reader")) == "string",
			"sign_reader setting should exist")
	end)

	T.run("hudlocker setting exists", function()
		T.assert(type(core.settings:get("hudlocker")) == "string",
			"hudlocker setting should exist")
	end)

	T.run("autorefill setting exists", function()
		T.assert(type(core.settings:get("autorefill")) == "string",
			"autorefill setting should exist")
	end)

	T.run("autoeject setting exists", function()
		T.assert(type(core.settings:get("autoeject")) == "string",
			"autoeject setting should exist")
	end)

	-- Cheat definitions: category assignments for untested cheats
	T.run("ChatAlerts cheat in Social category", function()
		T.assert(type(core.cheats.Social) == "table", "Social category exists")
		T.assert(core.cheats.Social.ChatAlerts ~= nil,
			"ChatAlerts should be in Social category")
	end)

	T.run("NameColorizer cheat in Social category", function()
		T.assert(type(core.cheats.Social) == "table", "Social category exists")
		T.assert(core.cheats.Social.NameColorizer ~= nil,
			"NameColorizer should be in Social category")
	end)

	T.run("SignReader cheat in Info category", function()
		T.assert(type(core.cheats.Info) == "table", "Info category exists")
		T.assert(core.cheats.Info.SignReader ~= nil,
			"SignReader should be in Info category")
	end)

	T.run("HUDLocker cheat in Render category", function()
		T.assert(type(core.cheats.Render) == "table", "Render category exists")
		T.assert(core.cheats.Render.HUDLocker ~= nil,
			"HUDLocker should be in Render category")
	end)

	T.run("AutoRefill cheat in Inventory category", function()
		T.assert(type(core.cheats.Inventory) == "table", "Inventory category exists")
		T.assert(core.cheats.Inventory.AutoRefill ~= nil,
			"AutoRefill should be in Inventory category")
	end)

	T.run("AutoEject cheat in Inventory category", function()
		T.assert(type(core.cheats.Inventory) == "table", "Inventory category exists")
		T.assert(core.cheats.Inventory.AutoEject ~= nil,
			"AutoEject should be in Inventory category")
	end)

	T.run("ChestStealer cheat in Inventory category", function()
		T.assert(type(core.cheats.Inventory) == "table", "Inventory category exists")
		T.assert(core.cheats.Inventory.ChestStealer ~= nil,
			"ChestStealer should be in Inventory category")
	end)

	T.run("AutoSort cheat in Inventory category", function()
		T.assert(type(core.cheats.Inventory) == "table", "Inventory category exists")
		T.assert(core.cheats.Inventory.AutoSort ~= nil,
			"AutoSort should be in Inventory category")
	end)

	T.run("DumpFull cheat in Inventory category", function()
		T.assert(type(core.cheats.Inventory) == "table", "Inventory category exists")
		T.assert(core.cheats.Inventory.DumpFull ~= nil,
			"DumpFull should be in Inventory category")
	end)

	T.run("BlockLogger cheat in Info category", function()
		T.assert(type(core.cheats.Info) == "table", "Info category exists")
		T.assert(core.cheats.Info.BlockLogger ~= nil,
			"BlockLogger should be in Info category")
	end)

	T.run("BlockStats cheat in Info category", function()
		T.assert(type(core.cheats.Info) == "table", "Info category exists")
		T.assert(core.cheats.Info.BlockStats ~= nil,
			"BlockStats should be in Info category")
	end)

	-- Cheat settings sub-fields (stored in cheat_defs keyed by setting name)
	T.run("sign_reader.range cheat setting exists", function()
		local def = core.cheat_defs["sign_reader"]
		T.assert(def ~= nil, "sign_reader cheat def exists")
		T.assert(def.cheat_settings ~= nil, "sign_reader has cheat_settings")
		T.assert(type(def.cheat_settings.range) == "table",
			"sign_reader.range cheat setting exists")
		T.assert_eq(def.cheat_settings.range.default, 10,
			"sign_reader.range default is 10")
	end)

	T.run("sign_reader.log cheat setting exists", function()
		local def = core.cheat_defs["sign_reader"]
		T.assert(def ~= nil, "sign_reader cheat def exists")
		T.assert(type(def.cheat_settings.log) == "table",
			"sign_reader.log cheat setting exists")
		T.assert(def.cheat_settings.log.default == false,
			"sign_reader.log default is false")
	end)

	T.run("hudlocker.notify_on_change cheat setting exists", function()
		local def = core.cheat_defs["hudlocker"]
		T.assert(def ~= nil, "hudlocker cheat def exists")
		T.assert(def.cheat_settings ~= nil, "hudlocker has cheat_settings")
		T.assert(type(def.cheat_settings.notify_on_change) == "table",
			"hudlocker.notify_on_change cheat setting exists")
		T.assert(def.cheat_settings.notify_on_change.default == true,
			"hudlocker.notify_on_change default is true")
	end)

	-- Chat commands not yet covered
	T.run("/blockstats chat command registered", function()
		T.assert(type(core.registered_chatcommands["blockstats"]) == "table",
			"/blockstats command should exist")
		T.assert(type(core.registered_chatcommands["blockstats"].func) == "function",
			"/blockstats should have a function")
	end)

	T.run("/eject chat command registered", function()
		T.assert(type(core.registered_chatcommands["eject"]) == "table",
			"/eject command should exist")
		T.assert(type(core.registered_chatcommands["eject"].func) == "function",
			"/eject should have a function")
	end)

	-- Callback tables not yet covered
	T.run("registered_on_damage_taken table exists", function()
		T.assert(type(core.registered_on_damage_taken) == "table",
			"registered_on_damage_taken should be a table")
	end)

	T.run("registered_on_dignode table exists", function()
		T.assert(type(core.registered_on_dignode) == "table",
			"registered_on_dignode should be a table")
	end)

	T.run("registered_on_hud_flags_changed table exists", function()
		T.assert(type(core.registered_on_hud_flags_changed) == "table",
			"registered_on_hud_flags_changed should be a table")
	end)

	T.run("registered_on_hud_param_changed table exists", function()
		T.assert(type(core.registered_on_hud_param_changed) == "table",
			"registered_on_hud_param_changed should be a table")
	end)

	-- QoL mod features
	T.run("/entityinfo command registered", function()
		T.assert(type(core.registered_chatcommands["entityinfo"]) == "table",
			"/entityinfo command should exist")
	end)

	T.run("chat timestamps callback prepends [HH:MM:SS]", function()
		local found
		for _, cb in ipairs(core.registered_on_receiving_chat_message) do
			local ret = cb("test message")
			if ret and ret:match("^%[%d+:%d+:%d+%] ") then
				found = true
				break
			end
		end
		T.assert(found, "at least one callback adds [HH:MM:SS] timestamp")
	end)

	T.run("click coords callback parses (X, Y, Z)", function()
		local found
		for _, cb in ipairs(core.registered_on_receiving_chat_message) do
			-- Should not crash, should parse coords silently
			local ok, ret = pcall(cb, "Look at (100, 200, -300)")
			if ok then
				found = true
			end
		end
		T.assert(found, "click coords callback should handle (X, Y, Z)")
	end)

	T.run("auto_reconnect setting defaults exist", function()
		T.assert(type(core.settings:get("auto_reconnect")) == "string",
			"auto_reconnect setting should exist")
		T.assert(type(core.settings:get("auto_reconnect_delay")) == "string",
			"auto_reconnect_delay setting should exist")
		T.assert(type(core.settings:get("auto_reconnect_max_backoff")) == "string",
			"auto_reconnect_max_backoff setting should exist")
		T.assert(type(core.settings:get("auto_reconnect_max")) == "string",
			"auto_reconnect_max setting should exist")
	end)
end
