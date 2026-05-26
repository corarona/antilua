local lockview_pitch = nil
local lockview_yaw = nil

ws.rg("LockView", "Bots", "lockview", function()
	if lockview_pitch and lockview_yaw then
		core.localplayer:set_yaw(lockview_yaw)
		core.localplayer:set_pitch(lockview_pitch)
	end
end, function()
	lockview_pitch = core.localplayer:get_pitch() * -1
	lockview_yaw = core.localplayer:get_yaw()
end, function()
	lockview_pitch = nil
	lockview_yaw = nil
end)
