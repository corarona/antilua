-- Tests for the mapviewer clientmod (formspec big-map viewer).

function test_mapviewer(T)
	T.run("mapviewer mod is loaded", function()
		T.assert(type(mapviewer) == "table", "mapviewer global should exist")
		T.assert(type(mapviewer.open) == "function", "mapviewer.open should be a function")
		T.assert(type(mapviewer.save_current) == "function",
			"mapviewer.save_current should be a function")
		T.assert(type(mapviewer.handle_fields) == "function",
			"mapviewer.handle_fields should be a function")
	end)

	T.run("mapviewer handle_fields consumes buttons without errors", function()
		local ok = pcall(function()
			return mapviewer.handle_fields({ pan_n = "true" })
		end)
		T.assert(ok == true, "handle_fields should not error on pan_n")
	end)

	-- Requires the big map save dir (resolved after connect) and a rendered
	-- section, so defer until the world/localplayer is ready.
	T.defer("mapviewer save_current copies the displayed section to PNG", function()
		if not (core.al_bigmap and core.al_bigmap.render_section) then
			core.log("info", "[AL_TEST] skipping mapviewer save test: no big map")
			return
		end
		mapviewer.open()
		local path = mapviewer.save_current()
		T.assert(path ~= nil, "save_current should return a saved path, got "
			.. tostring(path))
		if path then
			local data = core.read_file(path)
			T.assert(data ~= nil and #data > 0,
				"saved PNG should exist and be non-empty")
		end
		core.al_bigmap:clear_images()
	end)
end
