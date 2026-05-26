ws.rg("AutoCombatLog","Bots","autoclog",function()
	local ln = minetest.localplayer:get_name()
	for _,pl in pairs(minetest.get_nearby_objects(270)) do
		if pl:is_player() and not pl:is_local_player() then
			--if table.indexof(nlist.get("friends"),pl:get_name() or pl:get_properties().nametag) == -1 then
				local pos = minetest.localplayer:get_pos()
				minetest.localplayer:set_pos(vector.new(pos.x+math.random(-2,2),pos.y+math.random(-4,35),pos.z+math.random(-2,2)))
				minetest.log("CLOGGED:"..pl:get_name() or pl:get_properties().nametag)
				minetest.disconnect()
			--end
		end
	end
end)
