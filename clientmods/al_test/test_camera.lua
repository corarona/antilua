-- Tests for Camera API (nametags)

function test_camera_nametags(T)
	T.defer("core.camera:add_nametag exists", function()
		T.assert(type(core.camera.add_nametag) == "function",
			"add_nametag should be a function")
	end)

	T.defer("core.camera:add_nametag returns integer id", function()
		local id = core.camera:add_nametag({
			pos = { x = 0, y = 0, z = 0 },
			text = "test"
		})
		T.assert(type(id) == "number", "should return a number")
		T.assert(id > 0, "id should be positive")
		-- cleanup
		core.camera:remove_nametag(id)
	end)

	T.defer("core.camera:add_nametag with all fields", function()
		local id = core.camera:add_nametag({
			pos = { x = 10, y = 20, z = 30 },
			text = "hello",
			color = "#FF0000",
			size = 24,
			scale_z = true,
		})
		T.assert(type(id) == "number", "should return a number")
		core.camera:remove_nametag(id)
	end)

	T.defer("core.camera:remove_nametag returns true on success", function()
		local id = core.camera:add_nametag({
			pos = { x = 0, y = 0, z = 0 },
			text = "remove_me"
		})
		local ok = core.camera:remove_nametag(id)
		T.assert(ok == true, "remove_nametag should return true")
	end)

	T.defer("core.camera:remove_nametag returns false on missing", function()
		local ok = core.camera:remove_nametag(99999)
		T.assert(ok == false, "remove_nametag should return false for missing id")
	end)

	T.defer("core.camera:clear_nametags", function()
		core.camera:add_nametag({ pos = { x = 0, y = 0, z = 0 }, text = "a" })
		core.camera:add_nametag({ pos = { x = 1, y = 1, z = 1 }, text = "b" })
		core.camera:clear_nametags()
		-- removing any old id should fail now
		local ok = core.camera:remove_nametag(1)
		T.assert(ok == false, "after clear, old ids should be gone")
	end)

	T.defer("core.camera:add_nametag with bgcolor", function()
		local id = core.camera:add_nametag({
			pos = { x = 5, y = 5, z = 5 },
			text = "bg_test",
			color = "#FFFFFF",
			bgcolor = "#000000",
		})
		T.assert(type(id) == "number", "should succeed with bgcolor")
		core.camera:remove_nametag(id)
	end)

	T.defer("core.camera nametags survive multiple add/remove", function()
		local ids = {}
		for i = 1, 10 do
			ids[i] = core.camera:add_nametag({
				pos = { x = i, y = 0, z = 0 },
				text = "n" .. i
			})
		end
		for _, id in ipairs(ids) do
			local ok = core.camera:remove_nametag(id)
			T.assert(ok, "should remove id " .. id)
		end
	end)
end
