-- Tests for tps_client mod

function test_tps_client(T)
	T.run("tps_client global exists", function()
		T.assert(tps_client ~= nil, "tps_client global should exist")
		T.assert(type(tps_client) == "table", "tps_client should be a table")
	end)
end
