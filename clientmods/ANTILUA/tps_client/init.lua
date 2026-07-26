tps_client = {}
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
			local tr = ws.hud_anchor("top_right", -10, 10)
			hud = core.localplayer:hud_add({
				type = "text",
				position = tr.position,
				alignment = tr.alignment,
				offset = tr.offset,
				text = message,
				number = 0xFFFFFF,
			})
			tr.offset.x = tr.offset.x - 25
			ping_hud = core.localplayer:hud_add({
				type = "text",
				position = tr.position,
				alignment = tr.alignment,
				offset = tr.offset,
				text = "0",
				number = 0xFFF800,
			})
		end
	end
end)

core.register_globalstep(function(dtime)
	if tps_client.ping then
		tps_client.ping = tps_client.ping + dtime
		if ping_hud and core.localplayer then
			core.localplayer:hud_change(ping_hud, "text", tostring(math.floor(tps_client.ping * 1000)))
		end
	end
end)