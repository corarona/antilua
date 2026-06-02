local function checkprojectile(self)
	local range = tonumber(core.settings:get(self.setting .. ".scan_range")) or 4
	local pos = minetest.localplayer:get_pos()
	for k, v in ipairs(minetest.get_objects_inside_radius(pos, range)) do
		local tex = v:get_item_textures()
		if tex and (tex:sub(-9) == "arrow_box" or tex:sub(-7) == "_splash" or tex:sub(-17) == "shulkerbullet.png") then
			local vel = v:get_velocity()
			local trigger = tonumber(core.settings:get(self.setting .. ".trigger_distance")) or 4
			local dst = vector.distance(minetest.localplayer:get_pos(), v:get_pos())
			if dst > trigger then return false end
			if vel and vel.x == 0 and vel.y == 0 and vel.z == 0 then return false end
			return true
		end
	end
	return false
end

ws.rg("AutoEvade", {
	category = "Combat",
	setting = "autoevade",
	on_step = function(self, dtime)
		if checkprojectile(self) then
			local dist = tonumber(core.settings:get(self.setting .. ".evade_distance")) or 2
			local rndx = math.random(-dist, dist)
			local rndz = math.random(-dist, dist)
			minetest.localplayer:set_pos(ws.dircoord(rndx, 2, rndz))
		end
	end,
	daughters = {"headsaver"},
	cheat_settings = {
		scan_range = { type = "number", default = 4, min = 1, max = 20 },
		trigger_distance = { type = "number", default = 4, min = 1, max = 10 },
		evade_distance = { type = "number", default = 2, min = 1, max = 10 },
	},
})
