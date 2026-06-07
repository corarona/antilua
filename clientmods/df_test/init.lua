local modname = assert(core.get_current_modname())
local modpath = core.get_modpath(modname)

-- Test framework
local df_test = {}
local results = { passed = 0, failed = 0, skipped = 0, errors = {} }

function df_test.assert(cond, msg)
	if not cond then
		error(msg or "assertion failed", 2)
	end
end

function df_test.assert_eq(a, b, msg)
	if a ~= b then
		error(string.format("%s: expected %s, got %s", msg or "assert_eq", dump(b), dump(a)), 2)
	end
end

function df_test.run(name, fn)
	local ok, err = pcall(fn, df_test)
	if ok then
		results.passed = results.passed + 1
		core.log("info", "[DF_TEST] PASS: " .. name)
	else
		results.failed = results.failed + 1
		table.insert(results.errors, { name = name, err = err })
		core.log("warning", "[DF_TEST] FAIL: " .. name .. " — " .. tostring(err))
	end
end

-- Mark a test as known failure (unported DF feature)
function df_test.known_failure(name, fn)
	local ok, err = pcall(fn, df_test)
	if ok then
		results.passed = results.passed + 1
		core.log("info", "[DF_TEST] PASS (unexpected): " .. name)
	else
		results.skipped = results.skipped + 1
		core.log("info", "[DF_TEST] SKIP (not ported): " .. name .. " — " .. tostring(err))
	end
end

function df_test.report()
	core.log("action", "============================================")
	core.log("action", "[DF_TEST] Results: " .. results.passed .. " passed, "
		.. results.failed .. " failed, " .. results.skipped .. " skipped (not ported)")
	for _, e in ipairs(results.errors) do
		core.log("action", "[DF_TEST]   FAIL " .. e.name .. ": " .. tostring(e.err))
	end
	core.log("action", "============================================")
end

-- Mod channel for server communication
local mod_channel

core.register_on_modchannel_message(function(channel_name, sender, message)
	if channel_name ~= "df_test" then
		return
	end
	core.log("info", "[DF_TEST] Mod channel received from " .. sender .. ": " .. message)
end)

do
	local ok = pcall(function()
		mod_channel = core.mod_channel_join("df_test")
	end)
	if not ok then
		core.log("warning", "[DF_TEST] Could not join mod channel 'df_test'")
	end
end

function df_test.send_to_server(msg)
	if mod_channel and mod_channel:is_writeable() then
		mod_channel:send_all(msg)
	end
end

-- Deferred tests (run after localplayer is available)
local deferred_tests = {}

function df_test.defer(name, fn)
	table.insert(deferred_tests, { name = name, fn = fn })
end

-- Load test modules
dofile(modpath .. "/test_api.lua")
dofile(modpath .. "/test_cheats.lua")
dofile(modpath .. "/test_clientobject.lua")
dofile(modpath .. "/test_inventory.lua")
dofile(modpath .. "/test_callbacks.lua")
dofile(modpath .. "/test_dragonfire_mods.lua")
dofile(modpath .. "/test_df_mods.lua")

-- Run API/registration tests at mod load time
core.register_on_mods_loaded(function()
	local t0 = core.get_us_time()
	core.log("action", "[DF_TEST] Starting DragonfireClient integration tests")

	test_cheat_settings(df_test)
	test_callback_registration(df_test)
	test_api_registration_no_player(df_test)
	test_inventory_action_no_player(df_test)
	test_clientobject_ref(df_test)
	test_inventory_action(df_test)

	test_dragonfire_wasplib(df_test)
	test_dragonfire_lockview(df_test)
	test_dragonfire_headsaver(df_test)
	test_dragonfire_invsaver(df_test)
	test_dragonfire_antitower(df_test)
	test_dragonfire_walls(df_test)
	test_dragonfire_autoevade(df_test)
	test_dragonfire_extracted_features(df_test)
	test_ws_rg_new_api(df_test)

	test_wasplib_constraint(df_test)
	test_wasplib_helpers(df_test)
	test_wasplib_merged(df_test)
	test_dig_mod(df_test)
	test_place_mod(df_test)
	test_inv_open_mod(df_test)
	test_autocraft_mod(df_test)
	test_session_stats(df_test)
	test_always_day(df_test)
	test_clean_hud(df_test)
	test_formspec_blocker(df_test)
	test_entity_logger(df_test)
	test_world_observer(df_test)
	test_movement_display(df_test)
	test_breath_alert(df_test)
	test_formspec_modifier(df_test)
	test_category_assignments(df_test)

	-- Integration tests (deferred — register but don't run yet)
	test_ws_rg_lifecycle(df_test)
	test_inventory_structure(df_test)
	test_inventory_action_integration(df_test)
	test_world_interaction(df_test)

	-- Defer localplayer-dependent tests (poll until localplayer is ready)
	if #deferred_tests > 0 then
		core.log("action", "[DF_TEST] " .. #deferred_tests .. " tests deferred until localplayer is ready")

		local function check_and_run()
			if core.localplayer then
				for _, t in ipairs(deferred_tests) do
					df_test.run(t.name, t.fn)
				end
				core.log("action", "[DF_TEST] Deferred tests complete")
				df_test.report()
			else
				core.after(0.5, check_and_run)
			end
		end
		core.after(1, check_and_run)
	end

	local elapsed = (core.get_us_time() - t0) / 1000000
	core.log("action", "[DF_TEST] Immediate tests completed in " .. string.format("%.2f", elapsed) .. "s")
	df_test.report()
end)
