sbots.register_bot("spongedigger",{
	landing_distance = 1,
	find_pos = function(self,pos)
		local nds = minetest.find_nodes_near(pos,60,{"mcl_sponges:sponge","mcl_sponges:sponge_wet"})
		if not nds or #nds == 0 then return end
		table.sort(nds,function(a, b) return vector.distance(pos,a) < vector.distance(pos,b) end)
		return nds[1]
	end,
	do_pos = function(self,pos)
		local nn=minetest.find_nodes_near(pos,1,{"mcl_sponges:sponge","mcl_sponges:sponge_wet"},true)
		if not nn or #nn == 0 then return true end
		for _,v in pairs(nn) do minetest.dig_node(v) end
	end,
})

ws.register_bot = sbots.register_bot

ws.register_bot("fwaterbot",{
	find_pos = function(self,pos)
		local nds
		if self.target_pos then
			nds = minetest.find_nodes_in_area(vector.offset(pos,0,4,0),vector.offset(pos,0,-100,0),{"mcl_core:water_flowing"})
		end
		if not nds then
			nds = minetest.find_nodes_near(pos,50,{"mcl_core:water_flowing"})
		end
		table.sort(nds,function(a, b) return a.y > b.y end)
		for _,v in ipairs(nds) do
			local tn = minetest.get_node_or_nil(vector.offset(v,0,1,0))
			if tn and tn.name == "air" then return v end
			--and vector.distance(self.orig_pos,v) < 250 then return v end
		end
	end,
	do_pos = function(self,pos)
		local tn = minetest.get_node_or_nil(pos)
		if tn and tn.name == "air" then return true end
	end,
})


local pos_from_chat

ws.register_bot("ftlbot",{
	moving_target = true,
	stand_waiting = true,
	find_pos = function(self,pos)
		if pos_from_chat and self.target_pos and not vector.equals(self.target_pos,pos_from_chat) then
			return pos_from_chat
		end
	end,
	do_pos = function(self,pos)	return end,
})

local mtgminer_tgt
