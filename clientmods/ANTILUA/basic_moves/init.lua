local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)
dofile(modpath .. "/autofly.lua")
dofile(modpath .. "/flight_hud.lua")

poi.register_transport('CTP',function(pos,name)
	core.localplayer:set_pos(pos)
end)

poi.register_transport('STP',function(pos,name)
	core.send_chat_message("/teleport "..pos.x..","..pos.y..","..pos.z)
end)

ws.rg("AutoFsprint","Movement","autoforwardsprint",function()
	if core.settings:get_bool("continuous_forward") then
		core.set_keypress("special1", true)
	end
end,function() end,function()
		core.set_keypress("special1", false)
end)

ws.rg("AxisSnap","Player","axissnap",function()
	local y=core.localplayer:get_yaw()
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
	core.localplayer:set_yaw(yy)
end)
