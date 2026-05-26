-- Tests for DragonfireClient InventoryAction API

function test_inventory_action_no_player(T)
	T.run("InventoryAction constructor works", function()
		local ok, action = pcall(InventoryAction, "move")
		T.assert(ok and action ~= nil, "InventoryAction('move') should succeed")
	end)

	T.run("InventoryAction type checking", function()
		local ok, action = pcall(InventoryAction, "move")
		if not ok or not action then return end
		T.assert(type(action.apply) == "function", "action:apply should be a function")
		T.assert(type(action.from) == "function", "action:from should be a function")
		T.assert(type(action.to) == "function", "action:to should be a function")
		T.assert(type(action.set_count) == "function", "action:set_count should be a function")
	end)

	T.run("InventoryAction drop type", function()
		local ok, action = pcall(InventoryAction, "drop")
		T.assert(ok and action ~= nil, "InventoryAction('drop') should succeed")
	end)

	T.run("InventoryAction craft type", function()
		local ok, action = pcall(InventoryAction, "craft")
		T.assert(ok and action ~= nil, "InventoryAction('craft') should succeed")
	end)

	T.run("InventoryAction set_count works", function()
		local ok, action = pcall(InventoryAction, "move")
		if not ok or not action then return end
		local ok2 = pcall(action.set_count, action, 1)
		T.assert(ok2, "action:set_count(1) should not crash")
	end)

	-- core.get_inventory needs ModApiClient porting
	T.known_failure("core.get_inventory (needs ModApiClient)", function()
		local location = "player:singleplayer"
		local inv = core.get_inventory(location)
		T.assert(inv == nil or type(inv) == "table",
			"get_inventory should return nil or table")
	end)
end

function test_inventory_action(T)
	-- No additional deferred tests currently
end
