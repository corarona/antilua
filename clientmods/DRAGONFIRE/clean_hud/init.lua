if core.settings:get("clean_hud") == nil then
	core.settings:set("clean_hud", "false")
end

core.register_on_hud_add(function(hud_def)
	if not core.settings:get_bool("clean_hud") then
		return false
	end
	return true
end)

core.register_cheat("CleanHUD", { category = "Render", setting = "clean_hud" })
