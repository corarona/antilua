ws.rg("AutoCombatLog", { category = "Player", setting = "autoclog",
	on_step = function(self)
		local range = tonumber(core.settings:get(self.setting .. ".detect_range")) or 270
		for _, pl in pairs(minetest.get_nearby_objects(range)) do
			if pl:is_player() and not pl:is_local_player() then
				local pos = minetest.localplayer:get_pos()
				minetest.localplayer:set_pos(vector.new(
					pos.x + math.random(-2, 2),
					pos.y + math.random(-4, 35),
					pos.z + math.random(-2, 2)))
				minetest.log("CLOGGED:" .. pl:get_name())
				minetest.disconnect()
			end
		end
	end,
	cheat_settings = {
		detect_range = { type = "number", default = 270, min = 10, max = 500 },
	},
})
