-- Chat command to test the 3D drawing API

core.register_chatcommand("testdraw", {
	params = "sphere <radius> [wire] | box <w> [h] [d] | wirebox <w> [h] [d] | wiresphere <radius> | circle <radius> | line <length> | all | clear [group]",
	description = "Test the Lua 3D drawing API",
	func = function(param)
		if not core.draw3d then
			return false, "draw3d API not available"
		end

		local parts = param:split(" ")
		local cmd = parts[1]
		if not cmd or cmd == "" then
			return false, "Usage: .testdraw sphere|box|wirebox|circle|line|all|clear [params]"
		end

		local pos = core.localplayer and core.localplayer:get_pos()
		if not pos then
			return false, "Player not ready"
		end

		if cmd == "clear" then
			local group = tonumber(parts[2])
			if group then
				core.draw3d:clear(group)
				return true, "Cleared shapes in group " .. group
			else
				core.draw3d:clear()
				return true, "Cleared all shapes"
			end
		end

		if cmd == "sphere" then
			local radius = tonumber(parts[2]) or 5
			local is_wire = parts[3] == "wire"
			local segs = tonumber(parts[3]) or (is_wire and 24 or nil)
			if is_wire then
				core.draw3d:add_wiresphere(pos, radius, "#00FF00", segs)
			else
				core.draw3d:add_sphere(pos, radius, "#00FF0080", segs)
			end
			return true, "Added " .. (is_wire and "wireframe " or "") .. "sphere at " .. core.pos_to_string(pos) .. " radius=" .. radius

		elseif cmd == "wiresphere" then
			local radius = tonumber(parts[2]) or 5
			local segs = tonumber(parts[3]) or 24
			core.draw3d:add_wiresphere(pos, radius, "#00FF00", segs)
			return true, "Added wireframe sphere at " .. core.pos_to_string(pos) .. " radius=" .. radius

		elseif cmd == "box" then
			local w = tonumber(parts[2]) or 5
			local h = tonumber(parts[3]) or w
			local d = tonumber(parts[4]) or w
			local p1 = {x = pos.x - w / 2, y = pos.y, z = pos.z - d / 2}
			local p2 = {x = pos.x + w / 2, y = pos.y + h, z = pos.z + d / 2}
			core.draw3d:add_box(p1, p2, "#FF4444")
			return true, "Added box " .. w .. "x" .. h .. "x" .. d .. " at " .. core.pos_to_string(pos)

		elseif cmd == "wirebox" then
			local w = tonumber(parts[2]) or 5
			local h = tonumber(parts[3]) or w
			local d = tonumber(parts[4]) or w
			local p1 = {x = pos.x - w / 2, y = pos.y, z = pos.z - d / 2}
			local p2 = {x = pos.x + w / 2, y = pos.y + h, z = pos.z + d / 2}
			core.draw3d:add_wirebox(p1, p2, "#FFFF44")
			return true, "Added wirebox " .. w .. "x" .. h .. "x" .. d

		elseif cmd == "circle" then
			local radius = tonumber(parts[2]) or 5
			local segs = tonumber(parts[3]) or 32
			core.draw3d:add_circle(pos, radius, "#44AAFF", segs)
			return true, "Added circle at " .. core.pos_to_string(pos) .. " radius=" .. radius

		elseif cmd == "line" then
			local length = tonumber(parts[2]) or 10
			local look = core.camera:get_look_dir()
			local p2 = {x = pos.x + look.x * length, y = pos.y + look.y * length, z = pos.z + look.z * length}
			core.draw3d:add_line(pos, p2, "#FF44FF")
			return true, "Added line length=" .. length

		elseif cmd == "all" then
			core.draw3d:add_sphere({x = pos.x + 8, y = pos.y, z = pos.z}, 3, "#00FF0080", 16, 1)
			core.draw3d:add_wiresphere({x = pos.x - 8, y = pos.y, z = pos.z}, 3, "#00FF00", 16, 6)
			core.draw3d:add_box({x = pos.x - 5, y = pos.y, z = pos.z - 2}, {x = pos.x + 5, y = pos.y + 4, z = pos.z + 2}, "#FF444480", 2)
			core.draw3d:add_wirebox({x = pos.x - 5, y = pos.y + 5, z = pos.z - 2}, {x = pos.x + 5, y = pos.y + 9, z = pos.z + 2}, "#FFFF44", 3)
			core.draw3d:add_circle(pos, 6, "#44AAFF", 32, 4)
			local look = core.camera:get_look_dir()
			core.draw3d:add_line(pos, {x = pos.x + look.x * 12, y = pos.y + look.y * 12, z = pos.z + look.z * 12}, "#FF44FF", 5)
			return true, "Added shapes. .testdraw clear <group> to remove."

		else
			return false, "Unknown subcommand: " .. cmd .. ". Use sphere|box|wirebox|circle|line|all|clear"
		end
	end,
})
