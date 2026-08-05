-- Tests for basic_moves mod

function test_basic_moves(T)
	T.run("basic_moves setting: autoforwardsprint", function()
		T.assert(core.settings:get("autoforwardsprint") ~= nil,
			"setting 'autoforwardsprint' should exist")
	end)

	T.run("basic_moves setting: continuous_forward", function()
		T.assert(core.settings:get("continuous_forward") ~= nil,
			"setting 'continuous_forward' should exist")
	end)

	T.run("basic_moves registers poi transports", function()
		T.assert(type(poi) == "table", "poi should be loaded")
		local names = {}
		for _, v in ipairs(poi.registered_transports) do
			names[v.name] = true
		end
		for _, name in ipairs({"CTP", "STP", "Autopilot"}) do
			T.assert(names[name], "transport '" .. name .. "' should be registered")
		end
	end)

	T.run("autofly.warp rejects void-dimension waypoints", function()
		local wp = "basic_moves_test_void"
		poi.delete_waypoint(wp)
		poi.set_waypoint({ x = 1000, y = -100, z = 1000 }, wp)
		T.assert(autofly.warp(wp) == false,
			"warp to a void-dimension waypoint should return false")
		poi.delete_waypoint(wp)
	end)

	T.run("poi_screenshots setting defaults to false", function()
		T.assert(core.settings:get_bool("poi_screenshots", false) == false,
			"'poi_screenshots' should default to false")
	end)
end
