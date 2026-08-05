-- Tests for the poi waypoint grouping system.
--
-- Drives poi.handle_fields() directly with the fields tables that a real
-- formspec submission sends. Note: dropdowns without an `index event` param
-- submit the selected item's VALUE text (e.g. "Red", "Mine"), not its index.

function test_poi(T)
	T.run("poi module API exists", function()
		T.assert(type(poi) == "table", "poi should be loaded")
		for _, fn in ipairs({
			"set_waypoint", "delete_waypoint", "get_group", "set_group",
			"get_color", "group_color", "handle_fields", "build_formspec_content",
		}) do
			T.assert(type(poi[fn]) == "function", "poi." .. fn .. " should exist")
		end
	end)

	T.run("poi.group_color is deterministic per group", function()
		T.assert(poi.group_color("Mine") == poi.group_color("Mine"),
			"same group should always map to the same color")
		T.assert(poi.group_color("Other") == poi.group_color("Other"),
			"other group should be stable too")
		T.assert(poi.group_color("Death") == 0xff0000,
			"Death group should stay red")
		T.assert(poi.group_color("") == nil, "empty group should have no color")
		T.assert(poi.group_color(nil) == nil, "nil group should have no color")
	end)

	local saved_show_all = core.settings:get_bool("poi_show_all_waypoints")
	core.settings:set_bool("poi_show_all_waypoints", false)

	-- poi prefixes displayed waypoint HUDs with this dot (matches poi's WP_DOT).
	local WP_DOT = "● "

	local test_wps = {}

	local function cleanup()
		for _, name in ipairs(poi.getwps()) do
			if name:find("^poi_test") then
				poi.delete_waypoint(name)
			end
		end
		for _, name in ipairs(test_wps) do
			poi.delete_waypoint(name)
		end
		for key in pairs(ws.hud_waypoints) do
			if key:find(WP_DOT .. "poi_test") then
				ws.hud_remove_waypoint(key)
			end
		end
		test_wps = {}
		core.settings:set_bool("poi_show_all_waypoints", saved_show_all)
		core.close_formspec("poi-csm")
	end

	-- Cleanup runs in the deferred phase too: the deferred tests create the
	-- waypoints, so running cleanup at registration time would delete nothing
	-- and leak waypoints (with their groups) into mod storage between runs.
	T.defer("poi test cleanup (pre)", cleanup)

	local function reset_state()
		poi.handle_fields({ key_enter_field = "poi_search", poi_search = "" })
		poi.handle_fields({ group_filter = "All" })
	end

	local function mk_wp(name, x)
		poi.set_waypoint({ x = x, y = 5, z = -x }, name)
		test_wps[#test_wps + 1] = name
		return name
	end

	-- 1-based index of `name` inside the wp_list textlist of a built formspec.
	local function waypoint_index(fs, name)
		local m = fs:match("textlist%[[^%]]*;wp_list;([^%]]*)%]")
		if not m then return nil end
		local parts = {}
		for p in m:gmatch("[^;]+") do parts[#parts + 1] = p end
		local i = 0
		for item in parts[1]:gmatch("[^,]+") do
			i = i + 1
			-- Strip the #rrggbb textlist color prefix and the distance suffix.
			local bare = item:gsub("^#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]", "")
			bare = bare:gsub("%s%(%d+m%)%s*$", "")
			if bare == name then return i end
		end
		return nil
	end

	-- Select `name` in the waypoint list by simulating a textlist click.
	local function select_wp(name)
		local fs = poi.build_formspec_content()
		local idx = waypoint_index(fs, name)
		T.assert(idx ~= nil, "waypoint " .. name .. " should appear in the list")
		poi.handle_fields({ wp_list = "CHG:" .. idx })
	end

	-- Interaction tests need core.localplayer (poi's re-render may sort by
	-- distance), so defer them like the other poi tests.
	T.defer("Group field + Enter stores the group", function()
		reset_state()
		mk_wp("poi_test_a", 1000)
		select_wp("poi_test_a")
		T.assert(poi.get_group("poi_test_a") == "", "new waypoint should start with no group")

		-- A real submission sends every widget value at once; Enter was pressed
		-- in the Group field. group_filter used to swallow this and redraw.
		poi.handle_fields({
			group_filter = "All",
			poi_show_all = "false",
			wp_color = "Green",
			wp_group = "Mine",
			key_enter_field = "wp_group",
		})
		T.assert_eq(poi.get_group("poi_test_a"), "Mine",
			"group typed into the Group field should be stored")
	end)

	T.defer("Group field with unchanged text keeps the group", function()
		select_wp("poi_test_a")
		poi.handle_fields({
			group_filter = "All",
			poi_show_all = "false",
			wp_color = "Green",
			wp_group = "Mine",
			key_enter_field = "wp_group",
		})
		T.assert_eq(poi.get_group("poi_test_a"), "Mine",
			"resubmitting the same group text should be harmless")
	end)

	T.defer("color dropdown applies the picked color", function()
		reset_state()
		select_wp("poi_test_a")
		poi.handle_fields({ wp_color = "Red" })
		T.assert_eq(poi.get_color("poi_test_a"), "ff0000",
			"color picked in the dropdown should be stored")
	end)

	T.defer("group filter restricts the waypoint list", function()
		reset_state()
		mk_wp("poi_test_b", 1001)
		poi.set_group("poi_test_b", "Other")

		local all_fs = poi.build_formspec_content()
		T.assert(waypoint_index(all_fs, "poi_test_a") ~= nil, "unfiltered list should include poi_test_a")
		T.assert(waypoint_index(all_fs, "poi_test_b") ~= nil, "unfiltered list should include poi_test_b")

		local mine_hex = string.format("#%06x", poi.group_color("Mine"))
		local other_hex = string.format("#%06x", poi.group_color("Other"))
		T.assert(all_fs:find(mine_hex .. "poi_test_a", 1, true) ~= nil,
			"poi_test_a should be colored with the Mine group color")
		T.assert(all_fs:find(other_hex .. "poi_test_b", 1, true) ~= nil,
			"poi_test_b should be colored with the Other group color")

		poi.handle_fields({ group_filter = "Mine" })

		local mine_fs = poi.build_formspec_content()
		T.assert(waypoint_index(mine_fs, "poi_test_a") ~= nil,
			"filtered list should keep poi_test_a (group Mine)")
		T.assert(waypoint_index(mine_fs, "poi_test_b") == nil,
			"filtered list should drop poi_test_b (group Other)")
	end)

	T.defer("unrelated no-op submission does not lose the group", function()
		reset_state()
		select_wp("poi_test_a")
		poi.handle_fields({ group_filter = "All", poi_show_all = "false", wp_color = "Red" })
		T.assert_eq(poi.get_group("poi_test_a"), "Mine",
			"an unrelated submit should not change the stored group")
	end)

	T.defer("Show all button shows the group's waypoints as HUDs", function()
		reset_state()
		ws.hud_remove_waypoint(WP_DOT .. "poi_test_a")
		ws.hud_remove_waypoint(WP_DOT .. "poi_test_b")

		poi.handle_fields({ group_filter = "Mine" })
		poi.handle_fields({ show_all = "Show all" })

		T.assert(ws.hud_waypoints[WP_DOT .. "poi_test_a"] ~= nil,
			"poi_test_a (group Mine) should be displayed as a HUD waypoint")
		T.assert(ws.hud_waypoints[WP_DOT .. "poi_test_b"] == nil,
			"poi_test_b (group Other) should not be displayed")
	end)

	T.defer("displayed waypoints use dot-prefixed names colored by group", function()
		reset_state()
		ws.hud_remove_waypoint(WP_DOT .. "poi_test_a")
		poi.set_hud_wp(poi.get_waypoint("poi_test_a"), "poi_test_a")

		T.assert(ws.hud_waypoints[WP_DOT .. "poi_test_a"] ~= nil,
			"displayed waypoint should be registered under its dot-prefixed name")

		ws.hud_remove_waypoint(WP_DOT .. "poi_test_a")
		poi.set_group("poi_test_a", "")
		poi.set_hud_wp(poi.get_waypoint("poi_test_a"), "poi_test_a")
		T.assert(ws.hud_waypoints[WP_DOT .. "poi_test_a"] ~= nil,
			"ungrouped waypoint should also be dot-prefixed")
		ws.hud_remove_waypoint(WP_DOT .. "poi_test_a")
	end)

	T.defer("waypoint list always shows the distance", function()
		reset_state()
		mk_wp("poi_test_dist", 2000)
		local fs = poi.build_formspec_content()
		T.assert(fs:match("poi_test_dist %(%d+m%)") ~= nil,
			"list entry should include the distance even without Dist sort")
	end)

	T.defer("Add Here stores a waypoint at the current position", function()
		reset_state()
		local pos = core.localplayer:get_pos()
		poi.handle_fields({ add_here = "Add Here" })
		poi.handle_fields({ new_wp_name = "poi_test_here", add_here_confirm = "Add" })
		local stored = poi.get_waypoint("poi_test_here")
		T.assert(stored ~= nil, "Add Here should store a waypoint")
		T.assert(vector.distance(stored, vector.round(pos)) <= 1,
			"stored position should be the current position")
		poi.delete_waypoint("poi_test_here")
	end)

	T.defer("displayed waypoints mirror as minimap markers", function()
		if not core.ui.minimap or not core.ui.minimap.add_marker then return end
		reset_state()
		ws.hud_remove_waypoint(WP_DOT .. "poi_test_a")
		mk_wp("poi_test_mm", 700)
		poi.display(poi.get_waypoint("poi_test_mm"), "poi_test_mm")
		local id = poi.get_displayed_marker("poi_test_mm")
		T.assert(type(id) == "number", "displayed waypoint should get a minimap marker id")

		core.registered_chatcommands.clear_waypoint.func("")
		T.assert(poi.get_displayed_marker("poi_test_mm") == nil,
			"clear_waypoint should remove the minimap marker")
		T.assert(core.ui.minimap:remove_marker(id) == false,
			"marker should already be removed after clearing")
	end)

	T.defer("far waypoints still mirror as minimap markers", function()
		if not core.ui.minimap or not core.ui.minimap.add_marker then return end
		reset_state()
		-- Waypoint far outside the minimap's scan area: its dot is edge-clamped
		-- to the rim, so it must still be registered and removable.
		mk_wp("poi_test_far", 50000)
		poi.display(poi.get_waypoint("poi_test_far"), "poi_test_far")
		local id = poi.get_displayed_marker("poi_test_far")
		T.assert(type(id) == "number",
			"a waypoint outside the minimap range should still get a marker id")

		core.registered_chatcommands.clear_waypoint.func("")
		T.assert(poi.get_displayed_marker("poi_test_far") == nil,
			"clear_waypoint should remove the far waypoint marker")
		T.assert(core.ui.minimap:remove_marker(id) == false,
			"far marker should already be removed after clearing")
	end)

	T.defer("poi test cleanup (post)", cleanup)
end
