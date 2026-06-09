-- AntiluaClient server-side test coordinator
-- Listens on the "df_test" mod channel for client test messages

core.register_on_modchannel_message(function(channel_name, sender, message)
	if channel_name ~= "df_test" then
		return
	end
	core.log("action", "[DF_TEST_SERVER] Received from " .. sender .. ": " .. message)
	if message == "ping" then
		core.mod_channel_send_all("df_test", "pong")
	elseif message == "test_player_pos" then
		local players = core.get_connected_players()
		for _, player in ipairs(players) do
			local pos = player:get_pos()
			core.log("action", string.format(
				"[DF_TEST_SERVER] Player %s at (%.1f, %.1f, %.1f)",
				player:get_player_name(), pos.x, pos.y, pos.z))
		end
		core.mod_channel_send_all("df_test", "player_pos_ack")
	end
end)

-- Join the channel
local ok = pcall(core.mod_channel_join, "df_test")
if ok then
	core.log("action", "[DF_TEST_SERVER] Joined mod channel 'df_test'")
else
	core.log("warning", "[DF_TEST_SERVER] Failed to join mod channel 'df_test'")
end

core.log("action", "[DF_TEST_SERVER] Loaded")
