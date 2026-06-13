if core.settings:get("always_day") == nil then
	core.settings:set("always_day", "false")
end

core.register_on_time_of_day(function(time, speed)
	if not core.settings:get_bool("always_day") then
		return nil
	end
	return 12000
end)

core.register_cheat("AlwaysDay", { category = "Render", setting = "always_day",
	description = "Always show daytime lighting" })
