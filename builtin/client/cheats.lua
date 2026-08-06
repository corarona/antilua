core.cheats = {}

core.cheat_defs = {}

function core.register_cheat(name, ...)
	local def
	if type(name) == "table" then
		def = name
	elseif type(select(1, ...)) == "table" then
		def = select(1, ...)
		def.name = name
	else
		local category, setting_or_func = ...
		def = { name = name, category = category }
		if type(setting_or_func) == "string" then
			def.setting = setting_or_func
		else
			def.func = setting_or_func
		end
	end

	-- Idempotent: skip if already registered (avoids duplicates on mod reload)
	if core.cheats[def.category] and core.cheats[def.category][def.name] then
		return core.cheats[def.category][def.name]
	end

	def.conflicts_with = def.conflicts_with or {}

	if def.setting then
		if core.settings:get(def.setting) == nil then
			core.settings:set(def.setting, "false")
		end
		core.cheat_defs[def.setting] = def
		if def.cheat_settings then
			for key, spec in pairs(def.cheat_settings) do
				local full = def.setting .. "." .. key
				if core.settings:get(full) == nil then
					core.settings:set(full, tostring(spec.default))
				end
			end
		end
	end

	core.cheats[def.category] = core.cheats[def.category] or {}
	core.cheats[def.category][def.name] = def.setting or def.func

	return def
end

-- Profile management
function core.save_cheat_profile(name)
	local enabled = {}
	for setting, def in pairs(core.cheat_defs) do
		if core.settings:get_bool(setting) then
			table.insert(enabled, setting)
		end
	end
	core.settings:set("cheat_profile_" .. name, table.concat(enabled, ","))
	local list = core.settings:get("cheat_profile_names") or ""
	local names = {}
	for n in list:gmatch("[^,]+") do
		if n ~= name then table.insert(names, n) end
	end
	table.insert(names, name)
	core.settings:set("cheat_profile_names", table.concat(names, ","))
	core.settings:write()
end

function core.load_cheat_profile(name)
	local data = core.settings:get("cheat_profile_" .. name)
	if not data or data == "" then return false end
	local profiled = {}
	for setting in data:gmatch("[^,]+") do
		profiled[setting] = true
	end
	for setting, def in pairs(core.cheat_defs) do
		core.settings:set_bool(setting, profiled[setting] == true)
	end
	core.settings:write()
	return true
end

function core.delete_cheat_profile(name)
	core.settings:set("cheat_profile_" .. name, "")
	local list = core.settings:get("cheat_profile_names") or ""
	local names = {}
	for n in list:gmatch("[^,]+") do
		if n ~= name then table.insert(names, n) end
	end
	core.settings:set("cheat_profile_names", table.concat(names, ","))
	core.settings:write()
end

function core.list_cheat_profiles()
	local list = core.settings:get("cheat_profile_names") or ""
	local names = {}
	for n in list:gmatch("[^,]+") do
		table.insert(names, n)
	end
	return names
end

function core.save_cheat_profile_dialog()
	local fs = "formspec_version[10]size[6,3]"
		.. "no_prepend[]"
		.. "field[0.3,0.8;5.4,0.8;profile_name;Profile name;]"
		.. "button[0.3,1.8;2.5,0.8;profile_save;Save]"
		.. "button_exit[3.2,1.8;2.5,0.8;profile_cancel;Cancel]"
	core.show_formspec("antilua_save_profile", fs)
end

function core.show_slot_picker(setting)
	local fs = "formspec_version[10]size[6,5]"
		.. "no_prepend[]label[0.3,0.2;Select slot for " .. core.formspec_escape(setting) .. "]"
	for i = 1, 9 do
		local assigned = core.settings:get("cheat_slot_" .. i)
		local label = (assigned == setting) and ("[x] Slot " .. i) or ("[ ] Slot " .. i)
		local row = math.floor((i - 1) / 3)
		local col = (i - 1) % 3
		fs = fs .. "button[" .. (col * 2) .. "," .. (row * 0.7 + 0.7) .. ";1.8,0.6;slot_" .. i .. ";" .. core.formspec_escape(label) .. "]"
	end
	fs = fs .. "button_exit[0.3," .. (3.5) .. ";5.4,0.8;slot_done;Done]"
	core.show_formspec("antilua_slot_picker:" .. setting, fs)
end

core.register_on_formspec_input(function(formname, fields)
	local toggle_mode = core.settings:get_bool("cheat_menu_toggle_mode")

	-- Reopen cheat menu when a cheat-related formspec is closed
	local function reopen_on_quit()
		if fields.quit then
			core.after(0.05, function()
				core.cheat_menu_set_visible(toggle_mode)
			end)
		end
	end

	-- Save profile dialog
	if formname == "antilua_save_profile" then
		reopen_on_quit()
		if fields.profile_save then
			local name = fields.profile_name
			if name and #name > 0 then
				core.save_cheat_profile(name)
				ws.notify("Profile '" .. name .. "' saved.", ws.NOTIFY_INFO)
			end
		end
		return true
	end

	-- Slot picker
	local slot_prefix = "antilua_slot_picker:"
	if formname:sub(1, #slot_prefix) == slot_prefix then
		reopen_on_quit()
		local setting = formname:sub(#slot_prefix + 1)
		for i = 1, 9 do
			if fields["slot_" .. i] then
				local current = core.settings:get("cheat_slot_" .. i)
				if current == setting then
					core.settings:set("cheat_slot_" .. i, "")
				else
					core.settings:set("cheat_slot_" .. i, setting)
				end
				core.show_slot_picker(setting)
				return true
			end
		end
		return true
	end

	-- Cheat settings formspec (opened from gear icon or context menu)
	if formname:find("^cheat_settings:") == 1 then
		reopen_on_quit()
		return false
	end
end)

-- Chat command for profile management
core.register_chatcommand("profile", {
	params = "save|load|list|delete [name]",
	description = "Manage cheat profiles",
	func = function(param)
		param = param or ""
		local parts = {}
		for p in param:gmatch("%S+") do
			table.insert(parts, p)
		end
		local cmd = parts[1]
		if not cmd then
			return false, "Usage: .profile save|load|list|delete [name]"
		end
		if cmd == "save" then
			local pname = parts[2]
			if not pname then
				return false, "Usage: .profile save <name>"
			end
			core.save_cheat_profile(pname)
			return true, "Profile '" .. pname .. "' saved."
		elseif cmd == "load" then
			local pname = parts[2]
			if not pname then
				return false, "Usage: .profile load <name>"
			end
			if core.load_cheat_profile(pname) then
				return true, "Profile '" .. pname .. "' loaded."
			else
				return false, "Profile '" .. pname .. "' not found."
			end
		elseif cmd == "list" then
			local profiles = core.list_cheat_profiles()
			if #profiles == 0 then
				return true, "No saved profiles."
			end
			return true, "Profiles: " .. table.concat(profiles, ", ")
		elseif cmd == "delete" then
			local pname = parts[2]
			if not pname then
				return false, "Usage: .profile delete <name>"
			end
			core.delete_cheat_profile(pname)
			return true, "Profile '" .. pname .. "' deleted."
		else
			return false, "Unknown command: " .. cmd .. ". Use save|load|list|delete."
		end
	end,
})

-- Movement cheats
core.register_cheat({ name = "Freecam", category = "Movement", setting = "freecam",
	description = "Detach camera for free movement" })
core.register_cheat({ name = "Freelook", category = "Movement", setting = "freelook",
	description = "Look around freely while moving" })
core.register_cheat({ name = "AutoForward", category = "Movement", setting = "continuous_forward",
	description = "Automatically move forward" })
core.register_cheat({ name = "PitchMove", category = "Movement", setting = "pitch_move",
	description = "Move in the direction you are looking" })
core.register_cheat({ name = "AutoJump", category = "Movement", setting = "autojump",
	description = "Automatically jump when hitting obstacles" })
core.register_cheat({ name = "Jesus", category = "Movement", setting = "jesus",
	description = "Walk on liquids",
	conflicts_with = { "spider", "jetpack", "freecam" } })
core.register_cheat({ name = "NoSlow", category = "Movement", setting = "no_slow",
	description = "Prevent movement speed reduction" })
core.register_cheat({ name = "JetPack", category = "Movement", setting = "jetpack",
	description = "Fly upward by holding the jump key",
	conflicts_with = { "jesus", "spider", "freecam" } })
core.register_cheat({ name = "AntiSlip", category = "Movement", setting = "antislip",
	description = "Prevent slipping on slippery surfaces" })
core.register_cheat({ name = "AirJump", category = "Movement", setting = "airjump",
	description = "Jump while in mid-air",
	conflicts_with = { "jesus", "spider" } })
core.register_cheat({ name = "Spider", category = "Movement", setting = "spider",
	description = "Climb walls like a spider",
	conflicts_with = { "jesus", "jetpack", "freecam" } })
core.register_cheat({ name = "EntitySpeed", category = "Movement", setting = "entity_speed",
	description = "Increase entity movement speed" })

-- Combat cheats
core.register_cheat({ name = "AntiKnockback", category = "Combat", setting = "antiknockback",
	description = "Prevent knockback from attacks" })
core.register_cheat({ name = "AttachmentFloat", category = "Combat", setting = "float_above_parent",
	description = "Float above attached parent" })
core.register_cheat({ name = "AutoHit", category = "Combat", setting = "autohit",
	description = "Automatically attack nearby entities" })

-- Render cheats
core.register_cheat({ name = "Xray", category = "Render", setting = "xray",
	description = "See ores and nodes through walls" })
core.register_cheat({ name = "Fullbright", category = "Render", setting = "fullbright",
	description = "Brighten surfaces to a configurable minimum light level",
	cheat_settings = {
		min_level = { type = "int", default = 15, min = 0, max = 15 },
	} })
core.register_cheat({ name = "HUDBypass", category = "Render", setting = "hud_flags_bypass",
	description = "Bypass HUD flags set by the server" })
core.register_cheat({ name = "NoHurtCam", category = "Render", setting = "no_hurt_cam",
	description = "Disable hurt camera effects" })
core.register_cheat({ name = "CheatHUD", category = "Render", setting = "cheat_hud",
	description = "Show active cheat indicators on screen",
	cheat_settings = {
		speed = { type = "number", default = 1.0, min = 0.1, max = 10.0 },
	} })
core.register_cheat({ name = "EntityHitboxes", category = "Render", setting = "enable_entity_esp",
	description = "Highlight entity hitboxes" })
core.register_cheat({ name = "EntityWallhack", category = "Render", setting = "enable_entity_wallhack",
	description = "See entities through walls" })
core.register_cheat({ name = "EntityTracers", category = "Render", setting = "enable_entity_tracers",
	description = "Draw tracer lines to entities" })
core.register_cheat({ name = "PlayerHitboxes", category = "Render", setting = "enable_player_esp",
	description = "Highlight player hitboxes" })
core.register_cheat({ name = "PlayerWallhack", category = "Render", setting = "enable_player_wallhack",
	description = "See players through walls" })
core.register_cheat({ name = "PlayerTracers", category = "Render", setting = "enable_player_tracers",
	description = "Draw tracer lines to players" })
core.register_cheat({ name = "NodeESP", category = "Render", setting = "enable_node_esp",
	description = "Highlight nodes through walls" })
core.register_cheat({ name = "NodeTracers", category = "Render", setting = "enable_node_tracers",
	description = "Draw tracer lines to selected nodes" })
core.register_cheat({ name = "BigMap", category = "Render",
	func = function() core.al_bigmap:toggle() end,
	description = "Open the client-side big map" })

-- Player cheats
core.register_cheat({ name = "FastDig", category = "Player", setting = "fastdig",
	description = "Dig nodes faster" })
core.register_cheat({ name = "FastPlace", category = "Player", setting = "fastplace",
	description = "Place nodes faster" })
core.register_cheat({ name = "AutoDig", category = "Player", setting = "autodig",
	description = "Automatically dig pointed node" })
core.register_cheat({ name = "AutoPlace", category = "Player", setting = "autoplace",
	description = "Automatically place selected node" })
core.register_cheat({ name = "InstantBreak", category = "Player", setting = "instant_break",
	description = "Break nodes instantly" })
core.register_cheat({ name = "FastHit", category = "Player", setting = "spamclick",
	description = "Hit entities at maximum speed" })
core.register_cheat({ name = "NoFallDamage", category = "Player", setting = "prevent_natural_damage",
	description = "Prevent fall damage" })
core.register_on_damage_sending(function(amount)
	if core.settings:get_bool("prevent_natural_damage") then
		return true
	end
end)
core.register_cheat({ name = "NoForceRotate", category = "Player", setting = "no_force_rotate",
	description = "Prevent forced rotation by server" })
core.register_cheat({ name = "Reach", category = "Player", setting = "reach",
	description = "Extend interaction range beyond normal tool range",
	cheat_settings = {
		range = { type = "number", default = 6.6, min = 1.0, max = 100.0 },
	} })
core.register_cheat({ name = "PointAll", category = "Player", setting = "point_all",
	description = "Point at any reachable node or entity" })
core.register_cheat({ name = "PrivBypass", category = "Player", setting = "priv_bypass",
	description = "Bypass server privilege restrictions" })
core.register_cheat({ name = "AutoRespawn", category = "Player", setting = "autorespawn",
	description = "Automatically respawn on death" })
core.register_cheat({ name = "ThroughWalls", category = "Player", setting = "dont_point_nodes",
	description = "Point through walls at blocked nodes" })

function core.show_cheat_settings_form(setting, use_auto)
	local def = core.cheat_defs[setting]
	if not def then return end

	-- Custom formspec via get_formspec field
	if def.get_formspec and not use_auto then
		local fs = def.get_formspec(setting)
		if fs then
			core.show_formspec("cheat_settings:" .. setting .. ":custom",
				"formspec_version[10]" .. fs)
			return
		end
	end

	-- Auto-generated formspec from cheat_settings
	if not def.cheat_settings then return end
	if not next(def.cheat_settings) then return end

	local keys = {}
	for k, _ in pairs(def.cheat_settings) do
		table.insert(keys, k)
	end
	table.sort(keys)

	-- Calculate form height: each dropdown row is taller (label + dropdown)
	local form_h = 2
	for _, key in ipairs(keys) do
		local spec = def.cheat_settings[key]
		if (spec.type == "string" and spec.options) or (spec.type == "enum" and spec.values) then
			form_h = form_h + 1.5
		else
			form_h = form_h + 1.1
		end
	end
	form_h = form_h + 1.3

	local fs = "formspec_version[10]size[5," .. form_h .. ",true]"
	local theme_bg = core.settings:get("theme_bg") or "#121212"
	fs = fs .. "padding[0.5,0.5]no_prepend[]bgcolor[" .. theme_bg .. ";true]"
	fs = fs .. "label[0,0.3;" .. core.formspec_escape(def.name) .. " Settings]"
	local y = 1
	for _, key in ipairs(keys) do
		local spec = def.cheat_settings[key]
		local full = setting .. "." .. key
		if spec.type == "bool" then
			fs = fs .. "checkbox[0.3," .. y .. ";" .. full .. ";" .. key .. ";"
				.. (core.settings:get_bool(full) and "true" or "false") .. "]"
			y = y + 1.1
		elseif spec.type == "number" then
			fs = fs .. "field[0.3," .. y .. ";4.4,0.8;" .. full .. ";" .. key .. ";"
				.. (core.settings:get(full) or tostring(spec.default)) .. "]"
			y = y + 1.1
		elseif (spec.type == "string" and spec.options) or (spec.type == "enum" and spec.values) then
			local items = spec.options or spec.values
			local current = core.settings:get(full) or tostring(spec.default)
			local selected = 1
			for i, opt in ipairs(items) do
				if opt == current then selected = i; break end
			end
			fs = fs .. "label[0.3," .. y .. ";" .. core.formspec_escape(key) .. "]"
			fs = fs .. "dropdown[0.3," .. (y + 0.35) .. ";4.4,0.7;" .. full .. ";"
				.. table.concat(items, ",") .. ";" .. selected .. "]"
			y = y + 1.5
		else
			fs = fs .. "field[0.3," .. y .. ";4.4,0.8;" .. full .. ";"
				.. key .. ";" .. (core.settings:get(full) or tostring(spec.default)) .. "]"
			y = y + 1.1
		end
	end
	fs = fs .. "button[0.5," .. (y + 0.3) .. ";1.5,0.8;__help;?]"
	fs = fs .. "button_exit[3," .. (y + 0.3) .. ";2,0.8;;Save]"

	core.show_formspec("cheat_settings:" .. setting, fs)
end

core.register_on_formspec_input(function(formname, fields)
	if formname:find("cheat_settings:") ~= 1 then return end

	-- Detect the __cheat_settings__ button from a custom formspec
	if fields.__cheat_settings__ then
		local setting
		if formname:find(":custom$") then
			setting = formname:sub(16, -8)
		else
			setting = formname:sub(16)
		end
		core.show_cheat_settings_form(setting, true)
		return
	end

	-- Help button — open the relevant README
	if fields.__help then
		local setting
		if formname:find(":custom$") then
			setting = formname:sub(16, -8)
		else
			setting = formname:sub(16)
		end
		if core.show_cheat_help then
			core.show_cheat_help(setting)
		end
		return
	end

	local setting = formname:sub(16)
	if formname:find(":custom$") then
		setting = formname:sub(16, -8)
	end
	local def = core.cheat_defs[setting]
	if not def or not def.cheat_settings then return end
	local changed = false
	for full, value in pairs(fields) do
		if full:find("^" .. setting .. "%.") == 1 then
			local key = full:sub(#setting + 2)
			local spec = def.cheat_settings[key]
			if spec then
				if spec.type == "bool" then
					core.settings:set_bool(full, value == "true")
				else
					core.settings:set(full, value)
				end
				changed = true
			end
		end
	end
	if changed then
		core.settings:write()
	end
end)

-- Quick Access Palette (opened with ~)
-- Providers generate entries for the palette; actions are run when an entry
-- referencing them is activated. Registration is tracked per mod so the
-- registrations are purged and re-created cleanly on mod reload / DTE edits.

core.quick_menu_providers = {}
core.quick_menu_actions = {}

local quick_menu_origin = function()
	return core.get_current_modname() or "??"
end

function core.register_quick_menu_provider(func)
	if type(func) ~= "function" then
		error("register_quick_menu_provider: expected function, got " .. type(func), 2)
	end
	core.quick_menu_providers[#core.quick_menu_providers + 1] = {
		func = func,
		mod = quick_menu_origin(),
	}
end

function core.register_quick_menu_action(id, func)
	if type(id) ~= "string" then
		error("register_quick_menu_action: id must be a string", 2)
	end
	if type(func) ~= "function" then
		error("register_quick_menu_action: expected function, got " .. type(func), 2)
	end
	core.quick_menu_actions[id] = {
		func = func,
		mod = quick_menu_origin(),
	}
end

function core.unregister_quick_menu_action(id)
	core.quick_menu_actions[id] = nil
end

function core.quick_menu_purge_mod(modname)
	local cleaned = 0
	for i = #core.quick_menu_providers, 1, -1 do
		if core.quick_menu_providers[i].mod == modname then
			table.remove(core.quick_menu_providers, i)
			cleaned = cleaned + 1
		end
	end
	for id, def in pairs(core.quick_menu_actions) do
		if def.mod == modname then
			core.quick_menu_actions[id] = nil
			cleaned = cleaned + 1
		end
	end
	return cleaned
end

-- Built-in quick menu entries
core.register_quick_menu_action("quickmenu_toggle_esp", function()
	local esp = {
		"enable_entity_esp", "enable_entity_wallhack", "enable_entity_tracers",
		"enable_player_esp", "enable_player_wallhack", "enable_player_tracers",
	}
	for _, setting in ipairs(esp) do
		core.settings:set_bool(setting, not core.settings:get_bool(setting))
	end
end)

core.register_quick_menu_provider(function()
	return {
		{ label = "Screenshot", action = function() core.make_screenshot() end },
		{ label = "Reset Camera Roll", action = function()
			if core.localplayer then
				core.localplayer:set_roll(0)
			end
		end },
		{ label = "Toggle Xray", toggle = "xray" },
		{ label = "Toggle Fullbright", toggle = "fullbright" },
		{ label = "Toggle Freecam", toggle = "freecam" },
		{ label = "Toggle NoFall", toggle = "prevent_natural_damage" },
		{ label = "Toggle All ESP", action_id = "quickmenu_toggle_esp" },
	}
end)
