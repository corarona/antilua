tps_client = {}
local ch = core.mod_channel_join("tps")
core.after(5, function()
	if ch and ch:is_writeable() then
		ch:send_all("init")
	end
end)

local hud, ping_hud, cur_y

-- Re-reserve the shared top-right HUD slot and apply any y offset change.
local function apply_layout()
	if not core.localplayer then return end
	local slot = ws.hud_layout.reserve("tps_client", "top_right", 1)
	if hud and slot.y ~= cur_y then
		cur_y = slot.y
		core.localplayer:hud_change(hud, "offset", { x = -10, y = cur_y })
		core.localplayer:hud_change(ping_hud, "offset", { x = -35, y = cur_y })
	end
	return slot
end

core.register_on_modchannel_message(function(channel_name, sender, message)
	if sender == "" and channel_name == "tps" and core.localplayer then
		tps_client.tps = tonumber(message)
		tps_client.ping = 0
		if hud then
			core.localplayer:hud_change(hud, "text", message)
			apply_layout()
		else
			local slot = apply_layout()
			cur_y = slot.y
			hud = core.localplayer:hud_add({
				type = "text",
				position = slot.position,
				alignment = slot.alignment,
				offset = { x = -10, y = cur_y },
				text = message,
				number = 0xFFFFFF,
			})
			ping_hud = core.localplayer:hud_add({
				type = "text",
				position = slot.position,
				alignment = slot.alignment,
				offset = { x = -35, y = cur_y },
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
		-- Keep the slot in sync if widgets above/below resize
		apply_layout()
	end
end)
