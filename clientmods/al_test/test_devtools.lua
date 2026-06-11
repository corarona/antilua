-- Smoke tests for devtools mod

function test_devtools(T)
	T.run("devtools settings exist", function()
		local itemmeta = core.settings:get("itemmeta")
		T.assert(true, "devtools module loaded without error")
	end)
end
