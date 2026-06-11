tps_client = {
	ping_tolerance = 0.5,
	tps_tolerance = 10
}
local ch = core.mod_channel_join("tps")
core.after(5, function()
	if ch and ch:is_writeable() then
		ch:send_all("init")
	end
end)

local hud, ping_hud

core.register_on_modchannel_message(function(channel_name, sender, message)
	if sender == "" and channel_name == "tps" and core.localplayer then
		tps_client.tps = tonumber(message)
		tps_client.ping = 0
		if hud then
			core.localplayer:hud_change(hud, "text", message)
		else
			hud = core.localplayer:hud_add({
				type = "text",
				position = {x = 1, y = 1},
				alignment = {x = -1, y = -1},
				offset = {x = -25, y = -25},
				text = message,
				number = 0xFFFFFF,
			})
			ping_hud = core.localplayer:hud_add({
				type = "text",
				position = {x = 1, y = 1},
				alignment = {x = -1, y = -1},
				offset = {x = -50, y = -25},
				text = "0",
				number = 0xFFF800,
			})
		end
	end
end)

core.register_globalstep(function(dtime)
	if tps_client.ping then
		tps_client.ping = tps_client.ping + dtime
		if tps_client.ping_hud then
			core.localplayer:hud_change(ping_hud, "text", tostring(math.floor(tps_client.ping * 1000)))
		end
		local ping_ms = math.max(tps_client.ping * 1000, 1)
		tps_client.tps = math.floor(tps_client.tps / math.ceil(ping_ms))
		if tps_client.ping > 1000 and hud then
			core.localplayer:hud_change(hud, "text", tostring(tps_client.tps))
		end
	end
end)

core.register_chatcommand("tps_set_ping_tolerance", { func = function(param)
	local n = tonumber(param)
	if n then
		tps_client.ping_tolerance = n
	end
end })

core.register_chatcommand("tps_set_tps_tolerance", { func = function(param)
	local n = tonumber(param)
	if n then
		tps_client.tps_tolerance = n
	end
end })
