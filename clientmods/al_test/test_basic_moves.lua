-- Tests for basic_moves mod

function test_basic_moves(T)
	local expected = {"autopilot", "auto_sprint", "auto_sneak", "autoforwardsprint"}
	for _, name in ipairs(expected) do
		T.run("basic_moves setting: " .. name, function()
			T.assert(core.settings:get(name) ~= nil,
				"setting '" .. name .. "' should exist")
		end)
	end
end
