local greenup_node = "mcl_core:dirt_with_grass"
ws.rg("PlaceOn","Placers","placeon",function()
	local pos = ws.dircoord(0,0,0)
	local poss = minetest.find_nodes_near_under_air_except(pos, 4, {greenup_node})
	for _,v in pairs(poss) do
		ws.place(vector.offset(v,0,1,0),greenup_node)
	end
end,function()
	greenup_node = minetest.localplayer:get_wielded_item():get_name()
end)

local torch = "mcl_torches:torch"
ws.rg("TorchUp","Placers","torchup",function()
	local pos = ws.dircoord(0,0,0)
	local poss = minetest.find_nodes_near_under_air_except(pos, 4, {torch})
	for _,v in pairs(poss) do
		local ab = vector.offset(v,0,1,0)
		local li = minetest.get_node_light(ab,0.0)
		if li and li < 8 then
			ws.place(ab,torch)
		end
	end
end)
