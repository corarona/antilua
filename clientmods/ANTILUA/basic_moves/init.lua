local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)
dofile(modpath .. "/autofly.lua")
dofile(modpath .. "/flight_hud.lua")

poi.register_transport("CTP", function(pos, _)
	if not pos then return true end
	core.localplayer:set_pos(pos)
end, "Teleport (Client)")

poi.register_transport("STP", function(pos, _)
	if not pos then return true end
	core.send_chat_message("/teleport " .. pos.x .. "," .. pos.y .. "," .. pos.z)
end, "Teleport (Server)")

ws.rg("AutoFsprint", {
	category = "Movement",
	setting = "autoforwardsprint",
	description = "Auto-forward with sprint",
	on_step = function()
		if core.settings:get_bool("continuous_forward") then
			core.set_keypress("special1", true)
		end
	end,
	on_stop = function()
		core.set_keypress("special1", false)
	end,
})

ws.rg("AxisSnap", {
	category = "Player",
	setting = "axissnap",
	description = "Snap movement to cardinal axes",
	on_step = function()
		-- Autopilot aims the camera itself; don't fight it.
		if core.settings:get_bool("autopilot") then return end
		local yaw = core.localplayer:get_yaw()
		local snapped = math.floor((yaw + 45) / 90) % 4 * 90
		core.localplayer:set_yaw(snapped)
	end,
})
