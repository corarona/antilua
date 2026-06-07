if core.settings:get("movement_display") == nil then
	core.settings:set("movement_display", "false")
end

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
