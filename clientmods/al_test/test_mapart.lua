function test_mapart(T)
	T.run("core.decode_image exists", function()
		T.assert(type(core.decode_image) == "function",
			"core.decode_image should be a function")
	end)

	T.run("core.write_file exists", function()
		T.assert(type(core.write_file) == "function",
			"core.write_file should be a function")
	end)

	T.run("decode_image fails on empty data", function()
		local r = core.decode_image("")
		T.assert(r == nil, "should return nil for empty data")
	end)

	T.run("decode_image fails on garbage data", function()
		local r, img = core.decode_image("not a png")
		T.assert(r == nil, "should return nil for garbage")
	end)

	T.run("write_file and read_file roundtrip", function()
		local test_data = "hello mapart"
		local test_path = "/tmp/antilua_mapart_test"
		local ok = core.write_file(test_path, test_data)
		T.assert(ok, "write_file should succeed")

		local ok2, data = pcall(core.read_file, test_path)
		T.assert(ok2, "read_file of written file should succeed")
		T.assert_eq(data, test_data, "read back data should match")

		core.write_file(test_path, "")
	end)

	T.run("write_file path traversal denied", function()
		local ok, err = core.write_file("../../etc/passwd", "hack")
		T.assert(not ok, "path traversal should be denied")
	end)

	T.run("mapart module loaded", function()
		T.assert(type(mapart) == "table", "mapart global table exists")
		T.assert(type(mapart.palette) == "table", "mapart.palette exists")
		T.assert(#mapart.palette > 0, "palette has entries")
	end)

	T.run("mapart.find_closest exact match", function()
		local pal = {
			{ name = "red", param2 = 0, r = 255, g = 0, b = 0 },
			{ name = "green", param2 = 0, r = 0, g = 255, b = 0 },
			{ name = "blue", param2 = 0, r = 0, g = 0, b = 255 },
		}
		local best = mapart.find_closest(255, 0, 0, false, pal)
		T.assert(best ~= nil, "should find a match")
		T.assert_eq(best.name, "red", "exact red match")
	end)

	T.run("mapart.find_closest nearest neighbor", function()
		local pal = {
			{ name = "black", param2 = 0, r = 0, g = 0, b = 0 },
			{ name = "white", param2 = 0, r = 255, g = 255, b = 255 },
		}
		local best = mapart.find_closest(200, 200, 200, false, pal)
		T.assert(best ~= nil, "should find a match")
		T.assert_eq(best.name, "white", "light gray should match white")
	end)

	T.run("mapart.floyd_steinberg distributes error", function()
		local errors = {}
		for i = 1, 4 * 4 * 3 do errors[i] = 0 end
		mapart.floyd_steinberg(errors, 4, 4, 1, 1, 100, 0, 0)
		-- Error should be distributed to 4 neighbors at standard ratios
		local idx_2_1 = 1 * 4 + 2  -- right (7/16)
		T.assert(errors[idx_2_1 * 3 + 1] > 0, "right neighbor should receive error")
	end)

	T.run("mapart.sample_px nearest neighbor", function()
		-- Create a 2x2 RGBA pixel string: red, green, blue, white
		local data = string.char(
			255, 0, 0, 255,
			0, 255, 0, 255,
			0, 0, 255, 255,
			255, 255, 255, 255
		)
		local r, g, b, a = mapart.sample_px(data, 2, 2, 0, 0, 2, 2, false)
		T.assert_eq(r, 255, "top-left should be red")
		T.assert_eq(g, 0, "top-left should be red")
		T.assert_eq(a, 255, "alpha should be 255")
	end)

	T.run("mapart.sample_px bilinear interpolation", function()
		local data = string.char(
			255, 0, 0, 255,
			0, 255, 0, 255,
			0, 0, 255, 255,
			255, 255, 255, 255
		)
		-- Sample at half-pixel offset (should blend)
		local r, g, b, a = mapart.sample_px(data, 2, 2, 0.5, 0.5, 2, 2, true)
		T.assert(a == 255, "alpha should be 255")
		-- At 0.5,0.5 the bilinear blend of a 2x2: red(1-fx)(1-fy) + green(fx)(1-fy) + blue(1-fx)(fy) + white(fx)(fy)
		-- = 255*0.25 + 0*0.25 + 0*0.25 + 255*0.25 = 127.5 → 127
		T.assert(r > 0 and r < 255, "interpolated red should be between 0-255")
	end)

	T.run("mapart.reduce_palette returns same palette when under limit", function()
		local pal = {
			{ name = "a", param2 = 0, r = 255, g = 0, b = 0 },
			{ name = "b", param2 = 0, r = 0, g = 255, b = 0 },
		}
		local result = mapart.reduce_palette(pal, 5)
		T.assert_eq(#result, 2, "should keep all entries when max > count")
	end)

	T.run("mapart.reduce_palette reduces to specified count", function()
		local pal = {}
		for i = 1, 10 do
			table.insert(pal, { name = "c" .. i, param2 = 0, r = i * 25, g = i * 25, b = i * 25 })
		end
		local result = mapart.reduce_palette(pal, 3)
		T.assert_eq(#result, 3, "should reduce to 3 entries")
	end)

	T.run("mapart.game_state exists", function()
		T.assert(type(mapart.state) == "table", "mapart.state table exists")
	end)

	T.run("mapart.convert_image exists", function()
		T.assert(type(mapart.convert_image) == "function", "convert_image should be a function")
	end)

	T.run("mapart.image_to_schem exists", function()
		T.assert(type(mapart.image_to_schem) == "function", "image_to_schem should be a function")
	end)

	T.run("mapart.image_to_wall_schem exists", function()
		T.assert(type(mapart.image_to_wall_schem) == "function", "image_to_wall_schem should be a function")
	end)

	T.run("mapart.save_and_load_mts exists", function()
		T.assert(type(mapart.save_and_load_mts) == "function", "save_and_load_mts should be a function")
	end)
end
