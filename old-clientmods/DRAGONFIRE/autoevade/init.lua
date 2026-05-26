local karange = 4

local function checkprojectile()
	for k, v in ipairs(minetest.localplayer:get_nearby_objects(karange)) do
		local tex = v:get_item_textures()
		if tex and (tex:sub(-9) == "arrow_box" or tex:sub(-7) == "_splash" or tex:sub(-17) == "shulkerbullet.png") then
			local vel = v:get_velocity()
			local dst = vector.distance(minetest.localplayer:get_pos(), v:get_pos())
			if dst > 4 then return false end
			if vel and vel.x == 0 and vel.y == 0 and vel.z == 0 then return false end
			return true
		end
	end
	return false
end

ws.rg("AutoEvade", "Combat", "autoevade", function()
	if checkprojectile() then
		local rndx = math.random(-2, 2)
		local rndz = math.random(-2, 2)
		minetest.localplayer:set_pos(ws.dircoord(rndx, 2, rndz))
	end
end, function() end, function() end, {'headsaver'})
