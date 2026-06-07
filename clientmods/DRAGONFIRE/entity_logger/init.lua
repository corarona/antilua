if core.settings:get("entity_logger") == nil then
	core.settings:set("entity_logger", "false")
end

core.register_on_object_add(function(id)
	if not core.settings:get_bool("entity_logger") then
		return
	end
	ws.notify("Entity appeared, id=" .. id, ws.NOTIFY_INFO, {toast = false})
end)

core.register_on_object_hp_change(function(id, hp)
	if not core.settings:get_bool("entity_logger") then
		return
	end
	ws.notify("Entity " .. id .. " HP changed to " .. hp, ws.NOTIFY_INFO, {toast = false})
end)

core.register_cheat("EntityLogger", { category = "Render", setting = "entity_logger" })
