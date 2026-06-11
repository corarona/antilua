-- Tests for nlist (named lists) mod

function test_nlist(T)
	T.run("nlist global exists", function()
		T.assert(nlist ~= nil, "nlist global should exist")
		T.assert(type(nlist.get) == "function", "nlist.get should be a function")
	end)

	T.run("nlist basic CRUD", function()
		nlist.set("_al_test_list", {"a", "b", "c"})
		local result = nlist.get("_al_test_list")
		T.assert(result ~= nil, "get should return a table")
		T.assert_eq(#result, 3, "list should have 3 items")
		nlist.remove("_al_test_list")
	end)

	T.run("nlist handles missing lists", function()
		local result = nlist.get("_nonexistent_test_list")
		T.assert(true, "accessing nonexistent list did not crash")
	end)
end
