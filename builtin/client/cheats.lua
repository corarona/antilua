core.cheats = {
	["Movement"] = {
		["Freecam"] = "freecam",
		["Freelook"] = "freelook",
		["AutoForward"] = "continuous_forward",
		["PitchMove"] = "pitch_move",
		["AutoJump"] = "autojump",
		["Jesus"] = "jesus",
		["NoSlow"] = "no_slow",
		["JetPack"] = "jetpack",
		["AntiSlip"] = "antislip",
		["AirJump"] = "airjump",
		["Spider"] = "spider",
		["EntitySpeed"] = "entity_speed",
	},
	["Combat"] = {
		["AntiKnockback"] = "antiknockback",
		["AttachmentFloat"] = "float_above_parent",
		["AutoHit"] = "autohit",
	},
	["Render"] = {
		["Xray"] = "xray",
		["Fullbright"] = "fullbright",
		["HUDBypass"] = "hud_flags_bypass",
		["NoHurtCam"] = "no_hurt_cam",
		["BrightNight"] = "no_night",
		["Coords"] = "coords",
		["CheatHUD"] = "cheat_hud",
		["EntityHitboxes"] = "enable_entity_esp",
		["EntityWallhack"] = "enable_entity_wallhack",
		["EntityTracers"] = "enable_entity_tracers",
		["PlayerHitboxes"] = "enable_player_esp",
		["PlayerWallhack"] = "enable_player_wallhack",
		["PlayerTracers"] = "enable_player_tracers",
		["NodeESP"] = "enable_node_esp",
		["NodeTracers"] = "enable_node_tracers",
	},
	["Player"] = {
		["FastDig"] = "fastdig",
		["FastPlace"] = "fastplace",
		["AutoDig"] = "autodig",
		["AutoPlace"] = "autoplace",
		["InstantBreak"] = "instant_break",
		["FastHit"] = "spamclick",
		["NoFallDamage"] = "prevent_natural_damage",
		["NoForceRotate"] = "no_force_rotate",
		["Reach"] = "reach",
		["PointLiquids"] = "point_liquids",
		["PrivBypass"] = "priv_bypass",
		["AutoRespawn"] = "autorespawn",
		["ThroughWalls"] = "dont_point_nodes",
	},
}

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

	local fs = "formspec_version[10]size[5," .. (2 + #keys + 0.5) .. ",true]"
	fs = fs .. "padding[0.5,0.5]no_prepend[]bgcolor[#000000;true]"
	fs = fs .. "label[0,0;" .. core.formspec_escape(def.name) .. " Settings]"
	local y = 1
	for _, key in ipairs(keys) do
		local spec = def.cheat_settings[key]
		local full = setting .. "." .. key
		if spec.type == "bool" then
			fs = fs .. "checkbox[0.3," .. y .. ";" .. full .. ";" .. key .. ";"
				.. (core.settings:get_bool(full) and "true" or "false") .. "]"
		elseif spec.type == "number" then
			fs = fs .. "field[0.3," .. y .. ";4.4,0.8;" .. full .. ";" .. key .. ";"
				.. (core.settings:get(full) or tostring(spec.default)) .. "]"
		else
			fs = fs .. "field[0.3," .. y .. ";4.4,0.8;" .. full .. ";"
				.. key .. ";" .. (core.settings:get(full) or tostring(spec.default)) .. "]"
		end
		y = y + 1.1
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
	for key, spec in pairs(def.cheat_settings) do
		local full = setting .. "." .. key
		if fields[full] then
			core.settings:set(full, fields[full])
		elseif spec.type == "bool" then
			core.settings:set_bool(full, false)
		end
	end
end)
