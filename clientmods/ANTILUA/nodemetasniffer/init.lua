-- NodeMetaSniffer: detect and report nodemetadata changes

core.register_on_nodemetadata_change(function(positions)
	if not core.settings:get_bool("nodemetasniffer") then
		return
	end
	local range = tonumber(core.settings:get("nodemetasniffer.range")) or 50
	local notify = core.settings:get("nodemetasniffer.notify") or "toast"
	local player_pos = core.localplayer:get_pos()
	if not player_pos then
		return
	end
	for _, pos in ipairs(positions) do
		local dist = vector.distance(player_pos, pos)
		if dist <= range then
			local msg = "Nodemetadata changed at " .. core.pos_to_string(pos)
			if notify == "toast" or notify == "both" then
				ws.notify(msg, ws.NOTIFY_INFO)
			end
			if notify == "chat" or notify == "both" then
				core.display_chat_message(msg)
			end
		end
	end
end)

core.register_cheat({ name = "NodeMetaSniffer", category = "Info",
	setting = "nodemetasniffer",
	description = "Detect and report nodemetadata changes in range",
	cheat_settings = {
		range = { type = "number", default = 50, min = 5, max = 500 },
		notify = { type = "enum", values = {"toast", "chat", "both"}, default = "toast" },
	},
})
