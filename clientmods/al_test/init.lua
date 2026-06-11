local modname = assert(core.get_current_modname())
local modpath = core.get_modpath(modname)

-- Test framework
local al_test = {}
local results = { passed = 0, failed = 0, skipped = 0, errors = {} }

function al_test.assert(cond, msg)
	if not cond then
		error(msg or "assertion failed", 2)
	end
end

function al_test.assert_eq(a, b, msg)
	if a ~= b then
		error(string.format("%s: expected %s, got %s", msg or "assert_eq", dump(b), dump(a)), 2)
	end
end

function al_test.run(name, fn)
	local ok, err = pcall(fn, al_test)
	if ok then
		results.passed = results.passed + 1
		core.log("info", "[AL_TEST] PASS: " .. name)
	else
		results.failed = results.failed + 1
		table.insert(results.errors, { name = name, err = err })
		core.log("warning", "[AL_TEST] FAIL: " .. name .. " — " .. tostring(err))
	end
end

-- Mark a test as known failure (unported DF feature)
function al_test.known_failure(name, fn)
	local ok, err = pcall(fn, al_test)
	if ok then
		results.passed = results.passed + 1
		core.log("info", "[AL_TEST] PASS (unexpected): " .. name)
	else
		results.skipped = results.skipped + 1
		core.log("info", "[AL_TEST] SKIP (not ported): " .. name .. " — " .. tostring(err))
	end
end

function al_test.report()
	core.log("action", "============================================")
	core.log("action", "[AL_TEST] Results: " .. results.passed .. " passed, "
		.. results.failed .. " failed, " .. results.skipped .. " skipped (not ported)")
	for _, e in ipairs(results.errors) do
		core.log("action", "[AL_TEST]   FAIL " .. e.name .. ": " .. tostring(e.err))
	end
	core.log("action", "============================================")
end

-- Mod channel for server communication
local mod_channel

core.register_on_modchannel_message(function(channel_name, sender, message)
	if channel_name ~= "al_test" then
		return
	end
	core.log("info", "[AL_TEST] Mod channel received from " .. sender .. ": " .. message)
end)

do
	local ok = pcall(function()
		mod_channel = core.mod_channel_join("al_test")
	end)
	if not ok then
		core.log("warning", "[AL_TEST] Could not join mod channel 'al_test'")
	end
end

function al_test.send_to_server(msg)
	if mod_channel and mod_channel:is_writeable() then
		mod_channel:send_all(msg)
	end
end

-- Deferred tests (run after localplayer is available)
local deferred_tests = {}

function al_test.defer(name, fn)
	table.insert(deferred_tests, { name = name, fn = fn })
end

-- Load test modules
dofile(modpath .. "/test_api.lua")
dofile(modpath .. "/test_cheats.lua")
dofile(modpath .. "/test_clientobject.lua")
dofile(modpath .. "/test_inventory.lua")
dofile(modpath .. "/test_callbacks.lua")
dofile(modpath .. "/test_antilua_mods.lua")
dofile(modpath .. "/test_mods.lua")
dofile(modpath .. "/test_raw_packet.lua")
dofile(modpath .. "/test_autominer.lua")
dofile(modpath .. "/test_fishbot.lua")
dofile(modpath .. "/test_killaura.lua")
dofile(modpath .. "/test_witherbot.lua")
dofile(modpath .. "/test_schembuilder.lua")

-- Run API/registration tests at mod load time
core.register_on_mods_loaded(function()
	local t0 = core.get_us_time()
	core.log("action", "[AL_TEST] Starting Antilua integration tests")

	test_cheat_settings(al_test)
	test_callback_registration(al_test)
	test_api_registration_no_player(al_test)
	test_inventory_action_no_player(al_test)
	test_clientobject_ref(al_test)
	test_inventory_action(al_test)

	test_antilua_wasplib(al_test)
	test_antilua_lockview(al_test)
	test_antilua_headsaver(al_test)
	test_antilua_invsaver(al_test)
	test_antilua_walls(al_test)
	test_antilua_autoevade(al_test)
	test_antilua_extracted_features(al_test)
	test_ws_rg_new_api(al_test)

	test_wasplib_constraint(al_test)
	test_wasplib_helpers(al_test)
	test_wasplib_merged(al_test)
	test_dig_mod(al_test)
	test_place_mod(al_test)
	test_inv_open_mod(al_test)
	test_autocraft_mod(al_test)
	test_session_stats(al_test)
	test_always_day(al_test)
	test_clean_hud(al_test)
	test_formspec_blocker(al_test)
	test_entity_logger(al_test)
	test_world_observer(al_test)
	test_movement_display(al_test)
	test_breath_alert(al_test)
	test_formspec_modifier(al_test)
	test_category_assignments(al_test)
	test_raw_packet_api(al_test)
	test_autominer(al_test)
	test_fishbot(al_test)
	test_killaura(al_test)
	test_witherbot(al_test)
	test_schembuilder(al_test)

	-- Integration tests (deferred — register but don't run yet)
	test_ws_rg_lifecycle(al_test)
	test_inventory_structure(al_test)
	test_inventory_action_integration(al_test)
	test_world_interaction(al_test)

	-- Defer localplayer-dependent tests (poll until localplayer + its CAO are ready)
	if #deferred_tests > 0 then
		core.log("action", "[AL_TEST] " .. #deferred_tests .. " tests deferred until localplayer is ready")

		local max_polls = 60 -- 60 * 0.5s = 30s timeout
		local function check_and_run()
			if core.localplayer and core.localplayer:get_object() then
				for _, t in ipairs(deferred_tests) do
					al_test.run(t.name, t.fn)
				end
				core.log("action", "[AL_TEST] Deferred tests complete")
				al_test.report()
			elseif max_polls > 0 then
				max_polls = max_polls - 1
				core.after(0.5, check_and_run)
			else
				core.log("warning", "[AL_TEST] Deferred tests timed out waiting for localplayer/CAO")
				al_test.report()
			end
		end
		core.after(1, check_and_run)
	end

	local elapsed = (core.get_us_time() - t0) / 1000000
	core.log("action", "[AL_TEST] Immediate tests completed in " .. string.format("%.2f", elapsed) .. "s")
	al_test.report()
end)
