if core.settings:get("breath_alert") == nil then
	core.settings:set("breath_alert", "false")
end

core.register_on_breath_changed(function(breath)
	if not core.settings:get_bool("breath_alert") then
		return
	end
	if breath < 5 then
		ws.notify("Running out of breath! (" .. breath .. ")", ws.NOTIFY_WARNING)
	end
end)

core.register_cheat("BreathAlert", { category = "Player", setting = "breath_alert" })
