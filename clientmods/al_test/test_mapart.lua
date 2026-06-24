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
end
