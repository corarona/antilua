-- Tests for LocalPlayer API extras (collisionbox, eye_offset, gravity, etc.)
-- All deferred until core.localplayer is available

function test_localplayer_extras(T)
	T.defer("localplayer:get_collisionbox", function()
		local box = core.localplayer:get_collisionbox()
		-- push_aabb3f returns array [minX, minY, minZ, maxX, maxY, maxZ]
		T.assert(type(box) == "table", "should return a table")
		T.assert(type(box[1]) == "number", "minX should be a number")
		T.assert(type(box[2]) == "number", "minY should be a number")
		T.assert(type(box[5]) == "number", "maxY should be a number")
		T.assert(box[1] < box[4], "minX should be less than maxX")
	end)

	T.defer("localplayer:get_eye_offset", function()
		local off = core.localplayer:get_eye_offset()
		T.assert(type(off) == "table", "should return a table")
		T.assert(type(off.x) == "number", "x should be a number")
		T.assert(type(off.y) == "number", "y should be a number")
		T.assert(type(off.z) == "number", "z should be a number")
		-- eye height is typically positive (above player position)
		T.assert(off.y > 0, "eye Y offset should be positive")
	end)

	T.defer("localplayer:get_standing_node", function()
		local node = core.localplayer:get_standing_node()
		if node then
			T.assert(type(node) == "table", "should return a table")
			T.assert(type(node.x) == "number", "x should be a number")
		end
	end)

	T.defer("localplayer:get_gravity", function()
		local g = core.localplayer:get_gravity()
		T.assert(type(g) == "number", "should return a number")
		-- gravity may be 0 before first physics tick, but should be >= 0
		T.assert(g >= 0, "gravity should be >= 0")
	end)

	T.defer("localplayer:can_jump", function()
		local can = core.localplayer:can_jump()
		T.assert(type(can) == "boolean", "should return a boolean")
	end)

	T.defer("localplayer:get_autojump", function()
		local aj = core.localplayer:get_autojump()
		T.assert(type(aj) == "boolean", "should return a boolean")
	end)

	T.defer("localplayer:set_autojump", function()
		local before = core.localplayer:get_autojump()
		core.localplayer:set_autojump(not before)
		local after = core.localplayer:get_autojump()
		T.assert(after == not before, "autojump should toggle")
		-- restore
		core.localplayer:set_autojump(before)
	end)

	T.defer("localplayer:get_zoom_fov", function()
		local fov = core.localplayer:get_zoom_fov()
		T.assert(type(fov) == "number", "should return a number")
		-- 0 = zoom disabled, otherwise a positive FOV value
		T.assert(fov >= 0, "zoom fov should be >= 0")
		-- The zoom_bypass mod forces 15 when priv_bypass is active
		if core.settings:get_bool("priv_bypass") then
			T.assert(fov == 15, "zoom_bypass should force fov to 15, got " .. tostring(fov))
		end
	end)

	T.defer("localplayer:set_zoom_fov", function()
		local before = core.localplayer:get_zoom_fov()
		core.localplayer:set_zoom_fov(20)
		T.assert(core.localplayer:get_zoom_fov() == 20, "zoom fov should be settable")
		-- restore
		core.localplayer:set_zoom_fov(before)
		T.assert(core.localplayer:get_zoom_fov() == before, "zoom fov should restore")
	end)
end
