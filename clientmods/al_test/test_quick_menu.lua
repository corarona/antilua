-- Tests for the Quick Access Palette (~) Lua API

local qm_hits = 0

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
end
