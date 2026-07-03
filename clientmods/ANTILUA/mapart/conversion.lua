-- Save MTS to schematics dir and load into schembuilder
local function save_and_load_mts(schem, name, use_pos)
	local mts_data = core.serialize_schematic(schem, "mts")
	if not mts_data then
		return false, "Failed to serialize schematic"
	end

	local schem_dir = core.settings:get("mapart_output_dir")
		or "/tmp/antilua_mapart"

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

-- Build a filtered palette with only nodes in the player's inventory (cached 1s)
local _inv_cache_time = 0
local _inv_cache_pal = nil
local function build_inv_palette()
	local now = os.clock()
	if now - _inv_cache_time < 1.0 and _inv_cache_pal then
		return _inv_cache_pal
	end
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
	for _, entry in ipairs(palette) do
		if types[entry.name] then
			table.insert(filtered, entry)
		end
	end
	_inv_cache_time = now
	_inv_cache_pal = filtered
	return filtered
end

-- Convert decoded image data to an MTS schematic (floor/painting)
local function image_to_schem(width, height, pixel_data, opts)
	opts = opts or {}
	local out_w = opts.width or 128
	local out_h = opts.height or 128
	local use_dither = opts.dither or false
	local use_gamma = opts.gamma or false
	local pal = opts.palette or palette
	local use_bilinear = opts.filter == "bilinear"
	local errors = {}
	if use_dither then
		for i = 1, out_w * out_h * 3 do
			errors[i] = 0
		end
	end

	local schem = {
		size = { x = out_w, y = 1, z = out_h },
		data = {}
	}

	for z = out_h - 1, 0, -1 do
		for x = 0, out_w - 1 do
			local r, g, b, a = sample_px(pixel_data, width, height, x, z, out_w, out_h, use_bilinear)

			if use_dither then
				local idx = z * out_w + x
				r = math.max(0, math.min(255, r + errors[idx * 3 + 1]))
				g = math.max(0, math.min(255, g + errors[idx * 3 + 2]))
				b = math.max(0, math.min(255, b + errors[idx * 3 + 3]))
			end

			if a < 128 then
				table.insert(schem.data, {
					name = "air",
					prob = 0,
					param2 = 0,
				})
				goto skip_floor
			end

			local best = find_closest(r, g, b, use_gamma, pal)
			if best then
				local dr = (r or 0) - best.r
				local dg = (g or 0) - best.g
				local db = (b or 0) - best.b

				if use_dither then
					floyd_steinberg(errors, out_w, out_h, x, z, dr, dg, db)
				end

				table.insert(schem.data, {
					name = best.name,
					prob = 254,
					param2 = best.param2,
				})
			else
				table.insert(schem.data, {
					name = "air",
					prob = 0,
					param2 = 0,
				})
			end
			::skip_floor::
		end
	end

	return schem
end

-- Convert decoded image data to a vertical wall MTS schematic
local function image_to_wall_schem(width, height, pixel_data, opts)
	opts = opts or {}
	local out_w = opts.width or width
	local out_h = opts.height or height
	local use_dither = opts.dither or false
	local use_gamma = opts.gamma or false
	local pal = opts.palette or palette
	local dir = opts.direction or "x"
	local use_bilinear = opts.filter == "bilinear"

	local errors = {}
	if use_dither then
		for i = 1, out_w * out_h * 3 do
			errors[i] = 0
		end
	end

	local schem
	if dir == "x" then
		schem = { size = { x = out_w, y = out_h, z = 1 }, data = {} }
		for y = out_h - 1, 0, -1 do
			for x = 0, out_w - 1 do
				local r, g, b, a = sample_px(pixel_data, width, height, x, y, out_w, out_h, use_bilinear)
				if use_dither then
					local idx = y * out_w + x
					r = math.max(0, math.min(255, r + errors[idx * 3 + 1]))
					g = math.max(0, math.min(255, g + errors[idx * 3 + 2]))
					b = math.max(0, math.min(255, b + errors[idx * 3 + 3]))
				end
				if a < 128 then
					table.insert(schem.data, { name = "air", prob = 0, param2 = 0 })
					goto skip_wall_x
				end
				local best = find_closest(r, g, b, use_gamma, pal)
				if best then
					local dr = r - best.r; local dg = g - best.g; local db = b - best.b
					if use_dither then floyd_steinberg(errors, out_w, out_h, x, y, dr, dg, db) end
					table.insert(schem.data, { name = best.name, prob = 254, param2 = best.param2 })
				else
					table.insert(schem.data, { name = "air", prob = 0, param2 = 0 })
				end
				::skip_wall_x::
			end
		end
	else
		schem = { size = { x = 1, y = out_h, z = out_w }, data = {} }
		for z = 0, out_w - 1 do
			for y = out_h - 1, 0, -1 do
				local r, g, b, a = sample_px(pixel_data, width, height, z, y, out_w, out_h, use_bilinear)
				if use_dither then
					local idx = y * out_w + z
					r = math.max(0, math.min(255, r + errors[idx * 3 + 1]))
					g = math.max(0, math.min(255, g + errors[idx * 3 + 2]))
					b = math.max(0, math.min(255, b + errors[idx * 3 + 3]))
				end
				if a < 128 then
					table.insert(schem.data, { name = "air", prob = 0, param2 = 0 })
					goto skip_wall_z
				end
				local best = find_closest(r, g, b, use_gamma, pal)
				if best then
					local dr = r - best.r; local dg = g - best.g; local db = b - best.b
					if use_dither then floyd_steinberg(errors, out_w, out_h, z, y, dr, dg, db) end
					table.insert(schem.data, { name = best.name, prob = 254, param2 = best.param2 })
				else
					table.insert(schem.data, { name = "air", prob = 0, param2 = 0 })
				end
				::skip_wall_z::
			end
		end
	end
	return schem
end

local function process_conv_chunk()
	local s = state
	local c = s._conv
	if not c then return end
	local chunk = 32
	local done = 0

	for batch = 1, chunk do
		if c.mode == "floor" then
			if c.y < 0 then done = 1; break end
			for x = 0, c.out_w - 1 do
				local r,g,b,a = sample_px(c.img.data, c.img.width, c.img.height, x, c.y, c.out_w, c.out_h, c.filter == "bilinear")
				if c.dither then
					local idx = c.y * c.out_w + x
					r = math.max(0, math.min(255, r + c.errors[idx*3+1]))
					g = math.max(0, math.min(255, g + c.errors[idx*3+2]))
					b = math.max(0, math.min(255, b + c.errors[idx*3+3]))
				end
				if a < 128 then
					table.insert(c.schem.data, { name = "air", prob = 0, param2 = 0 })
				else
					local best = find_closest(r, g, b, c.gamma, c.pal)
					if best then
						local dr = r - best.r; local dg = g - best.g; local db = b - best.b
						if c.dither then floyd_steinberg(c.errors, c.out_w, c.out_h, x, c.y, dr, dg, db) end
						table.insert(c.schem.data, { name = best.name, prob = 254, param2 = best.param2 })
					else
						table.insert(c.schem.data, { name = "air", prob = 0, param2 = 0 })
					end
				end
			end
			c.y = c.y - 1
		else
			local dir = c.wall_dir
			if dir == "x" then
				if c.y < 0 then done = 1; break end
				for x = 0, c.out_w - 1 do
					local r,g,b,a = sample_px(c.img.data, c.img.width, c.img.height, x, c.y, c.out_w, c.out_h, c.filter == "bilinear")
					if c.dither then
						local idx = c.y * c.out_w + x
						r = math.max(0, math.min(255, r + c.errors[idx*3+1]))
						g = math.max(0, math.min(255, g + c.errors[idx*3+2]))
						b = math.max(0, math.min(255, b + c.errors[idx*3+3]))
					end
					if a < 128 then
						table.insert(c.schem.data, { name = "air", prob = 0, param2 = 0 })
					else
						local best = find_closest(r, g, b, c.gamma, c.pal)
						if best then
							local dr = r - best.r; local dg = g - best.g; local db = b - best.b
							if c.dither then floyd_steinberg(c.errors, c.out_w, c.out_h, x, c.y, dr, dg, db) end
							table.insert(c.schem.data, { name = best.name, prob = 254, param2 = best.param2 })
						else
							table.insert(c.schem.data, { name = "air", prob = 0, param2 = 0 })
						end
					end
				end
				c.y = c.y - 1
			else
				if c.z >= c.out_w then done = 1; break end
				for y = c.out_h - 1, 0, -1 do
					local r,g,b,a = sample_px(c.img.data, c.img.width, c.img.height, c.z, y, c.out_w, c.out_h, c.filter == "bilinear")
					if c.dither then
						local idx = y * c.out_w + c.z
						r = math.max(0, math.min(255, r + c.errors[idx*3+1]))
						g = math.max(0, math.min(255, g + c.errors[idx*3+2]))
						b = math.max(0, math.min(255, b + c.errors[idx*3+3]))
					end
					if a < 128 then
						table.insert(c.schem.data, { name = "air", prob = 0, param2 = 0 })
					else
						local best = find_closest(r, g, b, c.gamma, c.pal)
						if best then
							local dr = r - best.r; local dg = g - best.g; local db = b - best.b
							if c.dither then floyd_steinberg(c.errors, c.out_w, c.out_h, c.z, y, dr, dg, db) end
							table.insert(c.schem.data, { name = best.name, prob = 254, param2 = best.param2 })
						else
							table.insert(c.schem.data, { name = "air", prob = 0, param2 = 0 })
						end
					end
				end
				c.z = c.z + 1
			end
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
				local p = core.localplayer:get_pos()
				if c.grid_new then
					grid_pos = {
						x = math.floor((p.x - 63) / 128) * 128 + 64,
						y = math.floor(p.y),
						z = math.floor((p.z + 63) / 128) * 128 - 64,
					}
				else
					grid_pos = {
						x = math.floor(p.x / 128) * 128,
						y = math.floor(p.y),
						z = math.floor(p.z / 128) * 128,
					}
				end
			end
			local ok3, result = save_and_load_mts(c.schem, c.name, grid_pos)
			if ok3 then s.status = "Saved: " .. result else s.status = "Error: " .. (result or "unknown") end
		else
			local ok3, result = save_and_load_mts(c.schem, c.name)
			if ok3 then s.status = "Saved: " .. result else s.status = "Error: " .. (result or "unknown") end
		end
		c.schem = nil
		return
	end

	local total_rows = (c.mode == "floor" or (c.mode:sub(1,4) == "wall" and c.wall_dir == "x")) and c.out_h or c.out_w
	local remaining = (c.mode:sub(1,4) == "wall" and c.wall_dir == "z") and (c.out_w - c.z) or (c.y + 1)
	local pct = math.floor((total_rows - remaining) * 100 / total_rows)
	s.status = "Converting " .. pct .. "%..."
	core.after(0, process_conv_chunk)
end
