-- Tests for core.get_nodes_in_area

function test_client_map(T)
	-- Registration test (runs immediately)
	T.run("core.get_nodes_in_area exists", function()
		T.assert(type(core.get_nodes_in_area) == "function",
			"core.get_nodes_in_area should be a function")
	end)

	-- Bad volume test (runs immediately)
	T.run("get_nodes_in_area rejects too-large volume", function()
		local ok, err = pcall(core.get_nodes_in_area,
			{x = 0, y = 0, z = 0},
			{x = 999, y = 999, z = 999})
		T.assert(not ok, "should throw on huge volume")
		T.assert(string.find(tostring(err), "volume") ~= nil,
			"error should mention volume, got: " .. tostring(err))
	end)

	-- Empty area (same pos) returns empty table
	T.run("get_nodes_in_area empty area returns empty table", function()
		local r = core.get_nodes_in_area({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
		T.assert(type(r) == "table", "should return a table")
	end)

	-- Scan a wide area to make sure we find non-air nodes even if not fully loaded
	T.defer("get_nodes_in_area returns properly formatted nodes", function()
		local pos = core.localplayer:get_pos()
		local p1 = {x = -50, y = -10, z = -50}
		local p2 = {x = 50, y = 50, z = 50}
		local nodes = core.get_nodes_in_area(p1, p2)
		T.assert(type(nodes) == "table", "should return a table")
		-- Each entry should have position fields and a name
		for i, n in ipairs(nodes) do
			T.assert(type(n.x) == "number", "entry " .. i .. " should have x, got " .. type(n.x))
			T.assert(type(n.y) == "number", "entry " .. i .. " should have y")
			T.assert(type(n.z) == "number", "entry " .. i .. " should have z")
			T.assert(type(n.name) == "string", "entry " .. i .. " should have name, got " .. type(n.name))
			T.assert(type(n.param1) == "number", "entry " .. i .. " should have param1")
			T.assert(type(n.param2) == "number", "entry " .. i .. " should have param2")
			T.assert(n.name ~= "air", "should not contain air nodes")
			T.assert(n.name ~= "ignore", "should not contain ignore nodes")
		end
	end)

	-- Check that single-position scan returns the expected structure
	T.defer("get_nodes_in_area single position returns table", function()
		local pos = core.localplayer:get_pos()
		local bp = {x = math.floor(pos.x), y = math.floor(pos.y) - 1, z = math.floor(pos.z)}
		local nodes = core.get_nodes_in_area(bp, bp)
		T.assert(type(nodes) == "table", "should return a table")
		-- May be empty if floor position is air
	end)
end
