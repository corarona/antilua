function ws.coord(x, y, z)
	return vector.new(x, y, z)
end

function ws.ordercoord(c)
	if c.x == nil then
		return {x = c[1], y = c[2], z = c[3]}
	else
		return c
	end
end

function ws.optcoord(x, y, z)
	if y and z then
		return ws.coord(x, y, z)
	else
		return ws.ordercoord(x)
	end
end

function ws.cadd(c1, c2)
	return vector.add(c1, c2)
end

function ws.relcoord(x, y, z, rpos)
	local pos = rpos or core.localplayer:get_pos()
	pos.y = math.ceil(pos.y)
	return vector.add(pos, ws.optcoord(x, y, z))
end

function ws.is_same_pos(pos1, pos2)
	return vector.distance(vector.round(pos1), vector.round(pos2)) == 0
end

function ws.get_reachable_positions(range, under)
	under = under or false
	range = range or 4
	local rt = {}
	local lp = vector.round(core.localplayer:get_pos())
	local ylim = range
	if under then ylim = -1 end
	for x = -range, range do
		for y = -range, ylim do
			for z = -range, range do
				table.insert(rt, vector.offset(lp, x, y, z))
			end
		end
	end
	return rt
end

function ws.getaxis()
	local dir = ws.getdir()
	if dir == "north" or dir == "south" then return "z" end
	return "x"
end

function ws.setdir(dir)
	if dir == "north" then
		core.localplayer:set_yaw(0)
	elseif dir == "south" then
		core.localplayer:set_yaw(180)
	elseif dir == "east" then
		core.localplayer:set_yaw(270)
	elseif dir == "west" then
		core.localplayer:set_yaw(90)
	end
end

function ws.getdir(yaw)
	if not core.localplayer then return "north" end
	local rot = yaw or core.localplayer:get_yaw() % 360
	if ws.between(rot, 316, 360) or ws.between(rot, 0, 45) then
		return "north"
	elseif ws.between(rot, 136, 225) then
		return "south"
	elseif ws.between(rot, 226, 315) then
		return "east"
	elseif ws.between(rot, 46, 135) then
		return "west"
	end
end

function ws.dircoord(f, y, r, rpos, rdir)
	if not core.localplayer then return vector.new() end
	local dir = ws.getdir(rdir)
	local coord = ws.optcoord(f, y, r)
	local f = coord.x
	local y = coord.y
	local r = coord.z
	local lp = rpos or core.localplayer:get_pos()
	if dir == "north" then
		return ws.relcoord(r, y, f, rpos)
	elseif dir == "south" then
		return ws.relcoord(-r, y, -f, rpos)
	elseif dir == "east" then
		return ws.relcoord(f, y, -r, rpos)
	elseif dir == "west" then
		return ws.relcoord(-f, y, r, rpos)
	end
	return ws.relcoord(0, 0, 0, rpos)
end

function ws.get_dimension(pos)
	if pos.y > -65 then return "overworld"
	elseif pos.y > -8000 then return "void"
	elseif pos.y > -27000 then return "end"
	elseif pos.y > -28930 then return "void"
	elseif pos.y > -31000 then return "nether"
	else return "void"
	end
end
