-- Add [HH:MM:SS] timestamps to chat messages
core.register_on_receiving_chat_message(function(msg)
	if not msg then return end
	local ts = os.date("%H:%M:%S")
	return "[" .. ts .. "] " .. msg
end)
