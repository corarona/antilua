-- DragonfireClient server-side test coordinator
-- Listens on the "df_test" mod channel for client test messages

local mod_channel
local function join_channel()
	local ok, ch = pcall(minetest.mod_channel_join, "df_test")
	if ok and ch then
		mod_channel = ch
		minetest.log("action", "[DF_TEST_SERVER] Joined mod channel 'df_test'")
		ch:on_receive(function(channel_name, sender, message)
			minetest.log("action", "[DF_TEST_SERVER] Received from " .. sender .. ": " .. message)
			if message == "ping" then
				ch:send_all(sender, "pong")
			elseif message == "test_player_pos" then
				local players = minetest.get_connected_players()
				for _, player in ipairs(players) do
					local pos = player:get_pos()
					minetest.log("action", string.format(
						"[DF_TEST_SERVER] Player %s at (%.1f, %.1f, %.1f)",
						player:get_player_name(), pos.x, pos.y, pos.z))
				end
				ch:send_all(sender, "player_pos_ack")
			end
		end)
	end
end

minetest.after(1, join_channel)

minetest.log("action", "[DF_TEST_SERVER] Loaded")
