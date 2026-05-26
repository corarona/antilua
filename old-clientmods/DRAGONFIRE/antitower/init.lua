local function find_nodes_near_buildable_to(pos, dst, nodes, dir)
	local nn = minetest.find_nodes_near(pos, 4, nodes, false)
	local r = {}
	for k, v in pairs(nn) do
		local n = minetest.get_node_or_nil(vector.offset(v, 0, dir, 0))
		if n and n.name then
			local def = minetest.registered_nodes[n.name]
			if (def and def.buildable_to) or n.name == "air" then
				table.insert(r, v)
			end
		end
	end
	return r
end

ws.rg('AntiTower', 'Scaffold', 'anti_tower', function()
	local it = minetest.localplayer:get_wielded_item():get_name()
	local lp = ws.dircoord(0, 0, 0)
	local nds = find_nodes_near_buildable_to(lp, 4, {it}, -1)
	for k, v in ipairs(nds) do
		ws.place(vector.add(v, vector.new(0, -1, 0)), it)
	end
end, function() end, function() end, {'autorefill'})

ws.rg('ATower', 'Scaffold', 'atower', function()
	local it = minetest.localplayer:get_wielded_item():get_name()
	local lp = ws.dircoord(0, 0, 0)
	local nds = find_nodes_near_buildable_to(lp, 4, {it}, 1)
	for k, v in ipairs(nds) do
		ws.place(vector.add(v, vector.new(0, 1, 0)), it)
	end
end, function() end, function() end, {'autorefill'})
