if core.settings:get("clean_hud") == nil then
	core.settings:set("clean_hud", "false")
end

core.register_on_hud_add(function(hud_def)
	if not core.settings:get_bool("clean_hud") then
		return false
	end
	return true
end)

core.register_cheat("CleanHUD", { category = "Render", setting = "clean_hud",
	description = "Hide HUD elements for a clean view" })

core.register_on_hud_flags_changed(function()
	if not core.settings:get_bool("hudlocker") then
		return
	end
	if core.settings:get_bool("hudlocker.notify_on_change", true) then
		ws.notify("Server changed HUD flags", ws.NOTIFY_INFO)
	end
end)

core.register_on_hud_param_changed(function(param, value)
	if not core.settings:get_bool("hudlocker") then
		return
	end
	if core.settings:get_bool("hudlocker.notify_on_change", true) then
		local param_names = { "hotbar_itemcount", "hotbar_image", "hotbar_selected_image" }
		local name = param_names[param] or "param_" .. param
		ws.notify("Server changed HUD param: " .. name, ws.NOTIFY_INFO)
	end
end)

core.register_cheat({ name = "HUDLocker", category = "Render",
	setting = "hudlocker",
	description = "Notify when server changes HUD flags/params",
	cheat_settings = {
		notify_on_change = { type = "bool", default = true },
	},
})