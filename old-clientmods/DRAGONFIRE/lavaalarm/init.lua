ws.rg("LavaAlarm", {
	category = "Player",
	setting = "lavaalarm",
	on_step = function(self, dtime)
		local lava = {"mcl_core:lava_source","mcl_core:lava_flowing","mcl_nether:nether_lava_source","mcl_nether:nether_lava_flowing"}
		local range = tonumber(core.settings:get(self.setting .. ".detect_range")) or 3
		if minetest.find_node_near(ws.dircoord(0,0,0), range, lava) then
			minetest.sound_play("mcl_bells_bell_stroke", { pitch = 1.5, gain = 1.5})
		end
	end,
	cheat_settings = {
		detect_range = { type = "number", default = 3, min = 1, max = 20 },
	},
})

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

core.register_cheat("mcl2-invul", { category = "Player", setting = "mcl2-invul" })

minetest.register_chatcommand("mcl2_invul",{
	func = function()
		minetest.send_damage(1)
		minetest.disconnect()
	end,
})
