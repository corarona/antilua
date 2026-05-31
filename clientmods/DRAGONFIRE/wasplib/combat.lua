function ws.aim(tpos)
	local ppos = minetest.localplayer:get_pos()
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
	minetest.localplayer:set_yaw(yyaw)
	minetest.localplayer:set_pitch(pitch)
end

function ws.gaim(tpos, v, g)
	if not tpos then return end
	local atan, pi, pow, sqrt = math.atan, math.pi, math.pow, math.sqrt
	local player = minetest.localplayer
	local ppos = player:get_pos()
	local vec = vector.subtract(ppos, tpos)

	local yaw = atan(vec.z / vec.x) - pi / 2
	yaw = yaw + (tpos.x >= ppos.x and pi or 0)
	player:set_yaw((yaw + pi) / pi * 180)

	local g = -9.81
	local y = vec.y
	vec.y = 0
	local x = vector.length(vec)

	local pitch = atan(pow(v, 2) / (g * x) + sqrt(pow(v, 4) / (pow(g, 2) * pow(x, 2)) - 2 * pow(v, 2) * y / (g * pow(x, 2)) - 1))
	player:set_pitch((pitch / pi * 180) * -1)
end

function ws.find_player(name)
	local lp = ws.dircoord(0, 0, 0)
	for k, v in ipairs(minetest.get_objects_inside_radius(lp, 500)) do
		if v:get_name() == name then
			return v:get_pos(), v
		end
	end
end

function ws.playeron(p)
	local pls = minetest.get_player_names()
	for k, v in pairs(pls) do
		if v == p then return true end
	end
	return false
end
