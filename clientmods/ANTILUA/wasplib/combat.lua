function ws.aim(tpos)
	local ppos = core.localplayer:get_pos()
	local dir = vector.direction(ppos, tpos)
	local yyaw = 0
	local pitch = 0
	if dir.x < 0 then
		yyaw = math.atan2(-dir.x, dir.z) + (math.pi * 2)
	else
		yyaw = math.atan2(-dir.x, dir.z)
	end
	yyaw = ws.round2(math.deg(yyaw), 2)
	pitch = ws.round2(math.deg(math.asin(-dir.y) * 1), 2)
	core.localplayer:set_yaw(yyaw)
	core.localplayer:set_pitch(pitch)
end

