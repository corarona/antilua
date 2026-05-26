local lava = {"mcl_core:lava_source","mcl_core:lava_flowing","mcl_nether:nether_lava_source","mcl_nether:nether_lava_flowing"}
ws.rg("LavaAlarm","Player","lavaalarm",function()
	if minetest.find_node_near(ws.dircoord(0,0,0),3,lava) then
		minetest.sound_play("mcl_bells_bell_stroke", { pitch = 1.5, gain = 1.5})
	end
end)

local t = 0.5
minetest.register_globalstep(function(dtime)
	local player = minetest.localplayer
	if not player then return end
	if minetest.settings:get_bool("mcl2-invul") then
		if t <= 0 then
			minetest.send_damage(1)
			t = 0.5
		end
		t = t - dtime
	end
end)

minetest.register_cheat("mcl2-invul", "Player", "mcl2-invul")

minetest.register_chatcommand("mcl2_invul",{
	func = function()
		minetest.send_damage(1)
		minetest.disconnect()
	end,
})
