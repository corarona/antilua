local modname = core.get_current_modname()
local modpath = core.get_modpath_real(modname)

-- Module-scoped palette shared by all sub-files
mapart = {}
mapart.palette = {}
mapart.max_colors = tonumber(core.settings:get("mapart_max_colors")) or 0

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

	mapart.palette = {}
	for node_name, color_data in pairs(colors) do
		if type(color_data) ~= "table" then
		elseif type(color_data[1]) == "number" then
			local entry = {
				name = node_name,
				param2 = 0,
				r = color_data[1],
				g = color_data[2],
				b = color_data[3],
			}
			if color_data[4] then
				entry.a = color_data[4]
				if color_data[5] then
					entry.param2 = color_data[5]
				end
			end
			table.insert(mapart.palette, entry)
		elseif type(color_data[1]) == "table" then
			for param2, sub in ipairs(color_data) do
				local entry = {
					name = node_name,
					param2 = param2 - 1,
					r = sub[1],
					g = sub[2],
					b = sub[3],
				}
				if sub[4] then
					entry.a = sub[4]
					if sub[5] then
						entry.param2 = sub[5]
					end
				end
				table.insert(mapart.palette, entry)
			end
		end
	end
	if nlist and nlist.get then
		local exclude = nlist.get("mapart_exclude")
		if #exclude > 0 then
			local exclude_set = {}
			for _, v in ipairs(exclude) do
				exclude_set[v] = true
			end
			local filtered = {}
			for _, entry in ipairs(mapart.palette) do
				if not exclude_set[entry.name] then
					table.insert(filtered, entry)
				end
			end
			mapart.palette = filtered
		end
	end

	ws.notify("mapart: loaded " .. #mapart.palette .. " palette entries", ws.NOTIFY_INFO)
	return true
end

function mapart.compute_grid_pos(player_pos, use_new_grid)
	if not player_pos then return nil end
	if use_new_grid then
		return {
			x = math.floor((player_pos.x - 63) / 128) * 128 + 64,
			y = math.floor(player_pos.y),
			z = math.floor((player_pos.z + 63) / 128) * 128 - 64,
		}
	else
		return {
			x = math.floor(player_pos.x / 128) * 128,
			y = math.floor(player_pos.y),
			z = math.floor(player_pos.z / 128) * 128,
		}
	end
end

-- Load sub-modules (use get_modpath for VFS-compatible dofile paths)
local vfspath = core.get_modpath(modname) or modpath
dofile(vfspath .. "/palette.lua")
dofile(vfspath .. "/conversion.lua")
dofile(vfspath .. "/gui.lua")


local function apply_max_colors(pal)
	local maxc = mapart.max_colors
	if maxc and maxc > 0 and #pal > maxc then
		return mapart.reduce_palette(pal, maxc)
	end
	return pal
end

local MAX_MAPART_PIXELS = 1024 * 1024

core.register_chatcommand("mapart", {
	params = "<path> [width] [height] [--dither] [--gamma] [--invonly] [--grid_new] [--filter nearest|bilinear] [--colors N]",
	description = "Convert a PNG image to an MTS schematic using map colors",
	func = function(param)
		if param == "" then
			return false, "Usage: /mapart <path> [width] [height] [--dither] [--gamma] [--invonly] [--grid_new] [--filter nearest|bilinear] [--colors N]"
		end

		local parts = {}
		for p in param:gmatch("%S+") do
			table.insert(parts, p)
		end

		local filepath = parts[1]
		if filepath:find("%.%.") then
			return false, "Invalid path"
		end
		if not filepath:find("/") then
			filepath = core.get_data_path() .. "/images/" .. filepath
		end
		local out_w, out_h
		local do_dither = false
		local do_gamma = false
		local do_invonly = false
		local do_grid_new = core.settings:get_bool("mapart_grid_new", false)
		local filter = "nearest"
		local max_colors = mapart.max_colors

		for i = 2, #parts do
			if parts[i] == "--dither" then
				do_dither = true
			elseif parts[i] == "--gamma" then
				do_gamma = true
			elseif parts[i] == "--invonly" then
				do_invonly = true
			elseif parts[i] == "--grid_new" then
				do_grid_new = true
			elseif parts[i] == "--colors" then
				max_colors = tonumber(parts[i + 1]) or max_colors
				i = i + 1
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

		if out_w * out_h > MAX_MAPART_PIXELS then
			return false, "Image too large: " .. out_w .. "x" .. out_h .. " (" .. (out_w * out_h) .. " pixels, max " .. MAX_MAPART_PIXELS .. ")"
		end

		local pal = mapart.palette
		if do_invonly then
			pal = mapart.build_inv_palette()
			if not pal or #pal == 0 then
				return false, "No usable blocks in inventory"
			end
		end
		pal = apply_max_colors(pal)

		local schem = mapart.image_to_schem(img.width, img.height, img.data, {
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
			grid_pos = mapart.compute_grid_pos(core.localplayer:get_pos(), do_grid_new)
		end

		local name = filepath:match("([^/]+)%.png$") or "mapart_output"
		local ok3, result = mapart.save_and_load_mts(schem, name .. ".png", grid_pos)
		if ok3 then
			return true, "Mapart saved: " .. result .. " (" .. #schem.data .. " nodes)"
		else
			return false, "Error: " .. (result or "unknown")
		end
	end,
})

core.register_chatcommand("mapart_wall", {
	params = "<path> [width] [height] [--direction x|z] [--dither] [--gamma] [--invonly] [--filter nearest|bilinear] [--colors N]",
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
		if filepath:find("%.%.") then
			return false, "Invalid path"
		end
		if not filepath:find("/") then
			filepath = core.get_data_path() .. "/images/" .. filepath
		end
		local dir = "x"
		local do_dither = false
		local do_gamma = false
		local do_invonly = false
		local filter = "nearest"
		local max_colors = mapart.max_colors
		local args = {}

		for i = 2, #parts do
			if parts[i] == "--dither" then
				do_dither = true
			elseif parts[i] == "--gamma" then
				do_gamma = true
			elseif parts[i] == "--invonly" then
				do_invonly = true
			elseif parts[i] == "--colors" then
				max_colors = tonumber(parts[i + 1]) or max_colors
				i = i + 1
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

		if out_w * out_h > MAX_MAPART_PIXELS then
			return false, "Image too large: " .. out_w .. "x" .. out_h .. " (" .. (out_w * out_h) .. " pixels, max " .. MAX_MAPART_PIXELS .. ")"
		end

		local pal = mapart.palette
		if do_invonly then
			pal = mapart.build_inv_palette()
			if not pal or #pal == 0 then
				return false, "No usable blocks in inventory"
			end
		end
		pal = apply_max_colors(pal)

		local schem = mapart.image_to_wall_schem(img.width, img.height, img.data, {
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
		local ok3, result = mapart.save_and_load_mts(schem, name .. ".png")
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
		if param:find("%.%.") then
			return false, "Invalid path"
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

		local out_dir = core.settings:get("mapart_output_dir") or "/tmp/antilua_mapart"
		local outpath = out_dir .. "/test_encode_png_out.png"
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
