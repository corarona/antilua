-- Tests for player_radar mod

function test_player_radar(T)
	T.run("player_radar setting exists", function()
		local val = core.settings:get("player_radar")
		T.assert(val ~= nil, "player_radar setting should exist")
	end)
end
