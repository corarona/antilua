-- Tests for the Quick Access Palette (~) Lua API

local qm_hits = 0
local qm_repeat_hits = 0

local function quick_menu_index_of(label)
	local entries = core.get_quick_menu_entries()
	for i, e in ipairs(entries) do
		if e.label == label then
			return i
		end
	end
	return nil
end

function test_quick_menu(T)
	T.run("quick menu registration tables exist", function()
		T.assert(type(core.quick_menu_providers) == "table",
			"core.quick_menu_providers should be a table")
		T.assert(type(core.quick_menu_actions) == "table",
			"core.quick_menu_actions should be a table")
	end)

	T.run("register_quick_menu_provider validates type", function()
		local ok = pcall(core.register_quick_menu_provider, "not a function")
		T.assert(not ok, "provider with non-function should error")
	end)

	T.run("register_quick_menu_action validates type", function()
		local ok = pcall(core.register_quick_menu_action, "qm_bad", "not a function")
		T.assert(not ok, "action with non-function should error")
		local ok2 = pcall(core.register_quick_menu_action, 42, function() end)
		T.assert(not ok2, "action with non-string id should error")
	end)

	local provider_origin

	T.run("provider entries appear in get_quick_menu_entries", function()
		core.register_quick_menu_provider(function()
			return {
				{ label = "[QM] inline", action = function() qm_hits = qm_hits + 1 end },
				{ label = "[QM] toggle", toggle = { "airjump", "spider" } },
				{ label = "[QM] registered", action_id = "qm_test_action" },
			}
		end)
		provider_origin = core.quick_menu_providers[#core.quick_menu_providers].mod
		T.assert(type(provider_origin) == "string" and provider_origin ~= "",
			"provider records an origin mod")

		core.register_quick_menu_action("qm_test_action", function()
			qm_hits = qm_hits + 10
		end)

		local entries = core.get_quick_menu_entries()
		T.assert(type(entries) == "table", "get_quick_menu_entries returns a table")
		local found = {}
		for _, e in ipairs(entries) do
			found[e.label] = e
		end
		T.assert(found["[QM] inline"] ~= nil, "inline entry present")
		T.assert_eq(found["[QM] inline"].kind, "action", "inline entry kind")
		T.assert(found["[QM] toggle"] ~= nil, "toggle entry present")
		T.assert_eq(found["[QM] toggle"].kind, "toggle", "toggle entry kind")
		T.assert(found["[QM] toggle"].toggle[1] == "airjump", "toggle lists settings")
		T.assert(found["[QM] registered"] ~= nil, "registered entry present")
		T.assert_eq(found["[QM] registered"].action_id, "qm_test_action",
			"action_id carried through")
	end)

	T.run("activate inline entry runs action", function()
		qm_hits = 0
		local idx = quick_menu_index_of("[QM] inline")
		T.assert(idx ~= nil, "found inline entry index")
		local ok = core.activate_quick_menu_entry(idx)
		T.assert(ok == true, "activate returns true")
		T.assert_eq(qm_hits, 1, "inline action ran once")
	end)

	T.run("activate registered action entry", function()
		qm_hits = 0
		local idx = quick_menu_index_of("[QM] registered")
		T.assert(idx ~= nil, "found registered entry index")
		local ok = core.activate_quick_menu_entry(idx)
		T.assert(ok == true, "activate returns true")
		T.assert_eq(qm_hits, 10, "registered action ran")
	end)

	T.run("activate toggle entry flips multiple settings", function()
		local a0 = core.settings:get_bool("airjump")
		local s0 = core.settings:get_bool("spider")
		local idx = quick_menu_index_of("[QM] toggle")
		T.assert(idx ~= nil, "found toggle entry index")
		local ok = core.activate_quick_menu_entry(idx)
		T.assert(ok == true, "activate returns true")
		T.assert_eq(core.settings:get_bool("airjump"), not a0, "airjump flipped")
		T.assert_eq(core.settings:get_bool("spider"), not s0, "spider flipped")
		core.settings:set_bool("airjump", a0)
		core.settings:set_bool("spider", s0)
	end)

	T.run("activate out-of-range returns false", function()
		local ok = core.activate_quick_menu_entry(99999)
		T.assert(ok == false, "out-of-range index returns false")
	end)

	T.run("builtin demo entries present", function()
		local entries = core.get_quick_menu_entries()
		local labels = {}
		for _, e in ipairs(entries) do
			labels[e.label] = true
		end
		T.assert(labels["Screenshot"] == true, "Screenshot demo entry")
		T.assert(labels["Toggle All ESP"] == true, "Toggle All ESP demo entry")
		T.assert(labels["Toggle Xray"] == true, "Toggle Xray demo entry")
		T.assert(labels["Reset Camera Roll"] == true, "Reset Camera Roll demo entry")
	end)

	T.run("erroring provider is skipped", function()
		local before = #core.get_quick_menu_entries()
		core.register_quick_menu_provider(function()
			error("intentional provider failure")
		end)
		local after = #core.get_quick_menu_entries()
		T.assert_eq(after, before, "failed provider contributes no entries")
	end)

	T.run("inventory tabs appear in quick menu", function()
		if not core.inv_tabs then
			T.assert(true, "inv_tabs not loaded, skipping")
			return
		end
		local entries = core.get_quick_menu_entries()
		local labels = {}
		for _, e in ipairs(entries) do
			labels[e.label] = true
		end
		T.assert(labels["Player Inventory"] == true,
			"main inventory quick entry present")
		local tabs = core.inv_tabs.get_tabs()
		T.assert(#tabs > 0, "at least one inventory tab registered")
		for _, t in ipairs(tabs) do
			if t.active then
				T.assert(labels[t.title] == true,
					"active tab quick entry present: " .. t.title)
			end
		end
	end)

	T.run("inv_tabs.open validates tab ids", function()
		if not core.inv_tabs then
			T.assert(true, "inv_tabs not loaded, skipping")
			return
		end
		T.assert(type(core.inv_tabs.open) == "function", "inv_tabs.open exists")
		T.assert(core.inv_tabs.open("nonexistent_tab_xyz") == false,
			"open returns false for unknown id")
	end)

	T.run("quick menu exposes one-shot actions from clientmods", function()
		local entries = core.get_quick_menu_entries()
		local by_label = {}
		for _, e in ipairs(entries) do
			by_label[e.label] = e
		end
		local function mod_loaded(mod_name)
			if rawget(_G, mod_name) then
				return true
			end
			return core.get_modpath_real and core.get_modpath_real(mod_name) ~= nil
		end
		local function present(mod_name, label)
			if mod_loaded(mod_name) then
				T.assert(by_label[label] ~= nil,
					"quick entry present for " .. mod_name .. ": " .. label)
			end
		end
		local function present_cmd(cmd_name, label)
			local t = core.registered_chatcommands
			if t and t[cmd_name] then
				T.assert(by_label[label] ~= nil,
					"quick entry present for /" .. cmd_name .. ": " .. label)
			end
		end
		local function present_toggle(mod_name, setting, label)
			if mod_loaded(mod_name) then
				local e = by_label[label]
				T.assert(e ~= nil, "quick toggle entry present: " .. label)
				T.assert_eq(e.kind, "toggle", "toggle entry kind: " .. label)
				T.assert_eq(e.toggle and e.toggle[1], setting,
					"toggle entry setting: " .. label)
			end
		end
		present("poi", "Waypoint Here")
		present("poi", "Show Nearest Waypoint")
		present("autofly", "Warp to Nearest Waypoint")
		present("rhythmtp", "Rhythm TP Forward")
		present("autoeat", "Eat Food Now")
		present("ws", "Make Block from Wielded")
		present("sbots", "Stop All Bots")
		present("dte", "Open Lua IDE")
		present_cmd("schembrowse", "Open Schematic Browser")
		present_cmd("autocraft", "Open Autocraft GUI")
		present_cmd("entityinfo", "Inspect Pointed Thing")
		present_cmd("stats", "Show Session Stats")
		present_cmd("blockstats", "Show Block Stats")
		present_cmd("cheat_rearrange", "Rearrange Cheat Panels")
		present("ws", "Select Best Tool for Pointed Node")
		present("ws", "Clear HUD Markers")
		do
			local e = by_label["Fly (Free Move)"]
			T.assert(e ~= nil, "quick toggle entry present: Fly (Free Move)")
			T.assert_eq(e.kind, "toggle", "toggle entry kind: Fly (Free Move)")
		end
		present_toggle("poi", "poi_show_all_waypoints", "Show All Waypoints")
		present_toggle("chat_logger", "chat_logging", "Log Chat to File")
		present_toggle("devtools", "einv_taker", "Auto-Take Entity Inv")
	end)

	T.run("waypoints appear as quick menu entries", function()
		if not poi then
			T.assert(true, "poi not loaded, skipping")
			return
		end
		local orig_setting = core.settings:get("poi_show_all_waypoints")
		core.settings:set("poi_show_all_waypoints", "false")
		local test_name = "ALTestWaypoint"
		local test_pos = {x = 100, y = 64, z = 200}
		local orig_pos = poi.get_waypoint(test_name)
		poi.set_waypoint(test_pos, test_name)

		local idx = quick_menu_index_of(test_name)
		T.assert(idx ~= nil, "waypoint should appear as a quick menu entry")
		if idx then
			local entries = core.get_quick_menu_entries()
			T.assert_eq(entries[idx].kind, "action", "waypoint entry kind")
			T.assert(entries[idx].description ~= nil
				and entries[idx].description:find("100, 64, 200"),
				"waypoint entry has position description")
		end

		-- Activation selects and shows the waypoint (needs a player to aim/display)
		if idx and core.localplayer then
			local ok = core.activate_quick_menu_entry(idx)
			T.assert(ok, "activation succeeds")
			T.assert_eq(poi.last_name, test_name, "waypoint selected and shown")
		end

		-- All-servers mode still lists it (name carries the server:port: prefix)
		core.settings:set("poi_show_all_waypoints", "true")
		local found_all = nil
		for _, e in ipairs(core.get_quick_menu_entries()) do
			if e.label and e.label:match("ALTestWaypoint$") then
				found_all = e
				break
			end
		end
		T.assert(found_all ~= nil, "waypoint appears in show-all mode")

		-- Cleanup: restore the setting and remove/restore the temp waypoint
		core.settings:set("poi_show_all_waypoints", "false")
		if orig_pos then
			poi.set_waypoint(orig_pos, test_name)
		else
			poi.delete_waypoint(test_name)
		end
		core.settings:set("poi_show_all_waypoints", orig_setting or "false")
	end)

	T.run("unregister_quick_menu_action removes action", function()
		core.register_quick_menu_action("qm_temp_action", function() end)
		T.assert(core.quick_menu_actions["qm_temp_action"] ~= nil, "action registered")
		core.unregister_quick_menu_action("qm_temp_action")
		T.assert(core.quick_menu_actions["qm_temp_action"] == nil, "action removed")
	end)

	T.run("quick_menu_purge_mod removes that mod's registrations", function()
		local prov_before = 0
		for _, p in ipairs(core.quick_menu_providers) do
			if p.mod == provider_origin then prov_before = prov_before + 1 end
		end
		local act_before = 0
		for _, d in pairs(core.quick_menu_actions) do
			if d.mod == provider_origin then act_before = act_before + 1 end
		end
		local cleaned = core.quick_menu_purge_mod(provider_origin)
		T.assert_eq(cleaned, prov_before + act_before, "purge count matches")

		local entries = core.get_quick_menu_entries()
		local labels = {}
		for _, e in ipairs(entries) do
			labels[e.label] = true
		end
		T.assert(labels["[QM] inline"] == nil, "purged provider entries gone")
		T.assert(core.quick_menu_actions["qm_test_action"] == nil, "purged action gone")
	end)

	T.run("toggle entries carry keywords", function()
		local found
		for _, e in ipairs(core.get_quick_menu_entries()) do
			if e.label == "Fly (Free Move)" then found = e end
		end
		T.assert(found ~= nil, "Fly entry present")
		T.assert(type(found.keywords) == "table", "Fly entry has keywords table")
		local has_fly = false
		for _, kw in ipairs(found.keywords) do
			if kw == "fly" then has_fly = true end
		end
		T.assert(has_fly, "Fly entry keyword 'fly'")
	end)

	T.run("toggle entries expose enabled state", function()
		local orig = core.settings:get_bool("free_move")
		core.settings:set_bool("free_move", true)
		local entries = core.get_quick_menu_entries()
		core.settings:set_bool("free_move", orig)
		local found
		for _, e in ipairs(entries) do
			if e.label == "Fly (Free Move)" then found = e end
		end
		T.assert(found ~= nil, "Fly entry present")
		T.assert_eq(found.enabled, true, "Fly toggle enabled reflects setting")
	end)

	T.run("provider entries can carry second-level options", function()
		core.register_quick_menu_provider(function()
			return {
				{
					label = "[QM] submenu",
					action = function() qm_hits = qm_hits + 1 end,
					options = {
						{ label = "[QM] opt A", action = function() qm_hits = qm_hits + 100 end },
						{ label = "[QM] opt toggle", toggle = "airjump" },
					},
				},
			}
		end)
		local entries = core.get_quick_menu_entries()
		local found
		for _, e in ipairs(entries) do
			if e.label == "[QM] submenu" then found = e end
		end
		T.assert(found ~= nil, "entry with options present")
		T.assert(type(found.options) == "table", "entry exposes options table")
		T.assert_eq(#found.options, 2, "options count")
		T.assert_eq(found.options[1].label, "[QM] opt A", "first option label")
		T.assert_eq(found.options[1].kind, "action", "first option kind")
		T.assert_eq(found.options[2].label, "[QM] opt toggle", "second option label")
		T.assert_eq(found.options[2].kind, "toggle", "second option kind")
	end)

	T.run("cheat entries expose standard options", function()
		local entries = core.get_quick_menu_entries()
		local xray
		for _, e in ipairs(entries) do
			if e.label == "Xray" then xray = e end
		end
		T.assert(xray ~= nil, "Xray entry present")
		T.assert(type(xray.options) == "table", "cheat entry exposes options")
		local labels = {}
		for _, o in ipairs(xray.options) do
			labels[o.label] = true
		end
		T.assert(labels["Enable"] or labels["Disable"],
			"cheat options include enable/disable")
		T.assert(labels["Favorite"] or labels["Unfavorite"],
			"cheat options include favorite")
		local has_slot = false
		for _, o in ipairs(xray.options) do
			if o.label == "Slot..." or o.label:match("^Slot ") then has_slot = true end
		end
		T.assert(has_slot, "cheat options include slot picker")
	end)

	T.run("palette search matches fuzzy subsequences", function()
		local entries = core.get_quick_menu_entries("xry")
		local found = false
		for _, e in ipairs(entries) do
			if e.label == "Xray" then found = true end
		end
		T.assert(found, "fuzzy subsequence 'xry' finds Xray")
		local entries2 = core.get_quick_menu_entries("fullb")
		local found2 = false
		for _, e in ipairs(entries2) do
			if e.label == "Fullbright" then found2 = true end
		end
		T.assert(found2, "substring 'fullb' finds Fullbright")
	end)

	T.run("palette search matches second-level option labels", function()
		local entries = core.get_quick_menu_entries("[QM] opt A")
		local found = false
		for _, e in ipairs(entries) do
			if e.label == "[QM] submenu" then found = true end
		end
		T.assert(found,
			"parent surfaces when a submenu option label matches the query")
	end)

	T.run("launcher mode '/' offers a server-send entry", function()
		local entries = core.get_quick_menu_entries("/tp 1 2 3")
		local found = false
		for _, e in ipairs(entries) do
			if e.label == "/tp 1 2 3" then found = true end
		end
		T.assert(found, "server send entry present for '/tp 1 2 3'")
	end)

	T.run("launcher mode '.' lists client commands", function()
		local entries = core.get_quick_menu_entries(".list")
		local found = false
		for _, e in ipairs(entries) do
			if e.label and e.label:sub(1, 1) == "." then found = true break end
		end
		T.assert(found, "client command entries present for '.list'")
	end)

	T.run("recents section lists last activated entry first", function()
		local idx
		for i, e in ipairs(core.get_quick_menu_entries()) do
			if e.label == "Xray" then idx = i break end
		end
		T.assert(idx ~= nil, "Xray present")
		local orig = core.settings:get_bool("xray")
		T.assert(core.activate_quick_menu_entry(idx) == true, "activate Xray")
		core.settings:set_bool("xray", orig)
		local entries = core.get_quick_menu_entries()
		local header_pos, xray_pos
		for i, e in ipairs(entries) do
			if e.label == "Recent" then header_pos = i end
			if e.label == "Xray" then xray_pos = i end
		end
		T.assert(header_pos ~= nil, "Recent header shown when search empty")
		T.assert(xray_pos ~= nil, "Xray still present")
		if header_pos then
			T.assert_eq(xray_pos, header_pos + 1, "Xray is the first recent")
		end
	end)

	T.run("quick_menu_open passes search text to providers", function()
		core.register_quick_menu_provider(function(search)
			return { { label = "[QM] ctx:" .. (search or "") } }
		end)
		core.quick_menu_open("banana")
		local entries = core.get_quick_menu_entries()
		core.quick_menu_close()
		local found = false
		for _, e in ipairs(entries) do
			if e.label == "[QM] ctx:banana" then found = true end
		end
		T.assert(found, "provider received search text via quick_menu_open")
	end)

	T.run("repeat-last row appears after activation", function()
		core.register_quick_menu_provider(function()
			return { { label = "[QM] repeat-src",
				action = function() qm_repeat_hits = qm_repeat_hits + 1 end } }
		end)
		local idx
		for i, e in ipairs(core.get_quick_menu_entries()) do
			if e.label == "[QM] repeat-src" then idx = i break end
		end
		T.assert(idx ~= nil, "repeat-src entry present")
		T.assert(core.activate_quick_menu_entry(idx) == true, "activate repeat-src")
		T.assert_eq(qm_repeat_hits, 1, "repeat-src action ran once")

		local repeat_found = false
		for _, e in ipairs(core.get_quick_menu_entries()) do
			if e.kind == "repeat" then repeat_found = true end
		end
		T.assert(repeat_found, "repeat-last row appears after activation")
	end)
end
