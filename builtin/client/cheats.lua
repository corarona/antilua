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
	description = "Walk on liquids" })
core.register_cheat({ name = "NoSlow", category = "Movement", setting = "no_slow",
	description = "Prevent movement speed reduction" })
core.register_cheat({ name = "JetPack", category = "Movement", setting = "jetpack",
	description = "Fly upward by holding the jump key" })
core.register_cheat({ name = "AntiSlip", category = "Movement", setting = "antislip",
	description = "Prevent slipping on slippery surfaces" })
core.register_cheat({ name = "AirJump", category = "Movement", setting = "airjump",
	description = "Jump while in mid-air" })
core.register_cheat({ name = "Spider", category = "Movement", setting = "spider",
	description = "Climb walls like a spider" })
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
	description = "Brighten all surfaces for full visibility" })
core.register_cheat({ name = "HUDBypass", category = "Render", setting = "hud_flags_bypass",
	description = "Bypass HUD flags set by the server" })
core.register_cheat({ name = "NoHurtCam", category = "Render", setting = "no_hurt_cam",
	description = "Disable hurt camera effects" })
core.register_cheat({ name = "CheatHUD", category = "Render", setting = "cheat_hud",
	description = "Show active cheat indicators on screen" })
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
core.register_cheat({ name = "NoForceRotate", category = "Player", setting = "no_force_rotate",
	description = "Prevent forced rotation by server" })
core.register_cheat({ name = "Reach", category = "Player", setting = "reach",
	description = "Extend interaction distance" })
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
	fs = fs .. "button_exit[1.5," .. (y + 0.3) .. ";2,0.8;;Save]"

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
