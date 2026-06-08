-- Event logger: merged from entity_logger, world_observer, breath_alert, movement_display

--
-- Entity logger
--

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

--
-- World observer
--

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

--
-- Breath alert
--

core.register_on_breath_changed(function(breath)
	if not core.settings:get_bool("breath_alert") then
		return
	end
	if breath < 5 then
		ws.notify("Running out of breath! (" .. breath .. ")", ws.NOTIFY_WARNING)
	end
end)

core.register_cheat("BreathAlert", { category = "Player", setting = "breath_alert" })

--
-- Movement display
--

core.register_on_recieve_physics_override(function(movement)
	if not core.settings:get_bool("movement_display") then
		return
	end
	core.display_chat_message(string.format(
		"Movement: walk=%.1f jump=%.1f gravity=%.1f climb=%.1f",
		movement.speed_walk, movement.speed_jump,
		movement.gravity, movement.speed_climb))
end)

core.register_cheat("MovementDisplay", { category = "Render", setting = "movement_display" })
