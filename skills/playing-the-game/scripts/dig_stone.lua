-- Find nearest stone and dig it
local pos = core.localplayer:get_pos()
local stone = core.find_node_near(pos, 20, "mcl_core:stone")
if stone then
	-- Move close to it
	core.localplayer:set_pos({x = stone.x, y = stone.y + 2, z = stone.z})
	-- Dig the stone
	local dug = 0
	for i = 1, 5 do
		core.dig_node(stone)
		dug = dug + 1
	end
	-- Move around to pick up drops
	core.localplayer:set_pos({x = stone.x, y = stone.y + 1, z = stone.z})
	return "dug " .. dug .. " stone at " .. dump(stone)
else
	return "no stone found near " .. dump(pos)
end
