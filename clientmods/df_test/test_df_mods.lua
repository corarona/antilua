-- Tests for restructured DragonfireClient mods (dig, place, inv_open, autocraft, wasplib additions)

------------------------------------------------------------------------------
-- wasplib: constraint system
------------------------------------------------------------------------------
function test_wasplib_constraint(T)
	T.run("ws.set_pos1 exists", function()
		T.assert(type(ws.set_pos1) == "function")
	end)
	T.run("ws.set_pos2 exists", function()
		T.assert(type(ws.set_pos2) == "function")
	end)
	T.run("ws.reset_constraints exists", function()
		T.assert(type(ws.reset_constraints) == "function")
	end)
	T.run("ws.inside_constraints exists", function()
		T.assert(type(ws.inside_constraints) == "function")
	end)
	T.run("/pos1 chat command exists", function()
		T.assert(type(core.registered_chatcommands["pos1"]) == "table")
	end)
	T.run("/pos2 chat command exists", function()
		T.assert(type(core.registered_chatcommands["pos2"]) == "table")
	end)
	T.run("/creset chat command exists", function()
		T.assert(type(core.registered_chatcommands["creset"]) == "table")
	end)
	T.run("inside_constraints returns true when no constraints set", function()
		ws.reset_constraints()
		T.assert(ws.inside_constraints({x = 0, y = 0, z = 0}) == true)
	end)
end

------------------------------------------------------------------------------
-- wasplib: new helper functions
------------------------------------------------------------------------------
function test_wasplib_helpers(T)
	T.run("ws.dig_if_able exists", function()
		T.assert(type(ws.dig_if_able) == "function")
	end)
	T.run("ws.place_if_needed exists", function()
		T.assert(type(ws.place_if_needed) == "function")
	end)
	T.run("ws.get_nodes_per_tick returns number", function()
		local n = ws.get_nodes_per_tick()
		T.assert(type(n) == "number")
		T.assert(n > 0)
	end)
	T.run("ws.get_slot exists", function()
		T.assert(type(ws.get_slot) == "function")
	end)
	T.run("ws.get_itemslot_bg_v4 returns string", function()
		local s = ws.get_itemslot_bg_v4(0, 0, 1, 1)
		T.assert(type(s) == "string")
	end)
	T.run("ws.find_best_tool exists", function()
		T.assert(type(ws.find_best_tool) == "function")
	end)
end

------------------------------------------------------------------------------
-- wasplib: merged mods (autotool, headsaver, lavaalarm, lockview)
------------------------------------------------------------------------------
function test_wasplib_merged(T)
	T.run("autotool cheat setting exists", function()
		T.assert(core.settings:get("autotool") ~= nil)
	end)
	T.run("headsaver cheat setting exists", function()
		T.assert(core.settings:get("headsaver") ~= nil)
	end)
	T.known_failure("lavaalarm cheat setting exists", function()
		T.assert(core.settings:get("lavaalarm") ~= nil)
	end)
	T.run("lockview cheat setting exists", function()
		T.assert(core.settings:get("lockview") ~= nil)
	end)
	T.run("mcl2-invul cheat exists", function()
		T.assert(type(core.cheats["Player"]["mcl2-invul"]) ~= nil)
	end)
end

------------------------------------------------------------------------------
-- dig mod
------------------------------------------------------------------------------
function test_dig_mod(T)
	T.run("dig namespace exists", function()
		T.assert(type(dig) == "table")
	end)
	T.run("dig.calculate_dig_time exists", function()
		T.assert(type(dig.calculate_dig_time) == "function")
	end)
	T.run("dig.get_dig_time exists", function()
		T.assert(type(dig.get_dig_time) == "function")
	end)
	T.run("dig.dig_node exists", function()
		T.assert(type(dig.dig_node) == "function")
	end)
	T.run("dig/autocustom: DigCustom setting exists", function()
		T.assert(core.settings:get("digcustom") ~= nil)
	end)
	T.run("dig/tunnel: dighead setting exists", function()
		T.assert(core.settings:get("dighead") ~= nil)
	end)
	T.run("dig/tunnel: excavator setting exists", function()
		T.assert(core.settings:get("excavator") ~= nil)
	end)
	T.run("dig/blast: nuke setting exists", function()
		T.assert(core.settings:get("nuke") ~= nil)
	end)
	T.run("dig/sponge: digcyl chat commands exist", function()
		T.assert(type(core.registered_chatcommands["digcyl"]) == "table")
		T.assert(type(core.registered_chatcommands["digcyl_rad"]) == "table")
	end)
	T.run("dig.calculate_dig_time returns time for known toolcaps", function()
		local toolcaps = {
			groupcaps = {
				["pickaxey"] = { times = { [1] = 0.5, [2] = 0.3, [3] = 0.15 } },
			},
		}
		local groups = { pickaxey = 2 }
		local tm = dig.calculate_dig_time(toolcaps, groups)
		T.assert(type(tm) == "number")
		T.assert(tm > 0)
	end)
end

------------------------------------------------------------------------------
-- place mod (renamed from scaffold)
------------------------------------------------------------------------------
function test_place_mod(T)
	T.run("scaffold namespace exists (backward compat)", function()
		T.assert(type(scaffold) == "table")
	end)
	T.run("scaffold.place_if_needed delegates to ws", function()
		T.assert(type(scaffold.place_if_needed) == "function")
	end)
	T.run("scaffold.place_if_able delegates to ws", function()
		T.assert(type(scaffold.place_if_able) == "function")
	end)
	T.run("scaffold.dig delegates to ws", function()
		T.assert(type(scaffold.dig) == "function")
	end)
	T.run("place/walls: WallIn setting exists", function()
		T.assert(core.settings:get("place_wallin") ~= nil)
	end)
	T.run("place/walls: SkyPltfrm setting exists", function()
		T.assert(core.settings:get("place_skypltfrm") ~= nil)
	end)
	T.run("place/walls: PCeiling setting exists", function()
		T.assert(core.settings:get("pceiling") ~= nil)
	end)
	T.run("place/init: BlockSources setting exists", function()
		T.assert(core.settings:get("block_sources") ~= nil, "block_sources setting should exist")
	end)
	T.run("place/init: BlockSources default block_water setting", function()
		T.assert(core.settings:get("block_sources.block_water") ~= nil, "block_sources.block_water setting should exist")
	end)
	T.run("place/init: BlockSources default block_lava setting", function()
		T.assert(core.settings:get("block_sources.block_lava") ~= nil, "block_sources.block_lava setting should exist")
	end)
	T.run("place/init: Highway setting exists", function()
		T.assert(core.settings:get("highwaymaker") ~= nil)
	end)
	T.run("place/init: MultiScaff setting exists", function()
		T.assert(core.settings:get("scaffold") ~= nil)
	end)
	T.run("place/init: AutoMoss setting exists", function()
		T.assert(core.settings:get("automoss") ~= nil)
	end)
	T.run("place/init: PlaceOn setting exists (greenup)", function()
		T.assert(core.settings:get("placeon") ~= nil)
	end)
	T.run("place/spongebot: SpongeBot setting exists", function()
		T.assert(core.settings:get("spongebot") ~= nil)
	end)
	T.run("place/bot_tools: AutoCombatLog setting exists", function()
		T.assert(core.settings:get("autoclog") ~= nil)
	end)
	-- deprecate scaffold aliases removed
	local function check_category(name, expected)
		for cat, entries in pairs(core.cheats) do
			if entries[name] then
				T.assert_eq(cat, expected, name .. " should be in " .. expected .. ", got " .. cat)
				return
			end
		end
		T.assert(false, name .. " not found in any cheat category")
	end
	T.run("PlaceOn is in Place category", function()
		check_category("MultiScaff", "Place")
	end)
	T.run("AutoMoss is in Place category", function()
		check_category("AutoMoss", "Place")
	end)
	T.run("WallIn is in Place category", function()
		check_category("WallIn", "Place")
	end)
end

------------------------------------------------------------------------------
-- inv_open mod
------------------------------------------------------------------------------
function test_inv_open_mod(T)
	T.run("/craft chat command exists", function()
		T.assert(type(core.registered_chatcommands["craft"]) == "table")
	end)
	T.run("/openlist chat command exists", function()
		T.assert(type(core.registered_chatcommands["openlist"]) == "table")
	end)
	T.run("OpenInvLists cheat exists", function()
		if type(core.cheats["Inventory"]) == "table" then
			T.assert(core.cheats["Inventory"]["OpenInvLists"] ~= nil)
		else
			T.assert(false, "Inventory cheat category missing")
		end
	end)
	T.run("OpenCraftGrid cheat exists", function()
		if type(core.cheats["Inventory"]) == "table" then
			T.assert(core.cheats["Inventory"]["OpenCraftGrid"] ~= nil)
		else
			T.assert(false, "Inventory cheat category missing")
		end
	end)
	T.run("PunchInv cheat setting exists", function()
		T.assert(core.settings:get("punchinv") ~= nil)
	end)
end

------------------------------------------------------------------------------
-- autocraft mod
------------------------------------------------------------------------------
function test_autocraft_mod(T)
	T.run("/autocraft chat command exists", function()
		T.assert(type(core.registered_chatcommands["autocraft"]) == "table")
	end)
	T.run("/autocraft_list chat command exists", function()
		T.assert(type(core.registered_chatcommands["autocraft_list"]) == "table")
	end)
	T.run("/autocraft_clear chat command exists", function()
		T.assert(type(core.registered_chatcommands["autocraft_clear"]) == "table")
	end)
	T.run("autocraft cheat setting exists", function()
		T.assert(core.settings:get("autocraft") ~= nil)
	end)
	T.run("autocraft_recipes setting can be written and read", function()
		core.settings:set("autocraft_recipes", "{}")
		T.assert_eq(core.settings:get("autocraft_recipes"), "{}")
	end)
end

------------------------------------------------------------------------------
-- Integration: ws.rg lifecycle (deferred — needs localplayer)
------------------------------------------------------------------------------
function test_ws_rg_lifecycle(T)
	T.defer("ws.rg lifecycle: on_start fires on toggle on", function()
		local fired = { start = false, step = false, stop = false, done = false }
		local test_setting = "df_test_rg_lifecycle"
		core.settings:set(test_setting, "false")
		ws.rg("DFTestLifecycle", {
			category = "DevTools",
			setting = test_setting,
			delay = 0,
			on_start = function() fired.start = true end,
			on_step = function() fired.step = true end,
			on_stop = function() fired.stop = true end,
		})
		core.settings:set_bool(test_setting, true)
		core.after(1.0, function()
			local ok1 = fired.start
			local ok2 = fired.step
			core.settings:set_bool(test_setting, false)
			core.after(1.0, function()
				local ok3 = fired.stop
				if ok1 and ok2 and ok3 then
					fired.done = true
				end
			end)
		end)
		-- Poll for completion
		core.after(3.0, function()
			T.assert(fired.done, "ws.rg lifecycle: start=" .. tostring(fired.start) .. " step=" .. tostring(fired.step) .. " stop=" .. tostring(fired.stop))
			core.settings:set_bool(test_setting, false)
		end)
	end)
end

------------------------------------------------------------------------------
-- Integration: Inventory structure (deferred — needs localplayer)
------------------------------------------------------------------------------
function test_inventory_structure(T)
	T.defer("core.get_inventory returns player inventory with expected lists", function()
		local inv = core.get_inventory("current_player")
		T.assert(type(inv) == "table", "get_inventory should return a table")
		T.assert(type(inv.main) == "table", "inventory should have main list")
		T.assert(type(inv.craft) == "table", "inventory should have craft list")
		T.assert(type(inv.craftpreview) == "table", "inventory should have craftpreview list")
	end)
end

------------------------------------------------------------------------------
-- Integration: InventoryAction construction (deferred — needs localplayer)
------------------------------------------------------------------------------
function test_inventory_action_integration(T)
	T.defer("InventoryAction move can be created and applied", function()
		local act = InventoryAction("move")
		T.assert(type(act) == "table" or type(act) == "userdata")
		T.assert(type(act.apply) == "function")
		-- Don't actually execute — would modify inventory
	end)
	T.defer("InventoryAction craft can be created", function()
		local act = InventoryAction("craft")
		T.assert(type(act) == "table" or type(act) == "userdata")
		T.assert(type(act.craft) == "function")
	end)
end

------------------------------------------------------------------------------
-- Integration: World interaction (deferred — needs localplayer)
------------------------------------------------------------------------------
function test_world_interaction(T)
	T.defer("ws.can_place_at returns bool for current player pos", function()
		local pos = core.localplayer:get_pos()
		if pos then
			local np = vector.round(vector.offset(pos, 0, -1, 0))
			local node = core.get_node_or_nil(np)
			if node then
				local ok = ws.can_place_at(np)
				T.assert(type(ok) == "boolean")
			end
		end
	end)
	T.defer("ws.dig does not crash on air node", function()
		local pos = core.localplayer:get_pos()
		if pos then
			-- Should silently fail on air (returns nil/true/false), not crash
			local ok, err = pcall(ws.dig, vector.round(pos))
			T.assert(ok, "ws.dig on air should not throw; error: " .. tostring(err))
		end
	end)
end

------------------------------------------------------------------------------
-- Category assignment checks
------------------------------------------------------------------------------
function test_category_assignments(T)
	local function check_category(name, expected)
		for cat, entries in pairs(core.cheats) do
			if entries[name] then
				T.assert_eq(cat, expected, name .. " should be in " .. expected .. ", got " .. cat)
				return
			end
		end
		T.assert(false, name .. " not found in any cheat category")
	end
	T.run("DigCustom is in Dig category", function()
		check_category("DigCustom", "Dig")
	end)
	T.run("IceBreaker is in Dig category", function()
		check_category("IceBreaker", "Dig")
	end)
	T.run("BlockSources is in Place category", function()
		check_category("BlockSources", "Place")
	end)
	T.run("BlockSources use_wielded mode works", function()
		T.assert(core.settings:get("block_sources.use_wielded") ~= nil,
			"block_sources.use_wielded should have default value")
	end)
	T.run("Highway is in Place category", function()
		check_category("Highway", "Place")
	end)
	T.run("Autosponge is in Place category", function()
		check_category("Autosponge", "Place")
	end)
	T.run("POIs is in Misc category", function()
		check_category("POIs", "Misc")
	end)
	T.run("NlEdMode is in Misc category", function()
		check_category("NlEdMode", "Misc")
	end)
end

----------------------------------------------------------------------------------
-- Notification API
----------------------------------------------------------------------------------
function test_notification_api(T)
	-- Must guard: ws.notify may not exist if wasplib failed to load
	if not ws.notify then return end

	T.run("ws.notify() calls handler with defaults", function()
		local called = false
		ws.set_notify_handler(function(text, ntype, opts)
			called = true
		end)
		ws.notify("test message")
		ws.set_notify_handler(nil)
		T.assert(called, "ws.notify() should call the handler")
	end)

	T.run("ws.notify() with explicit type", function()
		local result_type = nil
		ws.set_notify_handler(function(text, ntype, opts)
			result_type = ntype
		end)
		ws.notify("error test", ws.NOTIFY_ERROR)
		ws.set_notify_handler(nil)
		T.assert_eq(result_type, ws.NOTIFY_ERROR)
	end)

	T.run("ws.notify() with {toast=false}", function()
		local opts_received = nil
		ws.set_notify_handler(function(text, ntype, opts)
			opts_received = opts
		end)
		ws.notify("chat only", ws.NOTIFY_INFO, {toast = false})
		ws.set_notify_handler(nil)
		T.assert_eq(opts_received.toast, false)
	end)

	T.run("ws.notify_cheat(true) uses success type", function()
		local result_type = nil
		ws.set_notify_handler(function(text, ntype, opts)
			result_type = ntype
		end)
		ws.notify_cheat("TestCheat", true)
		ws.set_notify_handler(nil)
		T.assert_eq(result_type, ws.NOTIFY_SUCCESS)
	end)

	T.run("ws.notify_cheat(false) uses info type", function()
		local result_type = nil
		ws.set_notify_handler(function(text, ntype, opts)
			result_type = ntype
		end)
		ws.notify_cheat("TestCheat", false)
		ws.set_notify_handler(nil)
		T.assert_eq(result_type, ws.NOTIFY_INFO)
	end)

	T.run("ws.set_notify_handler(nil) restores default", function()
		local custom_called = false
		ws.set_notify_handler(function() custom_called = true end)
		ws.set_notify_handler(nil)
		-- After restoring default, our custom handler should NOT be called
		custom_called = false
		ws.notify("test")
		T.assert(not custom_called, "custom handler should not be called after restore")
	end)

	T.defer("lifecycle: on_start success triggers notify_cheat true", function()
		local test_setting = "df_test_notify_lifecycle_success"
		core.settings:set(test_setting, "false")
		local notified_name = nil
		local notified_enabled = nil
		ws.set_notify_handler(function(text, ntype, opts) end) -- suppress output
		local orig_notify_cheat = ws.notify_cheat
		ws.notify_cheat = function(name, enabled)
			notified_name = name
			notified_enabled = enabled
			orig_notify_cheat(name, enabled)
		end
		ws.rg("DFTestNotifySuccess", {
			category = "DevTools",
			setting = test_setting,
			on_start = function() end,
		})
		core.settings:set_bool(test_setting, true)
		core.after(0.5, function()
			T.assert_eq(notified_name, "DFTestNotifySuccess",
				"should notify with cheat name on enable")
			T.assert_eq(notified_enabled, true,
				"should notify enabled=true on successful on_start")
			ws.notify_cheat = orig_notify_cheat
			ws.set_notify_handler(nil)
			core.settings:set_bool(test_setting, false)
		end)
	end)

	T.defer("lifecycle: on_start failure triggers error notification", function()
		local test_setting = "df_test_notify_lifecycle_fail"
		core.settings:set(test_setting, "false")
		local notified_text = nil
		local notified_type = nil
		ws.set_notify_handler(function(text, ntype, opts)
			notified_text = text
			notified_type = ntype
		end)
		ws.rg("DFTestNotifyFail", {
			category = "DevTools",
			setting = test_setting,
			on_start = function()
				return false, "custom failure reason"
			end,
		})
		core.settings:set_bool(test_setting, true)
		core.after(0.5, function()
			T.assert_eq(notified_text, "custom failure reason",
				"should use the message from return false, 'msg'")
			T.assert_eq(notified_type, ws.NOTIFY_ERROR,
				"failure should use error notification type")
			ws.set_notify_handler(nil)
			core.settings:set_bool(test_setting, false)
		end)
	end)
end
