function ws.get_hud_by_texture(texture)
	local def
	local i = -1
	repeat
		i = i + 1
		def = core.localplayer:hud_get(i)
	until not def or def.text:find(texture)
	if def then
		return def
	end
	return nil
end

function ws.display_wp(pos, name)
	local ix = #ws.displayed_wps + 1
	ws.displayed_wps[ix] = core.localplayer:hud_add({
		type = 'waypoint',
		name = name,
		text = name,
		number = 0x00ff00,
		world_pos = pos
	})
	return ix
end

function ws.clear_wp(ix)
	core.localplayer:hud_remove(ws.displayed_wps[ix])
	table.remove(ws.displayed_wps, ix)
end

function ws.clear_wps()
	for k, v in ipairs(ws.displayed_wps) do
		core.localplayer:hud_remove(v)
		table.remove(ws.displayed_wps, k)
	end
end
