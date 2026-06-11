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
end
