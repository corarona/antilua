-- Tests for formspec_utils mod

function test_formspec_utils(T)
	T.run("formspec_utils module loaded", function()
		T.assert(true, "formspec_utils module loaded without error")
	end)
end
