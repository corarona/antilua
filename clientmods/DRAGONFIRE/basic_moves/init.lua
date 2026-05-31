local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
dofile(modpath .. "/autofly.lua")
dofile(modpath .. "/flight_hud.lua")


local nether_rings = {
	166,
	420,
	1337,
	2666,
	3860,
}

local function nearest_portal(pos)
	if pos.y > 27000 then

	end
end

poi.register_transport('CTP',function(pos,name)
	minetest.localplayer:set_pos(pos)
end)

poi.register_transport('STP',function(pos,name)
	minetest.send_chat_message("/teleport "..pos.x..","..pos.y..","..pos.z)
end)

ws.rg("AutoFsprint","Movement","autoforwardsprint",function()
	if minetest.settings:get_bool("continuous_forward") then
		core.set_keypress("special1", true)
	end
end,function() end,function()
		core.set_keypress("special1", false)
end)

ws.rg("AxisSnap","Player","axissnap",function()
	local y=minetest.localplayer:get_yaw()
	local yy
	if ( y < 45 or y > 315 ) then
	    yy=0
	elseif (y < 135) then
	    yy=90
	elseif (y < 225 ) then
	    yy=180
	else
	    yy=270
	end
	minetest.localplayer:set_yaw(yy)
end)
