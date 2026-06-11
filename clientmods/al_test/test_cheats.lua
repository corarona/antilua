-- Tests for Antilua cheat features

function test_cheat_settings(T)
	-- Verify all expected cheat settings exist
	local expected_cheats = {
		"airjump", "spider", "jetpack", "no_slow", "antislip",
		"entity_speed", "antiknockback", "autodig", "fastdig",
		"jesus", "fastplace", "autoplace", "instant_break",
		"point_liquids", "spamclick",
		"no_force_rotate", "freecam", "freelook", "xray", "fullbright",
		"priv_bypass", "prevent_natural_damage", "no_hurt_cam",
		"reach", "hud_flags_bypass", "float_above_parent",
		"killaura", "scaffold", "autohit",
		"enable_entity_esp", "enable_entity_tracers",
		"enable_player_esp", "enable_player_tracers",
		"player_radar", "chest_stealer", "auto_death_waypoint", "auto_death_waypoint_max",
		"auto_torch", "auto_sort", "block_logger", "chat_alerts",
		"name_colorizer", "auto_screenshot", "light_overlay",
		"enable_node_esp",
		"autojump", "continuous_forward",
	}

	for _, name in ipairs(expected_cheats) do
		T.run("cheat setting exists: " .. name, function()
			local val = core.settings:get(name)
			T.assert(val ~= nil, "setting '" .. name .. "' should exist, got nil")
		end)
	end

	-- Verify cheat menu settings
	local menu_settings = {
		"cheat_menu_font", "cheat_menu_bg_color", "cheat_menu_bg_color_alpha",
		"cheat_menu_active_bg_color", "cheat_menu_active_bg_color_alpha",
		"cheat_menu_font_color", "cheat_menu_font_color_alpha",
		"cheat_menu_selected_font_color", "cheat_menu_selected_font_color_alpha",
		"cheat_menu_head_height", "cheat_menu_entry_height", "cheat_menu_entry_width",
	}

	for _, name in ipairs(menu_settings) do
		T.run("cheat menu setting exists: " .. name, function()
			local val = core.settings:get(name)
			T.assert(val ~= nil, "setting '" .. name .. "' should exist, got nil")
		end)
	end

	-- Verify cheat key bindings
	local key_bindings = {
		"keymap_toggle_cheat_menu", "keymap_toggle_freecam",
		"keymap_toggle_killaura", "keymap_toggle_scaffold",
		"keymap_select_up", "keymap_select_down", "keymap_select_left",
		"keymap_select_right", "keymap_select_confirm", "keymap_enderchest",
	}

	for _, name in ipairs(key_bindings) do
		T.run("cheat key binding exists: " .. name, function()
			local val = core.settings:get(name)
			T.assert(val ~= nil, "key binding '" .. name .. "' should exist, got nil")
		end)
	end

	-- Verify xray_nodes default
	T.run("xray_nodes has default value", function()
		local val = core.settings:get("xray_nodes")
		T.assert(val ~= nil and val ~= "",
			"xray_nodes should have a non-empty default")
	end)

	-- Verify cheat toggles work end-to-end
	T.run("toggle cheat via g_settings", function()
		-- Save original state
		local orig = core.settings:get("airjump")
		-- Toggle on
		core.settings:set("airjump", "true")
		T.assert_eq(core.settings:get("airjump"), "true", "airjump should be true")
		-- Toggle off
		core.settings:set("airjump", "false")
		T.assert_eq(core.settings:get("airjump"), "false", "airjump should be false")
		-- Restore
		if orig then
			core.settings:set("airjump", orig)
		end
	end)

	-- Verify show_cheat_settings_form works
	T.run("show_cheat_settings_form known setting", function()
		core.show_cheat_settings_form("scaffold")
		core.close_formspec("cheat_settings:scaffold")
		T.assert(true, "show_cheat_settings_form on scaffold completed without error")
	end)

	T.run("show_cheat_settings_form unknown setting", function()
		core.show_cheat_settings_form("nonexistent_setting_xyz")
		T.assert(true, "show_cheat_settings_form on unknown setting completed without error")
	end)
end
