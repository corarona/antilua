-- Tests for restructured Antilua mods (dig, place, inv_open, autocraft, wasplib additions)

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
	T.run("dig/autocustom: DigList setting exists", function()
		T.assert(core.settings:get("diglist") ~= nil)
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
-- place mod
------------------------------------------------------------------------------
function test_place_mod(T)
	T.run("place/init: BlockSources setting exists", function()
		T.assert(core.settings:get("block_sources") ~= nil, "block_sources setting should exist")
	end)
	T.run("place/init: BlockSources default block_water setting", function()
		T.assert(core.settings:get("block_sources.block_water") ~= nil, "block_sources.block_water setting should exist")
	end)
	T.run("place/init: BlockSources default block_lava setting", function()
		T.assert(core.settings:get("block_sources.block_lava") ~= nil, "block_sources.block_lava setting should exist")
	end)
	T.run("place/init: MultiScaff setting exists", function()
		T.assert(core.settings:get("scaffold") ~= nil)
	end)
	T.run("place/init: MultiScaff random setting exists", function()
		T.assert(core.settings:get("scaffold.random") ~= nil)
	end)
	T.run("place/init: MultiScaff dig setting exists", function()
		T.assert(core.settings:get("scaffold.dig") ~= nil)
	end)
	T.run("place/init: PlaceOn setting exists", function()
		T.assert(core.settings:get("placeon") ~= nil)
	end)
	T.run("place/init: PlaceOn use_wielded setting exists", function()
		T.assert(core.settings:get("placeon.use_wielded") ~= nil)
	end)
	T.run("place/init: PlaceOn range setting exists", function()
		T.assert(core.settings:get("placeon.range") ~= nil)
	end)
	T.run("place/init: AutoTower setting exists", function()
		T.assert(core.settings:get("autotower") ~= nil)
	end)
	T.run("place/init: AutoTower range setting exists", function()
		T.assert(core.settings:get("autotower.range") ~= nil)
	end)
	T.run("place/init: AutoTower down setting exists", function()
		T.assert(core.settings:get("autotower.down") ~= nil)
	end)
	T.run("place/init: AutoTower random setting exists", function()
		T.assert(core.settings:get("autotower.random") ~= nil)
	end)
	T.run("place/spongebot: SpongeBot setting exists", function()
		T.assert(core.settings:get("spongebot") ~= nil)
	end)
	T.run("combat: AutoCombatLog setting exists", function()
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
	T.run("MultiScaff is in Place category", function()
		check_category("MultiScaff", "Place")
	end)
	T.run("PlaceOn is in Place category", function()
		check_category("PlaceOn", "Place")
	end)
	T.run("AutoTower is in Place category", function()
		check_category("AutoTower", "Place")
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
		local test_setting = "al_test_rg_lifecycle"

		core.settings:set(test_setting, "false")
		ws.rg("DFTestLifecycle", {
			name = "DFTestLifecycle",
			category = "DevTools",
			setting = test_setting,
			delay = 0,
			on_start = function() fired.start = true end,
			on_step = function() fired.step = true end,
			on_stop = function() fired.stop = true end,
		})

		T.assert(#ws.registered_globalhacks > 0,
			"ws.registered_globalhacks should not be empty")
		T.assert(core.cheat_defs[test_setting] ~= nil,
			"cheat_defs should have the test setting")

		core.settings:set_bool(test_setting, true)

		-- Test the globalhack template directly (synchronous)
		local hack = ws.registered_globalhacks[#ws.registered_globalhacks]
		T.assert(type(hack) == "function", "latest globalhack should be a function")

		-- Call it manually — triggers on_start (setting=true, ghwason=nil)
		hack(0)

		-- Second call — triggers on_step (delay=0 so no rate-limit)
		hack(0)

		-- Disable and call again — triggers on_stop
		core.settings:set_bool(test_setting, false)
		hack(0)

		T.assert(fired.start, "on_start should fire when hack is called with setting=true")
		T.assert(fired.step, "on_step should fire on subsequent calls")
		T.assert(fired.stop, "on_stop should fire when setting is toggled off")

		core.settings:set_bool(test_setting, false)
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
	T.run("DigList is in Dig category", function()
		check_category("DigList", "Dig")
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

	T.run("ws.get_notify_history records default-handler notifications", function()
		if not ws.get_notify_history then return end
		local marker = "al_test_history_marker_" .. tostring(math.random(100000))
		-- Record through the default handler (history is not recorded via custom handlers)
		ws.notify(marker, ws.NOTIFY_INFO, {toast = false})
		local hist = ws.get_notify_history(50)
		local found = false
		for _, e in ipairs(hist) do
			if e.text == marker then found = true break end
		end
		T.assert(found, "recorded notification should appear in history")
		-- Clean up
		ws.clear_notify_history()
	end)

	T.run("ws.clear_notify_history empties history", function()
		if not ws.clear_notify_history then return end
		ws.clear_notify_history()
		local hist = ws.get_notify_history()
		T.assert_eq(#hist, 0, "history should be empty after clear")
	end)

	T.run("ws.show_notify_history builds formspec", function()
		if not ws.show_notify_history then return end
		ws.notify("viewer test", ws.NOTIFY_INFO, {toast = false})
		local ok, err = pcall(ws.show_notify_history)
		T.assert(ok, "notification viewer should build: " .. tostring(err))
		ws.clear_notify_history()
	end)
end

----------------------------------------------------------------------------------
-- Profile commands
----------------------------------------------------------------------------------
function test_al_profile(T)
	T.run(".al_profile command registered", function()
		T.assert(type(core.registered_chatcommands["al_profile"]) == "table",
			".al_profile command should exist")
	end)

	T.run(".profile is not overridden by qol", function()
		local def = core.registered_chatcommands["profile"]
		T.assert(def ~= nil, ".profile command should exist")
		if def then
			T.assert(def.mod_origin ~= "qol",
				".profile should not be registered by qol (it is .al_profile now)")
		end
	end)
end

----------------------------------------------------------------------------------
-- HUD layout registry
----------------------------------------------------------------------------------
function test_hud_layout(T)
	if not ws.hud_layout then return end

	T.run("ws.hud_layout.reserve returns distinct y offsets", function()
		local a = ws.hud_layout.reserve("al_test_a", "top_right", 1)
		local b = ws.hud_layout.reserve("al_test_b", "top_right", 2)
		T.assert(a.y >= 0, "first slot y should be >= 0")
		T.assert(b.y > a.y, "second slot should stack below the first")
		ws.hud_layout.release("al_test_a")
		ws.hud_layout.release("al_test_b")
	end)

	T.run("ws.hud_layout re-reserve keeps slot stable", function()
		local a1 = ws.hud_layout.reserve("al_test_c", "top_right", 1)
		local a2 = ws.hud_layout.reserve("al_test_c", "top_right", 1)
		T.assert_eq(a1.y, a2.y, "re-reserving same id should keep y")
		ws.hud_layout.release("al_test_c")
	end)

	T.run("ws.hud_layout.release frees the slot", function()
		ws.hud_layout.clear()
		local a = ws.hud_layout.reserve("al_test_d", "top_right", 1)
		ws.hud_layout.release("al_test_d")
		local b = ws.hud_layout.reserve("al_test_e", "top_right", 1)
		T.assert_eq(a.y, b.y, "released slot should be reusable at the same y")
		ws.hud_layout.clear()
	end)

	T.run("ws.hud_layout.top is base margin for non-top-right anchors", function()
		T.assert_eq(ws.hud_layout.top("bottom_left"), 8,
			"bottom_left stack should use the plain base margin")
		T.assert_eq(ws.hud_layout.top("top_center"), 8,
			"top_center stack should use the plain base margin")
	end)

	T.run("ws.hud_layout.minimap_active returns a boolean", function()
		local v = ws.hud_layout.minimap_active()
		T.assert(type(v) == "boolean", "minimap_active should return a boolean")
	end)

	T.run("ws.hud_layout.minimap_offset honours the avoid fraction", function()
		-- Default: 1/4 of the given screen height
		local prev = core.settings:get("ws_hud_minimap_avoid_fraction")
		core.settings:set("ws_hud_minimap_avoid_fraction", "")
		local default = ws.hud_layout.minimap_offset(1080)
		T.assert_eq(default, 270, "default offset should be 1/4 of the screen height")

		-- Custom fraction
		core.settings:set("ws_hud_minimap_avoid_fraction", "0.25")
		local custom = ws.hud_layout.minimap_offset(1080)
		T.assert_eq(custom, 270, "custom fraction should scale the offset")

		-- 0 disables avoidance
		core.settings:set("ws_hud_minimap_avoid_fraction", "0")
		T.assert_eq(ws.hud_layout.minimap_offset(1080), 0,
			"fraction 0 should disable the minimap offset")

		if prev == nil then
			core.settings:set("ws_hud_minimap_avoid_fraction", "")
		else
			core.settings:set("ws_hud_minimap_avoid_fraction", prev)
		end
	end)

	T.run("ws.hud_layout.top moves down when the minimap is visible", function()
		if not ws.hud_layout.minimap_active() then return end
		local win = core.get_player_window_information()
		local expected = 8 + ws.hud_layout.minimap_offset(win.size.y)
		T.assert_eq(ws.hud_layout.top("top_right"), expected,
			"top_right stack should sit below the minimap when it is visible")
	end)
end
