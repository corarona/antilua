-- Tests for minimap marker API (skip when minimap is disabled)

function test_minimap_markers(T)
	T.defer("core.ui.minimap.add_marker exists", function()
		if not core.ui.minimap then return end
		T.assert(type(core.ui.minimap.add_marker) == "function",
			"add_marker should be a function")
	end)

	T.defer("core.ui.minimap.remove_marker exists", function()
		if not core.ui.minimap then return end
		T.assert(type(core.ui.minimap.remove_marker) == "function",
			"remove_marker should be a function")
	end)

	T.defer("core.ui.minimap.clear_markers exists", function()
		if not core.ui.minimap then return end
		T.assert(type(core.ui.minimap.clear_markers) == "function",
			"clear_markers should be a function")
	end)

	T.defer("core.ui.minimap:add_marker returns integer id", function()
		if not core.ui.minimap then return end
		local id = core.ui.minimap:add_marker({
			pos = { x = 0, y = 0, z = 0 },
		})
		T.assert(type(id) == "number", "should return a number")
		T.assert(id > 0, "id should be positive")
		core.ui.minimap:remove_marker(id)
	end)

	T.defer("core.ui.minimap:add_marker with color", function()
		if not core.ui.minimap then return end
		local id = core.ui.minimap:add_marker({
			pos = { x = 10, y = 20, z = 30 },
			color = "#00FF00",
		})
		T.assert(type(id) == "number", "should return a number")
		core.ui.minimap:remove_marker(id)
	end)

	T.defer("core.ui.minimap:remove_marker returns true on success", function()
		if not core.ui.minimap then return end
		local id = core.ui.minimap:add_marker({ pos = { x = 0, y = 0, z = 0 } })
		local ok = core.ui.minimap:remove_marker(id)
		T.assert(ok == true, "should return true")
	end)

	T.defer("core.ui.minimap:remove_marker returns false on missing", function()
		if not core.ui.minimap then return end
		local ok = core.ui.minimap:remove_marker(99999)
		T.assert(ok == false, "should return false for missing id")
	end)

	T.defer("core.ui.minimap:clear_markers", function()
		if not core.ui.minimap then return end
		core.ui.minimap:add_marker({ pos = { x = 0, y = 0, z = 0 } })
		core.ui.minimap:add_marker({ pos = { x = 1, y = 1, z = 1 } })
		core.ui.minimap:clear_markers()
		local ok = core.ui.minimap:remove_marker(1)
		T.assert(ok == false, "after clear, old ids should be gone")
	end)
end
