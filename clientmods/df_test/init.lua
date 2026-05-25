local modname = assert(core.get_current_modname())
local modpath = core.get_modpath(modname)

-- Test framework
local df_test = {}
local results = { passed = 0, failed = 0, errors = {} }

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

function df_test.assert_near(a, b, epsilon, msg)
	epsilon = epsilon or 0.001
	if math.abs(a - b) > epsilon then
		error(string.format("%s: expected %g, got %g", msg or "assert_near", b, a), 2)
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

function df_test.report()
	core.log("action", "============================================")
	core.log("action", "[DF_TEST] Results: " .. results.passed .. " passed, "
		.. results.failed .. " failed")
	for _, e in ipairs(results.errors) do
		core.log("action", "[DF_TEST]   FAIL " .. e.name .. ": " .. tostring(e.err))
	end
	core.log("action", "============================================")
end

-- Mod channel for server communication
local mod_channel

-- Register handler for incoming mod channel messages
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

-- Wait helper: yields until a condition is met or timeout
function df_test.wait_until(cond_fn, timeout, interval)
	timeout = timeout or 5.0
	interval = interval or 0.1
	local elapsed = 0
	while elapsed < timeout do
		if cond_fn() then
			return true
		end
		core.get_internal_time() -- advance time
		elapsed = elapsed + interval
	end
	return cond_fn()
end

-- Load test modules
dofile(modpath .. "/test_api.lua")
dofile(modpath .. "/test_cheats.lua")
dofile(modpath .. "/test_clientobject.lua")
dofile(modpath .. "/test_inventory.lua")
dofile(modpath .. "/test_callbacks.lua")

-- Run tests when mods are loaded
core.register_on_mods_loaded(function()
	local t0 = core.get_us_time()
	core.log("action", "[DF_TEST] Starting DragonfireClient integration tests")

	-- API registration tests
	test_api_registration(df_test)

	-- Cheat tests
	test_cheat_settings(df_test)

	-- ClientObjectRef tests
	test_clientobject_ref(df_test)

	-- InventoryAction tests
	test_inventory_action(df_test)

	-- Callback registration tests
	test_callback_registration(df_test)

	local elapsed = (core.get_us_time() - t0) / 1000000
	core.log("action", "[DF_TEST] Tests completed in " .. string.format("%.2f", elapsed) .. "s")
	df_test.report()
end)
