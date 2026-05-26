ws.rg('HeadSaver', 'Player', 'headsaver', function()
	local head = ws.dircoord(0, 1, 0)
	local headnd = minetest.get_node_or_nil(head)
	if headnd and headnd.name ~= 'air' then
		local ap = ws.find_closest_reachable_airpocket(ws.dircoord(0, 0, 0))
		if ap then
			minetest.localplayer:set_pos(ap)
			return
		end
		ws.dig(head)
	end
end)
