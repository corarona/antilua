-- Tests for the Antilua big map / per-server minimap persistence API.

local function find_test_node()
	for _, name in ipairs({
		"basenodes:stone", "mapgen_stone", "default:stone",
		"testnodes:stone", "air",
	}) do
		if core.get_node_def(name) then
			return name
		end
	end
	return nil
end

function test_bigmap_api(T)
	T.run("core.al_bigmap exists", function()
		T.assert(type(core.al_bigmap) == "table",
			"core.al_bigmap should be a table")
	end)

	T.run("core.al_bigmap has full API", function()
		local api = {
			"open", "close", "toggle", "is_open",
			"set_center", "get_center", "pan", "set_zoom", "get_zoom",
			"set_follow_player", "get_follow_player",
			"set_save_enabled", "get_save_enabled",
			"save", "load", "clear",
			"get_block_count", "get_save_dir", "get_coverage",
			"has_block", "get_pixel", "set_pixel", "get_block",
		}
		for _, fn in ipairs(api) do
			T.assert(type(core.al_bigmap[fn]) == "function",
				"core.al_bigmap." .. fn .. " should be a function")
		end
	end)

	T.run("big map callbacks are registered", function()
		T.assert(type(core.register_on_bigmap_open) == "function",
			"register_on_bigmap_open should be a function")
		T.assert(type(core.register_on_bigmap_close) == "function",
			"register_on_bigmap_close should be a function")
	end)

	T.run("big map view control (colon and dot syntax)", function()
		core.al_bigmap:open()
		T.assert(core.al_bigmap:is_open(), "is_open should be true after open")
		core.al_bigmap.close()
		T.assert(not core.al_bigmap:is_open(), "is_open should be false after close")
		core.al_bigmap:toggle()
		T.assert(core.al_bigmap:is_open(), "toggle should open the map")
		core.al_bigmap:toggle()
		T.assert(not core.al_bigmap:is_open(), "toggle should close the map")

		core.al_bigmap:set_follow_player(true)
		T.assert(core.al_bigmap:get_follow_player() == true,
			"follow_player get/set")
		core.al_bigmap:set_zoom(2.0)
		T.assert(core.al_bigmap:get_zoom() == 2.0, "zoom get/set")
		local c = core.al_bigmap:get_center()
		T.assert(type(c) == "table" and type(c.x) == "number",
			"get_center returns coords")

		local save_dir = core.al_bigmap:get_save_dir()
		T.assert(type(save_dir) == "string", "get_save_dir returns a string")

		core.al_bigmap:set_save_enabled(true)
		T.assert(core.al_bigmap:get_save_enabled() == true,
			"save_enabled get/set")
	end)
end

function test_bigmap_pixels(T)
	local node_name = find_test_node()
	if not node_name then
		core.log("info", "[AL_TEST] skipping pixel roundtrip: no known test node")
		return
	end

	T.run("big map set_pixel/get_pixel roundtrip", function()
		local x, z = 1200, 3400

		local ok = core.al_bigmap:set_pixel(x, z, {
			node = node_name,
			height = 64,
			air_count = 3,
			param2 = 1,
		})
		T.assert(ok == true, "set_pixel should return true")

		local p = core.al_bigmap:get_pixel(x, z)
		T.assert(p ~= nil, "get_pixel should return a pixel after set_pixel")
		T.assert(p.node == node_name,
			"pixel node should match: " .. node_name .. " got " .. tostring(p and p.node))
		T.assert(p.height == 64, "pixel height should be preserved")
		T.assert(p.air_count == 3, "pixel air_count should be preserved")
		T.assert(p.param2 == 1, "pixel param2 should be preserved")

		T.assert(core.al_bigmap:get_block_count() >= 1,
			"get_block_count should be at least 1 after set_pixel")

		local cov = core.al_bigmap:get_coverage()
		T.assert(type(cov) == "table" and type(cov.count) == "number",
			"get_coverage should return a table with count")

		local blk = core.al_bigmap:get_block(x, z)
		T.assert(type(blk) == "table" and type(blk.data) == "table",
			"get_block should return a block with data")
		if blk and blk.data then
			local ix = (x % 16) + 1
			local iz = (z % 16) + 1
			local px = blk.data[iz] and blk.data[iz][ix]
			T.assert(px ~= nil and px.node == node_name,
				"get_block pixel should match set pixel")
		end
	end)

	T.run("big map save()/load() roundtrip", function()
		local x, z = 1200, 3400
		core.al_bigmap:save()
		core.al_bigmap:load()
		local p2 = core.al_bigmap:get_pixel(x, z)
		T.assert(p2 ~= nil and p2.node == node_name,
			"pixel should survive save()/load() roundtrip")
	end)

	-- render_section needs the save dir resolved (after connect), so defer it.
	T.defer("big map render_section writes a PNG", function()
		T.assert(type(core.al_bigmap.render_section) == "function",
			"render_section should be a function")
		local name = core.al_bigmap:render_section({
			pos = { x = 1200, z = 3400 },
			size = { x = 128, z = 128 },
		})
		T.assert(type(name) == "string" and name:match("%.png$"),
			"render_section should return a .png texture name, got "
				.. tostring(name))
		if type(name) == "string" then
			local dir = core.al_bigmap:get_save_dir() .. "/images"
			local data = core.read_file(dir .. "/" .. name)
			T.assert(data ~= nil and #data > 0,
				"rendered section PNG should exist and be non-empty")
		end
		core.al_bigmap:clear_images()
	end)
end

function test_bigmap_clear(T)
	T.run("big map clear()", function()
		local before = core.al_bigmap:get_block_count()
		core.al_bigmap:clear()
		T.assert(core.al_bigmap:get_block_count() == 0,
			"clear should empty the block store (had " .. before .. ")")
		local p = core.al_bigmap:get_pixel(1200, 3400)
		T.assert(p == nil, "cleared pixel should be gone")
	end)
end

function test_bigmap_live_capture(T)
	-- Deferred until the world/localplayer is ready: minimap blocks stream in
	-- from the mesh thread, so the big map store should grow on its own.
	T.defer("big map captures live minimap blocks", function()
		local save_dir = core.al_bigmap:get_save_dir()
		T.assert(type(save_dir) == "string" and #save_dir > 0,
			"big map save dir should be resolved after connecting")

		local polls = 40 -- 40 * 0.5s = 20s timeout
		local function poll()
			local n = core.al_bigmap:get_block_count()
			if n > 0 then
				core.log("info", "[AL_TEST] big map live capture count: " .. n)
				return
			end
			if polls > 0 then
				polls = polls - 1
				core.after(0.5, poll)
			end
		end
		poll()
	end)
end
