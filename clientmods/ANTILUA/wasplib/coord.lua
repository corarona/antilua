function ws.ordercoord(c)
	if c.x == nil then
		return {x = c[1], y = c[2], z = c[3]}
	else
		return c
	end
end

function ws.optcoord(x, y, z)
	if y and z then
		return vector.new(x, y, z)
	else
		return ws.ordercoord(x)
	end
end

function ws.relcoord(x, y, z, rpos)
	local pos = rpos or core.localplayer:get_pos()
	return vector.add(vector.new(pos.x, math.ceil(pos.y), pos.z), ws.optcoord(x, y, z))
end

function ws.getdir(yaw)
	if not core.localplayer then return "north" end
	local rot = yaw or core.localplayer:get_yaw() % 360
	if ws.between(rot, 315, 359) or ws.between(rot, 0, 44) then
		return "north"
	elseif ws.between(rot, 45, 134) then
		return "west"
	elseif ws.between(rot, 135, 224) then
		return "south"
	elseif ws.between(rot, 225, 314) then
		return "east"
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
