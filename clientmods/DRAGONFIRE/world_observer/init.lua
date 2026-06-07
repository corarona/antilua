if core.settings:get("world_observer") == nil then
	core.settings:set("world_observer", "false")
end

core.register_on_node_add(function(pos, node)
	if not core.settings:get_bool("world_observer") then
		return
	end
	ws.notify("Node placed at " .. core.pos_to_string(pos), ws.NOTIFY_INFO, {toast = false})
end)

core.register_on_node_remove(function(pos)
	if not core.settings:get_bool("world_observer") then
		return
	end
	ws.notify("Node removed at " .. core.pos_to_string(pos), ws.NOTIFY_INFO, {toast = false})
end)

core.register_cheat("WorldObserver", { category = "Render", setting = "world_observer" })
