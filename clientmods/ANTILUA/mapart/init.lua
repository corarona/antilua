local modname = core.get_current_modname()
local modpath
if type(core.get_modpath_real) == "function" then
	modpath = core.get_modpath_real(modname)
else
	modpath = core.get_modpath(modname)
end

-- Build flat palette from colors.json
local palette = {}

local function load_palette()
	local json_path = modpath .. "/colors.json"
	local json = core.read_file(json_path)
	if not json then
		local err = "mapart: colors.json not found at " .. json_path
		core.log(err)
		ws.notify(err, ws.NOTIFY_ERROR)
		return false
	end
	local ok2, colors = pcall(core.parse_json, json)
	if not ok2 or not colors then
		local err = "mapart: failed to parse colors.json: " .. tostring(colors)
		core.log(err)
		ws.notify(err, ws.NOTIFY_ERROR)
		return false
	end

	if type(colors) ~= "table" then
		local err = "mapart: colors.json parsed to " .. type(colors)
		core.log(err)
		ws.notify(err, ws.NOTIFY_ERROR)
		return false
	end

	palette = {}
	for node_name, color_data in pairs(colors) do
		if type(color_data) ~= "table" then
			-- skip unexpected format
		-- Single color: [r,g,b] or [r,g,b,a,...]
		elseif type(color_data[1]) == "number" then
			table.insert(palette, {
				name = node_name,
				param2 = 0,
				r = color_data[1],
				g = color_data[2],
				b = color_data[3],
			})
		-- Multi-color (param2-based): [[r,g,b], [r,g,b], ...]
		elseif type(color_data[1]) == "table" then
			for param2, entry in ipairs(color_data) do
				table.insert(palette, {
					name = node_name,
					param2 = param2 - 1,
					r = entry[1],
					g = entry[2],
					b = entry[3],
				})
			end
		end
	end
	core.log("mapart: loaded " .. #palette .. " palette entries")

	-- Apply nlist filtering
	if nlist and nlist.get then
		local exclude = nlist.get("mapart_exclude")
		if #exclude > 0 then
			local exclude_set = {}
			for _, v in ipairs(exclude) do
				exclude_set[v] = true
			end
			local filtered = {}
			for _, entry in ipairs(palette) do
				if not exclude_set[entry.name] then
					table.insert(filtered, entry)
				end
			end
			palette = filtered
		end
	end

	ws.notify("mapart: loaded " .. #palette .. " palette entries", ws.NOTIFY_INFO)
	return true
end

-- sRGB gamma to linear
local function srgb_to_linear(c)
	c = c / 255
	if c <= 0.04045 then
		return c / 12.92
	end
	return ((c + 0.055) / 1.055) ^ 2.4
end

-- Find closest palette entry (RGB Euclidean distance)
local function find_closest(r, g, b, use_gamma, pal_override)
	local pal = pal_override or palette
	local best_idx, best_dist = nil, math.huge
	for i, entry in ipairs(pal) do
		local dr, dg, db
		if use_gamma then
			dr = srgb_to_linear(r) - srgb_to_linear(entry.r)
			dg = srgb_to_linear(g) - srgb_to_linear(entry.g)
			db = srgb_to_linear(b) - srgb_to_linear(entry.b)
		else
			dr = r - entry.r
			dg = g - entry.g
			db = b - entry.b
		end
		local dist = dr*dr + dg*dg + db*db
		if dist < best_dist then
			best_dist = dist
			best_idx = i
		end
		if dist == 0 then break end
	end
	return pal[best_idx]
end

-- Floyd-Steinberg dithering
local function floyd_steinberg(errors, w, h, x, y, dr, dg, db)
	local function add_err(ox, oy, factor)
		local ex, ey = x + ox, y + oy
		if ex >= 0 and ex < w and ey >= 0 and ey < h then
			local idx = ey * w + ex
			errors[idx * 3 + 1] = errors[idx * 3 + 1] + dr * factor
			errors[idx * 3 + 2] = errors[idx * 3 + 2] + dg * factor
			errors[idx * 3 + 3] = errors[idx * 3 + 3] + db * factor
		end
	end
	add_err(1, 0, 7/16)
	add_err(-1, 1, 3/16)
	add_err(0, 1, 5/16)
	add_err(1, 1, 1/16)
end

-- Sample a pixel from the source image (nearest-neighbor or bilinear)
local function sample_px(data, sw, sh, px, py, dw, dh, bilinear)
	if bilinear then
		local sx = px * sw / dw
		local sy = py * sh / dh
		local x1 = math.min(math.floor(sx), sw - 1)
		local y1 = math.min(math.floor(sy), sh - 1)
		local x2 = math.min(x1 + 1, sw - 1)
		local y2 = math.min(y1 + 1, sh - 1)
		local fx = sx - x1; local fy = sy - y1
		local function get(x, y)
			local idx = (y * sw + x) * 4 + 1
			return string.byte(data, idx), string.byte(data, idx + 1),
				string.byte(data, idx + 2), string.byte(data, idx + 3)
		end
		local r1,g1,b1,a1 = get(x1, y1)
		local r2,g2,b2,a2 = get(x2, y1)
		local r3,g3,b3,a3 = get(x1, y2)
		local r4,g4,b4,a4 = get(x2, y2)
		return (1-fx)*(1-fy)*r1 + fx*(1-fy)*r2 + (1-fx)*fy*r3 + fx*fy*r4,
			(1-fx)*(1-fy)*g1 + fx*(1-fy)*g2 + (1-fx)*fy*g3 + fx*fy*g4,
			(1-fx)*(1-fy)*b1 + fx*(1-fy)*b2 + (1-fx)*fy*b3 + fx*fy*b4,
			(1-fx)*(1-fy)*a1 + fx*(1-fy)*a2 + (1-fx)*fy*a3 + fx*fy*a4
	end
	local sx = math.floor(px * sw / dw)
	local sy = math.floor(py * sh / dh)
	sx = math.min(sx, sw - 1); sy = math.min(sy, sh - 1)
	local idx = (sy * sw + sx) * 4 + 1
	return string.byte(data, idx), string.byte(data, idx + 1),
		string.byte(data, idx + 2), string.byte(data, idx + 3)
end

-- Convert decoded image data to an MTS schematic
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
				goto skip
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
			::skip::
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
					goto skip_x
				end
				local best = find_closest(r, g, b, use_gamma, pal)
				if best then
					local dr = r - best.r; local dg = g - best.g; local db = b - best.b
					if use_dither then floyd_steinberg(errors, out_w, out_h, x, y, dr, dg, db) end
					table.insert(schem.data, { name = best.name, prob = 254, param2 = best.param2 })
				else
					table.insert(schem.data, { name = "air", prob = 0, param2 = 0 })
				end
				::skip_x::
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
					goto skip_z
				end
				local best = find_closest(r, g, b, use_gamma, pal)
				if best then
					local dr = r - best.r; local dg = g - best.g; local db = b - best.b
					if use_dither then floyd_steinberg(errors, out_w, out_h, z, y, dr, dg, db) end
					table.insert(schem.data, { name = best.name, prob = 254, param2 = best.param2 })
				else
					table.insert(schem.data, { name = "air", prob = 0, param2 = 0 })
				end
				::skip_z::
			end
		end
	end
	return schem
end

-- Save MTS to schematics dir and load into schembuilder
local function save_and_load_mts(schem, name, use_pos)
	local mts_data = core.serialize_schematic(schem, "mts")
	if not mts_data then
		return false, "Failed to serialize schematic"
	end

	local schem_dir = core.settings:get("mapart_output_dir")
		or "/tmp/antilua_mapart"

	if type(core.mkdir) == "function" then
		core.mkdir(schem_dir)
	end

	local filepath = schem_dir .. "/" .. name:gsub("%.png$", "") .. ".mts"
	local ok, err = core.write_file(filepath, mts_data)
	if not ok then
		return false, err or "Failed to write MTS file"
	end

	-- Try to load into schembuilder if available
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

-- State for formspec
local state = {
	png_list = {},
	png_dir = core.settings:get("mapart.png_dir") or "/tmp/antilua_mapart",
	selected = 0,
	preview = "",
	out_w = 128,
	out_h = 128,
	dither = false,
	gamma = false,
	invonly = false,
	grid_new = core.settings:get_bool("mapart_grid_new", false),
	mode = "floor",
	filter = "nearest",
	status = "",
}

-- Mapart formspec tab (called from schembuilder)
get_mapart_tab = function(fs, tab)
	local s = state
	local preview = s.preview or ""

	-- Directory selector + refresh
	fs = fs .. "field[0.3,0.3;7,0.6;mapart_dir;;" ..
		core.formspec_escape(s.png_dir) .. "]" ..
		"button[7.5,0.3;2.2,0.6;mapart_refresh;Refresh]"

	-- PNG file list
	if #s.png_list > 0 then
		local items = {}
		for i, f in ipairs(s.png_list) do
			table.insert(items, core.formspec_escape(f))
		end
		fs = fs .. "textlist[0.3,1.2;9,3;mapart_list;" ..
			table.concat(items, ",") .. ";" .. s.selected .. "]"
	end

	-- Preview image
	if preview ~= "" then
		fs = fs .. "image[0.3,4.4;4,4;" .. preview .. "]"
	end

	-- Options
	local mode_idx = ({ floor = 1, wall_x = 2, wall_z = 3 })[s.mode] or 1
	fs = fs .. "field[5,4.8;1.5,0.6;mapart_w;;" .. s.out_w .. "]" ..
		"label[5,4.3;W]" ..
		"field[6.7,4.8;1.5,0.6;mapart_h;;" .. s.out_h .. "]" ..
		"label[6.7,4.3;H]" ..
		"dropdown[5,5.5;3.5;mapart_mode;Floor,Wall (X),Wall (Z);" .. mode_idx .. "]" ..
		"dropdown[5,6.2;3.5;mapart_filter;Nearest,Bilinear;" .. (s.filter == "bilinear" and 2 or 1) .. "]" ..
		"checkbox[5,6.9;mapart_dither;Dither;" .. (s.dither and "true" or "false") .. "]" ..
		"checkbox[5,7.6;mapart_gamma;Gamma;" .. (s.gamma and "true" or "false") .. "]" ..
		"checkbox[5,8.3;mapart_invonly;Inventory only;" .. (s.invonly and "true" or "false") .. "]"

	if s.mode == "floor" then
		fs = fs .. "checkbox[5,9.0;mapart_grid_new;New grid;" .. (s.grid_new and "true" or "false") .. "]"
	end

	-- Convert button + status
	local btn_y = s.mode == "floor" and 9.7 or 9.0
	fs = fs .. "button[0.3," .. btn_y .. ";9,0.8;mapart_convert;Convert]"
	local st_y = btn_y + 0.9
	if s.status ~= "" then
		fs = fs .. "label[0.3," .. st_y .. ";" .. core.formspec_escape(s.status) .. "]"
	end

	return fs
end

-- Handle mapart tab events (called from schembuilder)
handle_mapart_events = function(fields)
	local s = state

	if fields.mapart_refresh then
		local dir = fields.mapart_dir or s.png_dir
		s.png_dir = dir
		local files = core.get_dir_list(dir, false) or {}
		s.png_list = {}
		for _, f in ipairs(files) do
			if f:match("%.png$") then
				table.insert(s.png_list, f)
			end
		end
		s.selected = 0
		s.preview = ""
		return true
	end

	if fields.mapart_list then
		local event = fields.mapart_list
		local idx
		if event:match("^DCL:") then
			idx = tonumber(event:match("DCL:(%d+)"))
		else
			idx = tonumber(event)
		end
		if idx and s.png_list[idx] then
			s.selected = idx
			-- Show color-matched preview
			local filepath = s.png_dir .. "/" .. s.png_list[idx]
			local ok, data = pcall(core.read_file, filepath)
			if ok and data then
				local ok2, img = pcall(core.decode_image, data)
				if ok2 and img then
					local pw, ph = 64, 64
					local pixels = {}
					for y = 0, ph - 1 do
						for x = 0, pw - 1 do
							local r,g,b,a = sample_px(img.data, img.width, img.height, x, y, pw, ph, false)
							if a < 128 then
								pixels[#pixels + 1] = 0; pixels[#pixels + 1] = 0
								pixels[#pixels + 1] = 0; pixels[#pixels + 1] = 0
							else
								local best = find_closest(r, g, b, false, palette)
								if best then
									pixels[#pixels + 1] = best.r
									pixels[#pixels + 1] = best.g
									pixels[#pixels + 1] = best.b
									pixels[#pixels + 1] = 255
								else
									pixels[#pixels + 1] = r; pixels[#pixels + 1] = g
									pixels[#pixels + 1] = b; pixels[#pixels + 1] = 255
								end
							end
						end
					end
					local px_str = string.char(unpack(pixels))
					local png_data = core.encode_png(pw, ph, px_str, -1)
					if png_data then
						s.preview = "[png:" .. core.encode_base64(png_data)
					end
				end
			end
		end
		return true
	end

	if fields.mapart_convert then
		local dir = fields.mapart_dir or s.png_dir
		local idx = s.selected
		if not dir or idx == 0 or not s.png_list[idx] then
			s.status = "Select a PNG file first"
			return true
		end

		local name = s.png_list[idx]
		local filepath = dir .. "/" .. name
		local ok, data = pcall(core.read_file, filepath)
		if not ok or not data then
			s.status = "Failed to read file"
			return true
		end

		local ok2, img = pcall(core.decode_image, data)
		if not ok2 or not img then
			s.status = "Failed to decode image"
			return true
		end

		local out_w = tonumber(fields.mapart_w) or img.width
		local out_h = tonumber(fields.mapart_h) or img.height
		local do_dither = fields.mapart_dither == "true"
		local do_gamma = fields.mapart_gamma == "true"
		local do_invonly = fields.mapart_invonly == "true"
		local mode_names = { "floor", "wall_x", "wall_z" }
		local mode = mode_names[tonumber(fields.mapart_mode) or 1]
		local filter_names = { "nearest", "bilinear" }
		local filter = filter_names[tonumber(fields.mapart_filter) or 1]

		s.out_w = out_w
		s.out_h = out_h
		s.dither = do_dither
		s.gamma = do_gamma
		s.invonly = do_invonly
		s.mode = mode
		s.filter = filter

		local pal = palette
		if do_invonly then
			pal = build_inv_palette()
			if not pal or #pal == 0 then
				s.status = "No usable blocks in inventory"
				return true
			end
		end

		-- Start chunked conversion
		s.status = "Converting..."
		s._conv = {
			pal = pal, name = name, mode = mode,
			out_w = out_w, out_h = out_h,
			filter = filter,
			dither = do_dither, gamma = do_gamma,
			grid_new = fields.mapart_grid_new == "true",
			wall_dir = mode == "wall_x" and "x" or "z",
			img = img,
			schem = { size = { x = out_w, y = mode:sub(1,4) == "wall" and out_h or 1, z = mode:sub(1,4) == "wall" and (mode == "wall_z" and out_w or 1) or out_h }, data = {} },
			y = mode == "floor" and out_h - 1 or out_h - 1,
			z = 0,
			errors = {},
			air_count = 0,
		}
		if do_dither then
			for i = 1, out_w * out_h * 3 do s._conv.errors[i] = 0 end
		end
		if mode:sub(1,4) == "wall" then
			s._conv.schem.size.z = mode == "wall_z" and out_w or 1
			s._conv.schem.size.x = mode == "wall_x" and out_w or 1
		end
		core.after(0, function() process_conv_chunk() end)
		return true
	end

	return false
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
		-- Conversion complete
		s._conv = nil
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
		return
	end

	-- More rows remain
	local total_rows = (c.mode == "floor" or (c.mode:sub(1,4) == "wall" and c.wall_dir == "x")) and c.out_h or c.out_w
	local remaining = (c.mode:sub(1,4) == "wall" and c.wall_dir == "z") and (c.out_w - c.z) or (c.y + 1)
	local pct = math.floor((total_rows - remaining) * 100 / total_rows)
	s.status = "Converting " .. pct .. "%..."
	core.after(0, process_conv_chunk)
end

core.register_chatcommand("mapart", {
	params = "<path> [width] [height] [--dither] [--gamma] [--invonly] [--filter nearest|bilinear]",
	description = "Convert a PNG image to an MTS schematic using map colors",
	func = function(param)
		if param == "" then
			return false, "Usage: /mapart <path> [width] [height] [--dither] [--gamma] [--invonly] [--filter nearest|bilinear]"
		end

		local parts = {}
		for p in param:gmatch("%S+") do
			table.insert(parts, p)
		end

		local filepath = parts[1]
		local out_w, out_h
		local do_dither = false
		local do_gamma = false
		local do_invonly = false
		local do_grid_new = core.settings:get_bool("mapart_grid_new", false)
		local filter = "nearest"

		for i = 2, #parts do
			if parts[i] == "--dither" then
				do_dither = true
			elseif parts[i] == "--gamma" then
				do_gamma = true
			elseif parts[i] == "--invonly" then
				do_invonly = true
			elseif parts[i] == "--filter" then
				filter = parts[i + 1] or "nearest"
				i = i + 1
			elseif not out_w and not parts[i]:match("^%-%-") then
				out_w = tonumber(parts[i])
			elseif not parts[i]:match("^%-%-") then
				out_h = tonumber(parts[i])
			end
		end

		local ok, data = pcall(core.read_file, filepath)
		if not ok or not data then
			return false, "File not found: " .. filepath
		end

		local ok2, img = pcall(core.decode_image, data)
		if not ok2 or not img then
			return false, "Failed to decode image"
		end

		out_w = out_w or img.width
		out_h = out_h or img.height

		local ok, data = pcall(core.read_file, filepath)
		if not ok or not data then
			return false, "File not found: " .. filepath
		end

		local ok2, img = pcall(core.decode_image, data)
		if not ok2 or not img then
			return false, "Failed to decode image"
		end

		local pal = palette
		if do_invonly then
			pal = build_inv_palette()
			if not pal or #pal == 0 then
				return false, "No usable blocks in inventory"
			end
		end

		local schem = image_to_schem(img.width, img.height, img.data, {
			width = out_w,
			height = out_h,
			dither = do_dither,
			gamma = do_gamma,
			palette = pal,
			filter = filter,
		})

		if #schem.data == 0 then
			return false, "No non-transparent pixels found"
		end

		local grid_pos
		if core.localplayer then
			local p = core.localplayer:get_pos()
			if do_grid_new then
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

		local name = filepath:match("([^/]+)%.png$") or "mapart_output"
		local ok3, result = save_and_load_mts(schem, name .. ".png", grid_pos)
		if ok3 then
			return true, "Mapart saved: " .. result .. " (" .. #schem.data .. " nodes)"
		else
			return false, "Error: " .. (result or "unknown")
		end
	end,
})

core.register_chatcommand("mapart_wall", {
	params = "<path> [width] [height] [--direction x|z] [--dither] [--gamma] [--invonly] [--filter nearest|bilinear]",
	description = "Convert a PNG image to a vertical wall MTS schematic",
	func = function(param)
		if param == "" then
			return false, "Usage: /mapart_wall <path> [width] [height] [--direction x|z] [--dither] [--gamma] [--invonly] [--filter nearest|bilinear]"
		end

		local parts = {}
		for p in param:gmatch("%S+") do
			table.insert(parts, p)
		end

		local filepath = parts[1]
		local dir = "x"
		local do_dither = false
		local do_gamma = false
		local do_invonly = false
		local filter = "nearest"
		local args = {}

		for i = 2, #parts do
			if parts[i] == "--dither" then
				do_dither = true
			elseif parts[i] == "--gamma" then
				do_gamma = true
			elseif parts[i] == "--invonly" then
				do_invonly = true
			elseif parts[i] == "--direction" then
				dir = parts[i + 1] or "x"
				i = i + 1
			elseif parts[i] == "--filter" then
				filter = parts[i + 1] or "nearest"
				i = i + 1
			elseif not parts[i]:match("^%-%-") then
				table.insert(args, parts[i])
			end
		end

		local out_w = tonumber(args[1])
		local out_h = tonumber(args[2])

		local ok, data = pcall(core.read_file, filepath)
		if not ok or not data then
			return false, "File not found: " .. filepath
		end

		local ok2, img = pcall(core.decode_image, data)
		if not ok2 or not img then
			return false, "Failed to decode image"
		end

		out_w = out_w or img.width
		out_h = out_h or img.height

		local pal = palette
		if do_invonly then
			pal = build_inv_palette()
			if not pal or #pal == 0 then
				return false, "No usable blocks in inventory"
			end
		end

		local schem = image_to_wall_schem(img.width, img.height, img.data, {
			width = out_w,
			height = out_h,
			dither = do_dither,
			gamma = do_gamma,
			palette = pal,
			filter = filter,
			direction = dir,
		})

		if #schem.data == 0 then
			return false, "No non-transparent pixels found"
		end

		local name = filepath:match("([^/]+)%.png$") or "mapart_wall_output"
		local ok3, result = save_and_load_mts(schem, name .. ".png")
		if ok3 then
			return true, "Wall saved: " .. result .. " (" .. #schem.data .. " nodes)"
		else
			return false, "Error: " .. (result or "unknown")
		end
	end,
})

core.register_chatcommand("test_encode_png", {
	params = "<path>",
	description = "Test core.encode_png roundtrip: decode PNG, re-encode, save",
	func = function(param)
		if param == "" then
			return false, "Usage: /test_encode_png <path>"
		end
		local ok, data = pcall(core.read_file, param)
		if not ok or not data then
			return false, "File not found: " .. param
		end
		local ok2, img = pcall(core.decode_image, data)
		if not ok2 or not img then
			return false, "Failed to decode image"
		end

		local out = core.encode_png(img.width, img.height, img.data, -1)
		if not out then
			return false, "encode_png returned nil"
		end

		local outpath = "/tmp/test_encode_png_out.png"
		core.write_file(outpath, out)
		return true, string.format("encode_png ok: %dx%d -> %d bytes (input %d bytes)",
			img.width, img.height, #out, #data)
	end,
})

core.register_chatcommand("clear_particles", {
	params = "",
	description = "Clear all particles from the world (schembuilder previews etc.)",
	func = function()
		if type(core.clear_all_particles) == "function" then
			core.clear_all_particles()
			return true, "Particles cleared"
		end
		return false, "clear_all_particles not available"
	end,
})

-- Initialize palette (synchronous, mod load time)
pcall(load_palette)
