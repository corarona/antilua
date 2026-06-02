autofly={}
autofly.landing_distance=15
autofly.tpos=nil
autofly.atpos=nil

local max_speed = vector.new(4,26,4)

ws.rg('Fly3d', {
	category = 'Movement',
	setting = 'afly3d',
	on_step = function()
		if not poi.last_pos then return end
		local lp=ws.dircoord(0,0,0)
		local dst=vector.distance(lp,poi.last_pos)
		poi.set_hud_info("Fly3d")
		if dst > autofly.landing_distance and minetest.settings:get_bool("continuous_forward", false) then
			ws.aim(autofly.tpos)
		else
			minetest.settings:set_bool('afly3d',false)
		end
	end,
	on_start = function()
		if not poi.last_pos or not poi.last_name then
			return false, 'Select a poi first.'
		end
		autofly.tpos=table.copy(poi.last_pos)
		poi.set_hud_info("Fly3D")
		poi.display(autofly.tpos,poi.last_name )
	end,
	daughters = {'continuous_forward',"pitch_move"},
})

ws.rg('Mv3d', {
	category = 'Movement',
	setting = 'aflymv3d',
	on_step = function()
		if not poi.last_pos then return end
		local lp=ws.dircoord(0,0,0)
		local dir = vector.direction(lp,poi.last_pos)
		minetest.localplayer:set_velocity(vector.multiply(dir, ( minetest.localplayer:get_movement_speed().walk / 10 )))
		local dst=vector.distance(lp,poi.last_pos)
		poi.set_hud_info("Mv3d")
		if dst > autofly.landing_distance and minetest.settings:get_bool("continuous_forward", false) then
			--ws.aim(autofly.tpos)
		else
			minetest.settings:set_bool('afly3d',false)
		end
	end,
	on_start = function()
		if not poi.last_pos or not poi.last_name then
			return false, 'Select a poi first.'
		end
		autofly.tpos=table.copy(poi.last_pos)
		poi.set_hud_info("Fly3D")
		poi.display(autofly.tpos,poi.last_name )
		minetest.localplayer:set_physics_override({
			gravity = 0,
		})
	end,
	on_stop = function()
		minetest.localplayer:set_physics_override({
			gravity = 1,
		})
	end,
})


ws.rg('Fly2d', {
	category = 'Movement',
	setting = 'afly2d',
	on_step = function()
		if not poi.last_pos then return end
		autofly.tpos=poi.last_pos
		local lp=ws.dircoord(0,0,0)
		local dst=vector.distance(lp,autofly.tpos)
		poi.set_hud_info("Fly2D")
		if dst > autofly.landing_distance and minetest.settings:get_bool("continuous_forward",false) then
			ws.aim(autofly.tpos)
		elseif dst <= autofly.landing_distance then
			return true
		end
	end,
	on_start = function()
		if not poi.last_pos or not poi.last_name then
			return false, 'Select a poi first.'
		end
		poi.set_hud_info("Fly2d")
		local lp=ws.dircoord(0,0,0)
		autofly.tpos=vector.new(poi.last_pos.x,lp.y,poi.last_pos.z)
		autofly.atpos=table.copy(poi.last_pos)
		autofly.name=poi.last_name
		minetest.settings:set_bool('continuous_forward',true)
		local tdst=vector.distance(autofly.tpos,poi.last_pos)
		local above_or_below = "above"
		if autofly.tpos.y < poi.last_pos.y then
			above_or_below = "below"
		end
		poi.display(autofly.tpos,"Target " .. tdst .. "m "..above_or_below .." actual target '"..poi.last_name.."'")
	end,
	on_stop = function()
		poi.display(autofly.atpos,autofly.name)
		ws.aim(autofly.atpos)
	end,
	daughters = {'continuous_forward'},
})

ws.rg('FlyNRoof', {
	category = 'Movement',
	setting = 'aflynroof',
	on_step = function()
		if not poi.last_pos then return end
		local lp=ws.dircoord(0,0,0)
		local dst=vector.distance(lp,autofly.tpos)
		if dst > autofly.landing_distance and minetest.settings:get_bool("continuous_forward",false) then
			ws.aim(autofly.tpos)
			autofly.set_info(dst)
		else
			minetest.settings:set_bool('continuous_forward',false)
			minetest.settings:set_bool('alfynroof',false)
		end
	end,
	on_start = function()
		if not poi.last_pos or not poi.last_name then
			return false, 'Select a poi first.'
		end
		local lp = ws.dircoord(0,0,0)
		poi.set_hud_info("FlyNether")
		minetest.settings:set_bool('continuous_forward',true)
		autofly.tpos=vector.new(poi.last_pos.x / 8,lp.y,poi.last_pos.z / 8)
		poi.display(autofly.tpos,'Target for portal.')
	end,
	daughters = {'continuous_forward'},
})

function autofly.warp(name)
	local pos=autofly.get_waypoint(name)
	if pos then
		if ws.get_dimension(pos) == "void" then return false end
		minetest.localplayer:set_pos(pos)
		return true
	end
end

local function go_to(pos,name,method)
	poi.last_pos=pos
	poi.last_name=name
	minetest.settings:set_bool(method,true)
end

poi.register_transport('Fly3D',function(pos,name) go_to(pos,name,'afly3d') end)
poi.register_transport('Mv3D',function(pos,name) go_to(pos,name,'aflymv3d') end)
poi.register_transport('Fly2D',function(pos,name) go_to(pos,name,'afly2d') end)
poi.register_transport('Nroof',function(pos,name) go_to(pos,name,'aflynroof') end)
