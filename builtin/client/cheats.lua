core.cheats = {
	["Combat"] = {
		["AntiKnockback"] = "antiknockback",
		["AttachmentFloat"] = "float_above_parent",
	},
	["Movement"] = {
		["Freecam"] = "freecam",
		["AutoForward"] = "continuous_forward",
		["PitchMove"] = "pitch_move",
		["AutoJump"] = "autojump",
		["Jesus"] = "jesus",
		["NoSlow"] = "no_slow",
		["JetPack"] = "jetpack",
		["AntiSlip"] = "antislip",
		["AirJump"] = "airjump",
		["Spider"] = "spider",
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
	["Interact"] = {
		["FastDig"] = "fastdig",
		["FastPlace"] = "fastplace",
		["AutoDig"] = "autodig",
		["AutoPlace"] = "autoplace",
		["InstantBreak"] = "instant_break",
		["FastHit"] = "spamclick",
		["AutoHit"] = "autohit",
	},
	["Exploit"] = {
		["EntitySpeed"] = "entity_speed",
	},
	["Player"] = {
		["NoFallDamage"] = "prevent_natural_damage",
		["NoForceRotate"] = "no_force_rotate",
		["Reach"] = "reach",
		["PointLiquids"] = "point_liquids",
		["PrivBypass"] = "priv_bypass",
		["AutoRespawn"] = "autorespawn",
		["ThroughWalls"] = "dont_point_nodes",
	},
}

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

	if def.setting and core.settings:get(def.setting) == nil then
		core.settings:set(def.setting, "false")
	end

	core.cheats[def.category] = core.cheats[def.category] or {}
	core.cheats[def.category][def.name] = def.setting or def.func

	return def
end
