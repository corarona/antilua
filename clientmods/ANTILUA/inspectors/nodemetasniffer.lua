-- NodeMetaSniffer: detect and report nodemetadata changes

local prev_meta = {}
local meta_debounce = {}

core.register_on_nodemetadata_change(function(changes)
	if not core.settings:get_bool("nodemetasniffer") then
		return
	end
	local range = tonumber(core.settings:get("nodemetasniffer.range")) or 50
	local notify = core.settings:get("nodemetasniffer.notify") or "toast"
	local player_pos = core.localplayer:get_pos()
	if not player_pos then
		return
	end
	local now = os.time()
	for _, change in ipairs(changes) do
		local pos = change.pos
		local pos_key = core.pos_to_string(pos)
		local last = meta_debounce[pos_key] or 0
		if now - last >= 1 then
		meta_debounce[pos_key] = now
		local dist = vector.distance(player_pos, pos)
		if dist <= range then
			local diffs = {}
			for key, new_val in pairs(change.new) do
				local old_val = (change.old or {})[key]
				if old_val ~= new_val then
					local old_short = old_val and #old_val > 40 and old_val:sub(1, 40) .. "..." or old_val or "(none)"
					local new_short = #new_val > 40 and new_val:sub(1, 40) .. "..." or new_val
					diffs[#diffs + 1] = key .. ": " .. old_short .. " -> " .. new_short
				end
			end
			for key, old_val in pairs(change.old or {}) do
				if change.new[key] == nil then
					local old_short = #old_val > 40 and old_val:sub(1, 40) .. "..." or old_val
					diffs[#diffs + 1] = key .. ": " .. old_short .. " -> (removed)"
				end
			end
			if #diffs > 0 then
				local msg = "Meta at " .. pos_key .. ": " .. table.concat(diffs, "; ")
				if notify == "chat" or notify == "both" then
					core.display_chat_message(msg)
				end
				if notify ~= "off" then
					ws.notify(msg, ws.NOTIFY_INFO, {chat = false})
				end
			end
		end
		end
	end
	-- Clean stale debounce entries
	for k in pairs(meta_debounce) do
		if now - meta_debounce[k] > 10 then
			meta_debounce[k] = nil
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
