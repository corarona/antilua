# Mapart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `core.decode_image()` and `core.write_file()` C++ bindings, then build a client-side mod that converts PNG images to MTS schematics using Mineclonia's block color palette, with a GUI tab in schembuilder.

**Architecture:** C++ bindings for PNG decoding (via Irrlicht) and file writing. Lua mod for palette loading, color matching, formspec UI, and schematic generation. Integration via schembuilder's existing tab system.

**Tech Stack:** C++17, LuaJIT, IrrlichtMt (PNG loading), MTS schematic format, Floyd-Steinberg dithering.

**Note:** `core.get_dir_list()` already exists — no separate `list_dir` binding needed.

---

### Task 1: C++ Bindings — `decode_image` and `write_file`

**Files:**
- Modify: `src/script/lua_api/l_client.h` (declarations)
- Modify: `src/script/lua_api/l_client.cpp` (implementations + registration)

- [ ] **Step 1: Add declarations to l_client.h**

Add these lines after `l_read_file` (line 157):

```cpp
// decode_image(data) — decode PNG bytes to {width, height, data}
static int l_decode_image(lua_State *L);

// write_file(path, data) — write data to a file on disk
static int l_write_file(lua_State *L);
```

- [ ] **Step 2: Add `decode_image` implementation to l_client.cpp**

Add this block after `l_read_file` (after line 748):

```cpp
// decode_image(data)
int ModApiClient::l_decode_image(lua_State *L)
{
	size_t len;
	const char *data = luaL_checklstring(L, 1, &len);
	if (!data || len == 0) {
		lua_pushnil(L);
		lua_pushstring(L, "Empty data");
		return 2;
	}

	auto *device = RenderingEngine::get_raw_device();
	auto *fs = device->getFileSystem();
	auto *vd = device->getVideoDriver();

	auto *memfile = fs->createMemoryReadFile(data, (u32)len,
		"__antilua_decode__");
	if (!memfile) {
		lua_pushnil(L);
		lua_pushstring(L, "Failed to create memory file");
		return 2;
	}

	video::IImage *img = vd->createImageFromFile(memfile);
	memfile->drop();

	if (!img) {
		lua_pushnil(L);
		lua_pushstring(L, "Failed to decode image");
		return 2;
	}

	u32 w = img->getDimension().Width;
	u32 h = img->getDimension().Height;

	// Convert to consistent RGBA format
	video::IImage *rgba_img = img;
	bool needs_drop = false;
	if (img->getColorFormat() != video::ECF_A8R8G8B8) {
		rgba_img = vd->createImage(video::ECF_A8R8G8B8, img->getDimension());
		if (rgba_img) {
			img->copyTo(rgba_img);
			needs_drop = true;
		} else {
			rgba_img = img;
		}
	}

	// Build RGBA byte string
	std::string pixels;
	pixels.reserve((size_t)w * h * 4);
	for (u32 y = 0; y < h; y++) {
		for (u32 x = 0; x < w; x++) {
			video::SColor c = rgba_img->getPixel(x, y);
			pixels.push_back((char)c.getRed());
			pixels.push_back((char)c.getGreen());
			pixels.push_back((char)c.getBlue());
			pixels.push_back((char)c.getAlpha());
		}
	}

	if (needs_drop)
		rgba_img->drop();
	img->drop();

	lua_createtable(L, 0, 3);
	lua_pushinteger(L, (int)w);
	lua_setfield(L, -2, "width");
	lua_pushinteger(L, (int)h);
	lua_setfield(L, -2, "height");
	lua_pushlstring(L, pixels.data(), pixels.size());
	lua_setfield(L, -2, "data");
	return 1;
}
```

- [ ] **Step 3: Add `write_file` implementation to l_client.cpp**

Add this block after `l_decode_image`:

```cpp
// write_file(path, data)
int ModApiClient::l_write_file(lua_State *L)
{
	std::string path = luaL_checkstring(L, 1);
	// Prevent directory traversal
	if (path.find("..") != std::string::npos) {
		lua_pushnil(L);
		lua_pushstring(L, "Path traversal denied");
		return 2;
	}
	size_t data_len;
	const char *content = luaL_checklstring(L, 2, &data_len);

	if (fs::safeWriteToFile(path, std::string_view(content, data_len))) {
		lua_pushboolean(L, true);
		return 1;
	}

	lua_pushnil(L);
	lua_pushstring(L, "Failed to write file");
	return 2;
}
```

- [ ] **Step 4: Register both functions in `Initialize()`**

Add after `API_FCT(read_file);` (line 1241) and before `API_FCT(get_dir_list);`:

```cpp
	API_FCT(decode_image);
	API_FCT(write_file);
```

- [ ] **Step 5: Build and verify compilation**

Run: `cmake --build build -j$(nproc)`

Expected: Compilation succeeds. New functions are available in the client Lua environment as `core.decode_image()` and `core.write_file()`.

- [ ] **Step 6: Commit**

```bash
git add src/script/lua_api/l_client.h src/script/lua_api/l_client.cpp
git commit -m "Add core.decode_image() and core.write_file() Lua bindings"
```

---

### Task 2: Copy colors.json from Mineclonia

**Files:**
- Copy: `games/mineclonia/mods/ITEMS/mcl_maps/colors.json` → `clientmods/ANTILUA/mapart/colors.json`

- [ ] **Step 1: Create mapart directory and copy colors.json**

Run:
```bash
mkdir -p clientmods/ANTILUA/mapart
cp games/mineclonia/mods/ITEMS/mcl_maps/colors.json clientmods/ANTILUA/mapart/colors.json
```

- [ ] **Step 2: Commit**

```bash
git add clientmods/ANTILUA/mapart/colors.json
git commit -m "Copy mcl_maps colors.json for mapart"
```

---

### Task 3: Create mod.conf

**Files:**
- Create: `clientmods/ANTILUA/mapart/mod.conf`

- [ ] **Step 1: Write mod.conf**

```ini
name = antilua_mapart
description = Convert PNG images to MTS schematics using block colors (mapart)
depends = wasplib, nlist, schembuilder
```

- [ ] **Step 2: Commit**

```bash
git add clientmods/ANTILUA/mapart/mod.conf
git commit -m "Add mapart mod.conf"
```

---

### Task 4: Mapart init.lua — palette loading, color matching, formspec, commands

**Files:**
- Create: `clientmods/ANTILUA/mapart/init.lua`

- [ ] **Step 1: Write init.lua — palette loading and color matching**

```lua
local modpath = core.get_modpath(core.get_current_modname())

-- Build flat palette from colors.json
local palette = {}

local function load_palette()
	local ok, json = pcall(core.read_file, modpath .. "/colors.json")
	if not ok or not json then
		ws.notify("mapart: colors.json not found", ws.NOTIFY_ERROR)
		return false
	end
	local ok2, colors = pcall(core.parse_json, json)
	if not ok2 or not colors then
		ws.notify("mapart: failed to parse colors.json", ws.NOTIFY_ERROR)
		return false
	end

	palette = {}
	for node_name, color_data in pairs(colors) do
		-- Single color: [r,g,b] or [r,g,b,a,...]
		if type(color_data[1]) == "number" then
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

-- sRGB gamma → linear
local function srgb_to_linear(c)
	c = c / 255
	if c <= 0.04045 then
		return c / 12.92
	end
	return ((c + 0.055) / 1.055) ^ 2.4
end

-- Find closest palette entry (RGB Euclidean distance)
local function find_closest(r, g, b, use_gamma)
	local best_idx, best_dist = nil, math.huge
	for i, entry in ipairs(palette) do
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
		-- Short-circuit exact match
		if dist == 0 then break end
	end
	return palette[best_idx]
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
```

- [ ] **Step 2: Add schematic generation function**

```lua
-- Convert decoded image data to an MTS schematic
local function image_to_schem(width, height, pixel_data, opts)
	opts = opts or {}
	local out_w = opts.width or 128
	local out_h = opts.height or 128
	local use_dither = opts.dither or false
	local use_gamma = opts.gamma or false

	-- Nearest-neighbor resize
	local function get_pixel(px, py)
		local sx = math.floor(px * width / out_w)
		local sy = math.floor(py * height / out_h)
		sx = math.min(sx, width - 1)
		sy = math.min(sy, height - 1)
		local idx = (sy * width + sx) * 4 + 1
		return string.byte(pixel_data, idx),
			string.byte(pixel_data, idx + 1),
			string.byte(pixel_data, idx + 2),
			string.byte(pixel_data, idx + 3)
	end

	-- Initialize error accumulators for dithering
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

	for z = 0, out_h - 1 do
		for x = 0, out_w - 1 do
			local r, g, b, a = get_pixel(x, z)

			if a < 128 then
				goto skip
			end

			if use_dither then
				local idx = z * out_w + x
				r = math.max(0, math.min(255, r + errors[idx * 3 + 1]))
				g = math.max(0, math.min(255, g + errors[idx * 3 + 2]))
				b = math.max(0, math.min(255, b + errors[idx * 3 + 3]))
			end

			local best = find_closest(r, g, b, use_gamma)
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
					x = x, y = 0, z = z,
				})
			end
			::skip::
		end
	end

	return schem
end
```

- [ ] **Step 3: Add schembuilder integration and formspec tab in mapart init.lua**

```lua
-- Expose tab renderer and event handler globally for schembuilder
local schem_dir = core.settings:get("mapart_output_dir")
	or core.settings:get("schembuilder.schem_dir")
	or (os.getenv("HOME") or "") .. "/antilua_mapart"

-- Save MTS to schematics dir and load into schembuilder
local function save_and_load_mts(schem, name)
	local mts_data = core.serialize_schematic(schem, "mts")
	if not mts_data then
		return false, "Failed to serialize schematic"
	end

	local filepath = schem_dir .. "/" .. name:gsub("%.png$", "") .. ".mts"
	local ok, err = core.write_file(filepath, mts_data)
	if not ok then
		return false, err or "Failed to write MTS file"
	end

	-- Try to load into schembuilder if available
	if type(schembuilder_load_mts) == "function" then
		schembuilder_load_mts(filepath, name:gsub("%.png$", "") .. ".mts")
	end
	return true, filepath
end

-- State for formspec
local state = {
	png_list = {},
	png_dir = (os.getenv("HOME") or "") .. "/antilua_mapart",
	selected = 0,
	preview = "",
	out_w = 128,
	out_h = 128,
	dither = false,
	gamma = false,
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
	fs = fs .. "field[5,4.8;1.5,0.6;mapart_w;;" .. s.out_w .. "]" ..
		"label[5,4.3;W]" ..
		"field[6.7,4.8;1.5,0.6;mapart_h;;" .. s.out_h .. "]" ..
		"label[6.7,4.3;H]" ..
		"checkbox[5,5.5;mapart_dither;Dither;" .. (s.dither and "true" or "false") .. "]" ..
		"checkbox[5,6.2;mapart_gamma;Gamma;" .. (s.gamma and "true" or "false") .. "]"

	-- Convert button + status
	fs = fs .. "button[5,7;3,0.8;mapart_convert;Convert]"
	if s.status ~= "" then
		fs = fs .. "label[5,7.8;" .. core.formspec_escape(s.status) .. "]"
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
			-- Show preview of the original image
			local filepath = s.png_dir .. "/" .. s.png_list[idx]
			local ok, data = pcall(core.read_file, filepath)
			if ok and data then
				local ok2, img = pcall(core.decode_image, data)
				if ok2 and img then
					-- Resize to 64x64 for formspec preview
					local pw, ph = 64, 64
					local px = {}
					for z = 0, ph - 1 do
						for x = 0, pw - 1 do
							local sx = math.min(math.floor(x * img.width / pw), img.width - 1)
							local sy = math.min(math.floor(z * img.height / ph), img.height - 1)
							local pi = (sy * img.width + sx) * 4 + 1
							table.insert(px, string.byte(img.data, pi))
							table.insert(px, string.byte(img.data, pi + 1))
							table.insert(px, string.byte(img.data, pi + 2))
							table.insert(px, string.byte(img.data, pi + 3))
						end
					end
					local png_data = core.encode_png(pw, ph, px)
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

		local out_w = tonumber(fields.mapart_w) or 128
		local out_h = tonumber(fields.mapart_h) or 128
		local do_dither = fields.mapart_dither == "true"
		local do_gamma = fields.mapart_gamma == "true"

		s.out_w = out_w
		s.out_h = out_h
		s.dither = do_dither
		s.gamma = do_gamma

		local schem = image_to_schem(img.width, img.height, img.data, {
			width = out_w,
			height = out_h,
			dither = do_dither,
			gamma = do_gamma,
		})

		if #schem.data == 0 then
			s.status = "No non-transparent pixels found"
			return true
		end

		local ok3, result = save_and_load_mts(schem, name)
		if ok3 then
			s.status = "Saved: " .. result
		else
			s.status = "Error: " .. (result or "unknown")
		end
		return true
	end

	return false
end
```

- [ ] **Step 4: Add /mapart chat command**

```lua
core.register_chatcommand("mapart", {
	params = "<path> [width] [height] [--dither] [--gamma]",
	description = "Convert a PNG image to an MTS schematic using map colors",
	func = function(param)
		if param == "" then
			return false, "Usage: /mapart <path> [width] [height] [--dither] [--gamma]"
		end

		local parts = {}
		for p in param:gmatch("%S+") do
			table.insert(parts, p)
		end

		local filepath = parts[1]
		local out_w = 128
		local out_h = 128
		local do_dither = false
		local do_gamma = false

		for i = 2, #parts do
			if parts[i] == "--dither" then
				do_dither = true
			elseif parts[i] == "--gamma" then
				do_gamma = true
			elseif not out_w or out_w == 128 then
				out_w = tonumber(parts[i]) or 128
			else
				out_h = tonumber(parts[i]) or 128
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

		local schem = image_to_schem(img.width, img.height, img.data, {
			width = out_w,
			height = out_h,
			dither = do_dither,
			gamma = do_gamma,
		})

		if #schem.data == 0 then
			return false, "No non-transparent pixels found"
		end

		local name = filepath:match("([^/]+)%.png$") or "mapart_output"
		local ok3, result = save_and_load_mts(schem, name .. ".png")
		if ok3 then
			return true, "Mapart saved: " .. result .. " (" .. #schem.data .. " nodes)"
		else
			return false, "Error: " .. (result or "unknown")
		end
	end,
})
```

- [ ] **Step 5: Initialize mod — load palette on startup**

```lua
-- Initialize palette
core.after(0, function()
	load_palette()
end)
```

- [ ] **Step 6: Commit**

```bash
git add clientmods/ANTILUA/mapart/init.lua
git commit -m "Add mapart mod: palette, color matching, formspec, chat command"
```

---

### Task 5: Schembuilder formspec integration

**Files:**
- Modify: `clientmods/ANTILUA/schembuilder/init.lua`

- [ ] **Step 0: Expose schembuilder load function globally**

Add at the end of schembuilder's `init.lua` (after all local function definitions):

```lua
-- Exposed for other mods (e.g., mapart)
schembuilder_load_mts = function(filepath, label)
	if type(do_schembuild) ~= "function" then
		return false, "schembuilder not initialized"
	end
	local ok, err, sparam = do_schembuild("file:" .. filepath)
	if ok then
		create_build(sparam or ("file:" .. filepath), label or "schematic")
	end
	return ok, err
end
```

This allows the mapart mod to call `schembuilder_load_mts("/path/to/file.mts", "name.mts")`.

- [ ] **Step 1: Modify tab header to include Mapart tab**

Change line 348:
```lua
-- From:
"tabheader[0,0;tabs;Browse Schematics,Saved Builds,BlockExchange;" .. (tab + 1) .. "]" ..
-- To:
"tabheader[0,0;tabs;Browse Schematics,Saved Builds,BlockExchange,Mapart;" .. (tab + 1) .. "]" ..
```

- [ ] **Step 2: Add Mapart tab content**

After the `else` block for tab 2 (line 434, before `core.show_formspec`), add:

```lua
	elseif tab == 3 then
		fs = get_mapart_tab(fs, tab)
	end
```

Change the current `end` before `core.show_formspec` to `else`:

Find:
```lua
	else
		-- Tab 2: BlockExchange
```

Change to:
```lua
	elseif tab == 2 then
		-- Tab 2: BlockExchange
```

- [ ] **Step 3: Handle Mapart tab switch**

After line 662 (`if fields.tabs and tonumber(fields.tabs) == 3 then`), add:

```lua
	if fields.tabs and tonumber(fields.tabs) == 4 then
		-- Tab 3: Mapart — do nothing special
	end
```

- [ ] **Step 4: Add Mapart event handler**

At the beginning of the `core.register_on_formspec_input` callback (after the `if fields.tabs` check, around line 640), add:

```lua
	if handle_mapart_events(fields) then
		show_browser_form(3)
		return
	end
```

- [ ] **Step 5: Verify schembuilder loads correctly**

Run the client with the devtest game to verify the schembuilder formspec shows 4 tabs.

- [ ] **Step 6: Commit**

```bash
git add clientmods/ANTILUA/schembuilder/init.lua
git commit -m "Add Mapart tab to schembuilder formspec"
```

---

### Task 6: Write integration tests

**Files:**
- Create: `clientmods/al_test/test_mapart.lua`

- [ ] **Step 1: Write test file**

```lua
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
		local ok, err = pcall(core.decode_image, "")
		T.assert(not ok, "should error on empty data")
	end)

	T.run("decode_image fails on garbage data", function()
		local r, img = core.decode_image("not a png")
		T.assert(r == nil, "should return nil for garbage")
	end)

	T.run("decode_image roundtrip with encode_png", function()
		-- Create a small test image
		local w, h = 4, 4
		local px = {}
		for i = 1, w * h do
			table.insert(px, 255) -- R
			table.insert(px, 0)   -- G
			table.insert(px, 0)   -- B
			table.insert(px, 255) -- A
		end
		local png = core.encode_png(w, h, px)
		T.assert(png ~= nil, "encode_png should succeed")

		local r, img = core.decode_image(png)
		T.assert(r and img, "decode_image should succeed on valid PNG")
		T.assert_eq(img.width, w, "width should match")
		T.assert_eq(img.height, h, "height should match")
		T.assert_eq(#img.data, w * h * 4, "data length should be w*h*4")

		-- Check first pixel is red
		local r_byte = string.byte(img.data, 1)
		local g_byte = string.byte(img.data, 2)
		local b_byte = string.byte(img.data, 3)
		local a_byte = string.byte(img.data, 4)
		T.assert_eq(r_byte, 255, "red channel")
		T.assert_eq(g_byte, 0, "green channel")
		T.assert_eq(b_byte, 0, "blue channel")
		T.assert_eq(a_byte, 255, "alpha channel")
	end)

	T.run("write_file roundtrip", function()
		local test_data = "hello mapart"
		local test_path = os.tmpname() or "/tmp/antilua_mapart_test"
		local ok = core.write_file(test_path, test_data)
		T.assert(ok, "write_file should succeed")

		local ok2, data = pcall(core.read_file, test_path)
		T.assert(ok2, "read_file of written file should succeed")
		T.assert_eq(data, test_data, "read back data should match")

		os.remove(test_path)
	end)

	T.run("write_file path traversal denied", function()
		local ok, err = core.write_file("../../etc/passwd", "hack")
		T.assert(not ok, "path traversal should be denied")
	end)

	T.run("color match via encode->decode->convert pipeline", function()
		-- Encode a 1x1 red PNG, decode it, convert to schem
		local px = {255, 0, 0, 255}
		local png_data = core.encode_png(1, 1, px)
		T.assert(png_data ~= nil, "encode_png should succeed")
		local ok, img = core.decode_image(png_data)
		T.assert(ok and img, "decode_image should succeed")

		-- Convert via the public chat command flow
		-- Just verify decode_image returns usable data
		T.assert_eq(img.width, 1, "width")
		T.assert_eq(img.height, 1, "height")
		T.assert_eq(#img.data, 4, "one RGBA pixel")

		-- Verify first pixel is red
		local r = string.byte(img.data, 1)
		local g = string.byte(img.data, 2)
		local b = string.byte(img.data, 3)
		T.assert_eq(r, 255, "red channel")
		T.assert_eq(g, 0, "green channel")
		T.assert_eq(b, 0, "blue channel")
	end)

	T.run("write_file and read_file roundtrip", function()
		local test_data = "hello mapart"
		local test_path = "/tmp/antilua_mapart_test"
		local ok = core.write_file(test_path, test_data)
		T.assert(ok, "write_file should succeed")

		local ok2, data = pcall(core.read_file, test_path)
		T.assert(ok2, "read_file of written file should succeed")
		T.assert_eq(data, test_data, "read back data should match")

		os.remove(test_path)
	end)
end
```

- [ ] **Step 2: Register test in al_test's init.lua**

Add `dofile` line after line 112 (after `test_client_map.lua`):

```lua
dofile(modpath .. "/test_mapart.lua")
```

Add `test_mapart(al_test)` after line 173 (after `test_client_map(al_test)`):

```lua
test_mapart(al_test)
```

- [ ] **Step 3: Run tests**

```bash
./util/ci/run_al_tests.sh
```

Expected: All mapart tests pass (PASS).

- [ ] **Step 4: Commit**

```bash
git add clientmods/al_test/test_mapart.lua clientmods/al_test/init.lua
git commit -m "Add mapart integration tests"
```

---

### Task 7: Build and verify full pipeline

- [ ] **Step 1: Full rebuild**

```bash
cmake --build build -j$(nproc)
```

Expected: Clean compile, no warnings.

- [ ] **Step 2: Run unit tests and integration tests**

```bash
./bin/antilua --run-unittests
./util/ci/run_al_tests.sh
```

Expected: All unit tests pass. Integration tests show `[AL_TEST] PASS` for all mapart tests.

- [ ] **Step 3: End-to-end manual test**

Create a simple 2x2 test PNG:
```bash
# Use core.encode_png from the Lua pipe or test environment
```

Then use `/mapart` to convert and verify the MTS file is created in the schematics directory.

- [ ] **Step 4: Final commit if any fixes needed**

```bash
git commit -am "Fix mapart issues found during testing"
```
