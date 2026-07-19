local log_path

core.register_on_connect(function()
	if not core.settings:get_bool("chat_logging", false) then
		log_path = nil
		return
	end
	log_path = core.get_serverdata_path() .. "/chat.log"
	local ts = os.date("%Y-%m-%d %H:%M:%S")
	core.append_file(log_path, "\n--- Session started " .. ts .. " ---\n")
end)

core.register_on_disconnect(function()
	log_path = nil
end)

core.register_on_receiving_chat_message(function(message)
	if not log_path then return end
	local ts = os.date("%H:%M:%S")
	local text = core.strip_colors(message)
	core.append_file(log_path, "[" .. ts .. "] " .. text .. "\n")
	return
end)
