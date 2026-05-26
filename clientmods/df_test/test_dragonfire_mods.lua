-- Tests for DragonfireClient DRAGONFIRE modpack mods

function test_dragonfire_wasplib(T)
	T.run("ws namespace exists", function()
		T.assert(type(ws) == "table", "ws should be a table")
	end)

	T.run("ws.s exists", function()
		T.assert(type(ws.s) == "function", "ws.s should be a function")
	end)

	T.run("ws.dircoord exists", function()
		T.assert(type(ws.dircoord) == "function", "ws.dircoord should be a function")
	end)

	T.run("ws.switch_to_item exists", function()
		T.assert(type(ws.switch_to_item) == "function", "ws.switch_to_item should be a function")
	end)

	T.run("ws.place exists", function()
		T.assert(type(ws.place) == "function", "ws.place should be a function")
	end)

	T.run("ws.dig exists", function()
		T.assert(type(ws.dig) == "function", "ws.dig should be a function")
	end)

	T.run("ws.rg exists", function()
		T.assert(type(ws.rg) == "function", "ws.rg should be a function")
	end)
end

function test_dragonfire_lockview(T)
	T.run("lockview cheat setting exists", function()
		local val = core.settings:get("lockview")
		T.assert(val ~= nil, "setting 'lockview' should exist")
	end)
end

function test_dragonfire_headsaver(T)
	T.run("headsaver cheat setting exists", function()
		local val = core.settings:get("headsaver")
		T.assert(val ~= nil, "setting 'headsaver' should exist")
	end)
end

function test_dragonfire_invsaver(T)
	T.run("invsaver cheat setting exists", function()
		local val = core.settings:get("invsaver")
		T.assert(val ~= nil, "setting 'invsaver' should exist")
	end)
end

function test_dragonfire_antitower(T)
	T.run("anti_tower cheat setting exists", function()
		local val = core.settings:get("anti_tower")
		T.assert(val ~= nil, "setting 'anti_tower' should exist")
	end)

	T.run("atower cheat setting exists", function()
		local val = core.settings:get("atower")
		T.assert(val ~= nil, "setting 'atower' should exist")
	end)
end

function test_dragonfire_walls(T)
	T.run("scaffold_wallin cheat setting exists", function()
		local val = core.settings:get("scaffold_wallin")
		T.assert(val ~= nil, "setting 'scaffold_wallin' should exist")
	end)

	T.run("scaffold_skypltfrm cheat setting exists", function()
		local val = core.settings:get("scaffold_skypltfrm")
		T.assert(val ~= nil, "setting 'scaffold_skypltfrm' should exist")
	end)

	T.run("pceiling cheat setting exists", function()
		local val = core.settings:get("pceiling")
		T.assert(val ~= nil, "setting 'pceiling' should exist")
	end)
end

function test_dragonfire_autoevade(T)
	T.run("autoevade cheat setting exists", function()
		local val = core.settings:get("autoevade")
		T.assert(val ~= nil, "setting 'autoevade' should exist")
	end)
end

function test_dragonfire_extracted_features(T)
	T.run("ws.make_blocks exists", function()
		T.assert(type(ws.make_blocks) == "function", "ws.make_blocks should be a function")
	end)

	T.run("ws.loot exists", function()
		T.assert(type(ws.loot) == "function", "ws.loot should be a function")
	end)

	T.run("ws.icebreaker exists", function()
		T.assert(type(ws.icebreaker) == "function", "ws.icebreaker should be a function")
	end)
end
