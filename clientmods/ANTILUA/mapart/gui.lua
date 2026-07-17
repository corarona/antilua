-- State for formspec
local state = {
	png_list = {},
	png_dir = core.settings:get("mapart.png_dir") or (core.get_data_path() .. "images"),
	selected = 0,
	preview = "",
	out_w = tonumber(core.settings:get("mapart_gui_w")) or 128,
	out_h = tonumber(core.settings:get("mapart_gui_h")) or 128,
	dither = core.settings:get_bool("mapart_gui_dither"),
	gamma = core.settings:get_bool("mapart_gui_gamma"),
	invonly = core.settings:get_bool("mapart_gui_invonly"),
	grid_new = core.settings:get_bool("mapart_grid_new", false),
	mode = core.settings:get("mapart_gui_mode") or "floor",
	filter = core.settings:get("mapart_gui_filter") or "nearest",
	max_colors = tonumber(core.settings:get("mapart_gui_max_colors")) or 0,
	status = "",
	conv_done = false,
	conv_filename = "",
}

-- Mapart formspec tab (called from schembuilder)
get_mapart_tab = function(fs, tab)
	local s = state
	local preview = s.preview or ""

	fs = fs .. "field[0.3,0.3;7,0.6;mapart_dir;;" ..
		core.formspec_escape(s.png_dir) .. "]" ..
		"button[7.5,0.3;2.2,0.6;mapart_refresh;Refresh]"

	if #s.png_list > 0 then
		local items = {}
		for i, f in ipairs(s.png_list) do
			table.insert(items, core.formspec_escape(f))
		end
		fs = fs .. "textlist[0.3,1.2;9,3;mapart_list;" ..
			table.concat(items, ",") .. ";" .. s.selected .. "]"
	end

	if preview ~= "" then
		fs = fs .. "image[0.3,4.4;4,4;" .. preview .. "]"
	end

	local mode_idx = ({ floor = 1, wall_x = 2, wall_z = 3 })[s.mode] or 1
	fs = fs .. "field[5,4.8;1.5,0.6;mapart_w;;" .. s.out_w .. "]" ..
		"label[5,4.3;W]" ..
		"field[6.7,4.8;1.5,0.6;mapart_h;;" .. s.out_h .. "]" ..
		"label[6.7,4.3;H]" ..
		"dropdown[5,5.5;3.5;mapart_mode;Floor,Wall (X),Wall (Z);" .. mode_idx .. "]" ..
		"dropdown[5,6.2;3.5;mapart_filter;Nearest,Bilinear;" .. (s.filter == "bilinear" and 2 or 1) .. "]" ..
		"checkbox[5,6.9;mapart_dither;Dither;" .. (s.dither and "true" or "false") .. "]" ..
		"checkbox[5,7.6;mapart_gamma;Gamma;" .. (s.gamma and "true" or "false") .. "]" ..
		"checkbox[5,8.3;mapart_invonly;Inventory only;" .. (s.invonly and "true" or "false") .. "]" ..
		"field[5.5,8.8;1.5,0.6;mapart_colors;;" .. (s.max_colors > 0 and s.max_colors or "") .. "]" ..
		"label[5,8.5;Colors (0=all)]"

	if s.mode == "floor" then
		fs = fs .. "checkbox[5,9.0;mapart_grid_new;New grid;" .. (s.grid_new and "true" or "false") .. "]"
	end

	local btn_y = s.mode == "floor" and 9.7 or 9.0
	fs = fs .. "button[0.3," .. btn_y .. ";9,0.8;mapart_convert;Convert]"
	local st_y = btn_y + 0.9
	if s.status ~= "" then
		fs = fs .. "label[0.3," .. st_y .. ";" .. core.formspec_escape(s.status) .. "]"
	end
	if s.conv_done and s.conv_filename ~= "" then
		fs = fs .. "button[0.3," .. (st_y + 0.6) .. ";9,0.8;mapart_view_builder;View in Schembuilder]"
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
			local filepath = s.png_dir .. "/" .. s.png_list[idx]
			local ok, data = pcall(core.read_file, filepath)
			if ok and data then
				local ok2, img = pcall(core.decode_image, data)
				if ok2 and img then
					local pw, ph = 200, 200
					local pixels = {}
					for y = 0, ph - 1 do
						for x = 0, pw - 1 do
							local r,g,b,a = sample_px(img.data, img.width, img.height, x, y, pw, ph, false)
							if a < 128 then
								pixels[#pixels + 1] = 0; pixels[#pixels + 1] = 0
								pixels[#pixels + 1] = 0; pixels[#pixels + 1] = 0
							else
								local best = find_closest(r, g, b, false, mapart.palette)
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

		local max_colors = tonumber(fields.mapart_colors) or 0
		s.max_colors = max_colors
		s.out_w = out_w
		s.out_h = out_h
		s.dither = do_dither
		s.gamma = do_gamma
		s.invonly = do_invonly
		s.mode = mode
		s.filter = filter
		s.conv_done = false
		s.conv_filename = ""

		-- Persist settings
		core.settings:set("mapart_gui_w", tostring(out_w))
		core.settings:set("mapart_gui_h", tostring(out_h))
		core.settings:set("mapart_gui_dither", do_dither and "true" or "false")
		core.settings:set("mapart_gui_gamma", do_gamma and "true" or "false")
		core.settings:set("mapart_gui_mode", mode)
		core.settings:set("mapart_gui_filter", filter)
		core.settings:set("mapart_gui_max_colors", tostring(max_colors))

		local pal = mapart.palette
		if do_invonly then
			pal = build_inv_palette()
			if not pal or #pal == 0 then
				s.status = "No usable blocks in inventory"
				return true
			end
		end
		if max_colors > 0 and #pal > max_colors then
			pal = reduce_palette(pal, max_colors)
		end

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

	if fields.mapart_view_builder then
		core.close_formspec("schembuilder:browser")
		-- Switch to schembuilder tab 0
		show_browser_form(0)
		return true
	end

	return false
end
