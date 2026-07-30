-- Save MTS to schematics dir and load into schembuilder
function mapart.save_and_load_mts(schem, name, use_pos)
	local mts_data = core.serialize_schematic(schem, "mts")
	if not mts_data then
		return false, "Failed to serialize schematic"
	end

	local schem_dir = core.settings:get("mapart_output_dir")
		or (core.get_data_path() .. "/schematics")

	local filepath = schem_dir .. "/" .. name:gsub("%.png$", "") .. ".mts"
	local ok, err = core.write_file(filepath, mts_data)
	if not ok then
		return false, err or "Failed to write MTS file"
	end

	if schembuilder_api and type(schembuilder_api.load_mts) == "function" then
		schembuilder_api.load_mts(filepath, name:gsub("%.png$", "") .. ".mts", use_pos)
	end
	return true, filepath
end

-- Build a filtered palette with only nodes in the player's inventory
function mapart.build_inv_palette()
	local inv = core.get_inventory("current_player")
	if not inv then return nil end
	local types = {}
	for _, list_name in ipairs({"main", "craft"}) do
		local list = inv[list_name]
		if list then
			for _, stack in ipairs(list) do
				if not stack:is_empty() then
					local name = stack:get_name()
					if name then
						types[name] = true
					end
				end
			end
		end
	end
	local filtered = {}
	for _, entry in ipairs(mapart.palette) do
		if types[entry.name] then
			table.insert(filtered, entry)
		end
	end
	return filtered
end

-- Convert decoded image data to an MTS schematic
-- mode: "floor" (2D horizontal), "wall_x" (vertical facing X), "wall_z" (vertical facing Z)
function mapart.convert_image(width, height, pixel_data, mode, opts)
	opts = opts or {}
	local out_w = opts.width or width
	local out_h = opts.height or height

	local errors = {}
	if opts.dither then
		for i = 1, out_w * out_h * 3 do errors[i] = 0 end
	end

	local px_opts = {
		dither = opts.dither,
		gamma = opts.gamma,
		palette = opts.palette,
		filter = opts.filter,
		errors = errors,
	}

	local schem
	if mode == "wall_x" then
		schem = { size = { x = out_w, y = out_h, z = 1 }, data = {} }
	elseif mode == "wall_z" then
		schem = { size = { x = 1, y = out_h, z = out_w }, data = {} }
	else
		schem = { size = { x = out_w, y = 1, z = out_h }, data = {} }
	end

	if mode == "wall_z" then
		for z = 0, out_w - 1 do
			for y = out_h - 1, 0, -1 do
				table.insert(schem.data, mapart._process_pixel(pixel_data, width, height, z, y, out_w, out_h, px_opts))
			end
		end
	elseif mode == "wall_x" then
		for y = out_h - 1, 0, -1 do
			for x = 0, out_w - 1 do
				table.insert(schem.data, mapart._process_pixel(pixel_data, width, height, x, y, out_w, out_h, px_opts))
			end
		end
	else
		for z = out_h - 1, 0, -1 do
			for x = 0, out_w - 1 do
				table.insert(schem.data, mapart._process_pixel(pixel_data, width, height, x, z, out_w, out_h, px_opts))
			end
		end
	end

	return schem
end

-- Convert decoded image data to a floor MTS schematic
function mapart.image_to_schem(width, height, pixel_data, opts)
	return mapart.convert_image(width, height, pixel_data, "floor", opts)
end

-- Convert decoded image data to a vertical wall MTS schematic
function mapart.image_to_wall_schem(width, height, pixel_data, opts)
	opts = opts or {}
	local dir = opts.direction or "x"
	local mode = dir == "z" and "wall_z" or "wall_x"
	return mapart.convert_image(width, height, pixel_data, mode, opts)
end

-- Shared pixel processor used by both sync and async conversion paths
-- Returns { name, prob, param2 } for the given pixel
function mapart._process_pixel(pixel_data, img_w, img_h, img_x, img_y, out_w, out_h, opts)
	local use_bilinear = opts.filter == "bilinear"
	opts.errors = opts.errors or {}
	local errors = opts.errors
	local r, g, b, a = mapart.sample_px(pixel_data, img_w, img_h, img_x, img_y, out_w, out_h, use_bilinear)
	if opts.dither then
		local idx = img_y * out_w + img_x
		r = math.max(0, math.min(255, r + (errors[idx * 3 + 1] or 0)))
		g = math.max(0, math.min(255, g + (errors[idx * 3 + 2] or 0)))
		b = math.max(0, math.min(255, b + (errors[idx * 3 + 3] or 0)))
	end
	local threshold = 128
	local best = mapart.find_closest(r, g, b, opts.gamma, opts.palette or mapart.palette)
	if best and best.a then
		threshold = best.a
	end
	if a < threshold then
		return { name = "air", prob = 0, param2 = 0 }
	end
	if best then
		local dr = r - best.r; local dg = g - best.g; local db = b - best.b
		if opts.dither then
			mapart.floyd_steinberg(errors, out_w, out_h, img_x, img_y, dr, dg, db)
		end
		return { name = best.name, prob = 254, param2 = best.param2 }
	end
	return { name = "air", prob = 0, param2 = 0 }
end

function mapart.process_conv_chunk()
	local s = mapart.state
	if not s then return end
	local c = s._conv
	if not c then return end
	if not core.localplayer then
		s._conv = nil
		s._conv_cancel = false
		s.status = "Cancelled (disconnected)"
		return
	end
	if s._conv_cancel then
		s._conv = nil
		s._conv_cancel = false
		return
	end

	local px_opts = {
		dither = c.dither,
		gamma = c.gamma,
		palette = c.pal,
		filter = c.filter,
		errors = c.errors,
	}

	local chunk = 32
	local done = 0

	if c.mode == "wall_z" then
		for batch = 1, chunk do
			if c.z >= c.out_w then done = 1; break end
			for y = c.out_h - 1, 0, -1 do
				local entry = mapart._process_pixel(c.img.data, c.img.width, c.img.height, c.z, y, c.out_w, c.out_h, px_opts)
				table.insert(c.schem.data, entry)
			end
			c.z = c.z + 1
		end
	else
		for batch = 1, chunk do
			if c.y < 0 then done = 1; break end
			for x = 0, c.out_w - 1 do
				local img_y = c.y
				if c.mode:sub(1,4) == "wall" then
					-- wall_x: img_y = c.y, same as floor
				end
				local entry = mapart._process_pixel(c.img.data, c.img.width, c.img.height, x, img_y, c.out_w, c.out_h, px_opts)
				table.insert(c.schem.data, entry)
			end
			c.y = c.y - 1
		end
	end

	if done == 1 or (c.mode == "floor" and c.y < 0) or (c.mode:sub(1,4) == "wall" and c.wall_dir == "x" and c.y < 0) or (c.wall_dir == "z" and c.z >= c.out_w) then
		if #c.schem.data == 0 then
			s.status = "No non-transparent pixels found"
			return
		end

		if c.mode == "floor" then
			if c.grid_new ~= s.grid_new then
				core.settings:set_bool("mapart_grid_new", c.grid_new)
			end
			s.grid_new = c.grid_new
			local grid_pos
			if core.localplayer then
				grid_pos = mapart.compute_grid_pos(core.localplayer:get_pos(), c.grid_new)
			end
			local ok3, result = mapart.save_and_load_mts(c.schem, c.name, grid_pos)
			if ok3 then
				s.status = "Saved: " .. result
				s.conv_done = true
				s.conv_filename = c.name:gsub("%.png$", "") .. ".mts"
			else
				s.status = "Error: " .. (result or "unknown")
			end
		else
			local ok3, result = mapart.save_and_load_mts(c.schem, c.name)
			if ok3 then
				s.status = "Saved: " .. result
				s.conv_done = true
				s.conv_filename = c.name:gsub("%.png$", "") .. ".mts"
			else
				s.status = "Error: " .. (result or "unknown")
			end
		end
		c.schem = nil
		return
	end

	local total_rows = (c.mode == "floor" or (c.mode:sub(1,4) == "wall" and c.wall_dir == "x")) and c.out_h or c.out_w
	local remaining = (c.mode:sub(1,4) == "wall" and c.wall_dir == "z") and (c.out_w - c.z) or (c.y + 1)
	local pct = math.floor((total_rows - remaining) * 100 / total_rows)
	local prev_pct = s._last_pct or -1
	if pct - prev_pct >= 5 then
		s._last_pct = pct
	end
	s._conv_pct = pct
	s.status = "Converting " .. pct .. "%..."
	if pct > 0 and pct % 10 == 0 and pct ~= s._last_refresh then
		s._last_refresh = pct
		show_browser_form(3)
	end
	core.after(0, mapart.process_conv_chunk)
end
