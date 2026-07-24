ws.hud_waypoints = {}

function ws.hud_waypoint(name, pos, color, text)
	if not core.localplayer then return end
	color = color or 0xFF0000
	text = text or name
	local id = ws.hud_waypoints[name]
	if id then
		core.localplayer:hud_change(id, "name", name)
		core.localplayer:hud_change(id, "world_pos", pos)
		core.localplayer:hud_change(id, "number", color)
		return id
	end
	id = core.localplayer:hud_add({
		type = "waypoint",
		name = name,
		text = text,
		number = color,
		world_pos = pos,
	})
	ws.hud_waypoints[name] = id
	return id
end

function ws.hud_remove_waypoint(name)
	if not core.localplayer then return end
	local id = ws.hud_waypoints[name]
	if id then
		core.localplayer:hud_remove(id)
		ws.hud_waypoints[name] = nil
		return true
	end
end

function ws.clear_waypoints()
	if not core.localplayer then
		ws.hud_waypoints = {}
		return
	end
	for name, id in pairs(ws.hud_waypoints) do
		core.localplayer:hud_remove(id)
	end
	ws.hud_waypoints = {}
end

function ws.display_wp(pos, name)
	if not core.localplayer then return end
	local ix = #ws.displayed_wps + 1
	ws.displayed_wps[ix] = core.localplayer:hud_add({
		type = "waypoint",
		name = name,
		text = name,
		number = 0x00ff00,
		world_pos = pos,
	})
	return ix
end

function ws.clear_wp(ix)
	if not core.localplayer then return end
	core.localplayer:hud_remove(ws.displayed_wps[ix])
	table.remove(ws.displayed_wps, ix)
end

function ws.clear_wps()
	if not core.localplayer then
		ws.displayed_wps = {}
		return
	end
	for k = #ws.displayed_wps, 1, -1 do
		core.localplayer:hud_remove(ws.displayed_wps[k])
		ws.displayed_wps[k] = nil
	end
end