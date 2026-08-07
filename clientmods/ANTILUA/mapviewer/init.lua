-- mapviewer: formspec-based viewer for the Antilua big map.
--
-- Shows the client-side big map (saved minimap blocks) inside a formspec with
-- button-driven pan and zoom. Waypoints that the poi mod currently displays
-- (the ones shown as minimap markers / HUD dots) are overlaid as colored dots
-- with their names. A "Save as image" button copies the currently displayed
-- map section to a PNG in <data>/mapviewer/.
--
-- Requires the Antilua big map (core.al_bigmap, enable_minimap=true).

mapviewer = {}

local storage = core.get_mod_storage("mapviewer")

local af = core.al_formspec

local view = {
	center = nil, -- { x = node, z = node }
	size = nil,   -- section extent in nodes (square)
	tex = nil,    -- current render_section texture basename
	status = "",
	dirty = true, -- forces a re-render on the next formspec build
}

local function round(v)
	return math.floor(v + 0.5)
end

local function clamp(v, lo, hi)
	return math.max(lo, math.min(hi, v))
end

local function setting(name, default)
	local v = tonumber(core.settings:get(name))
	if v == nil then return default end
	return v
end

local function min_size()
	return setting("mapviewer_min_size", 32)
end

local function max_size()
	return setting("mapviewer_max_size", 2048)
end

local function default_size()
	return clamp(setting("mapviewer_default_size", 512), min_size(), max_size())
end

local function pan_step_frac()
	return setting("mapviewer_pan_step", 0.35)
end

local function zoom_factor()
	return setting("mapviewer_zoom_factor", 0.8)
end

local function available()
	return core.al_bigmap and type(core.al_bigmap.render_section) == "function"
end

--
-- Per-server view persistence
--

local function server_id()
	local info = core.get_server_info()
	if info and info.address and info.address ~= "" then
		return info.address .. ":" .. info.port
	end
	return "singleplayer"
end

local function persist_key()
	return "view_" .. server_id()
end

local function save_state()
	if not (view.center and view.size) then return end
	local ok, json = pcall(core.write_json, {
		x = round(view.center.x),
		z = round(view.center.z),
		size = round(view.size),
	})
	if ok and json then
		storage:set_string(persist_key(), json)
	end
end

local function load_state()
	local raw = storage:get_string(persist_key())
	if raw == "" then return end
	local ok, data = pcall(core.parse_json, raw)
	if not ok or type(data) ~= "table" then return end
	if type(data.x) == "number" and type(data.z) == "number" and type(data.size) == "number" then
		view.center = { x = data.x, z = data.z }
		view.size = clamp(data.size, min_size(), max_size())
	end
end

local function ensure_state()
	if not view.center then
		local p = core.localplayer and core.localplayer:get_pos()
		if p then
			view.center = { x = round(p.x), z = round(p.z) }
		else
			view.center = { x = 0, z = 0 }
		end
	end
	if not view.size then
		load_state()
	end
	if not view.size then
		view.size = default_size()
	end
end

local function mark_dirty(msg)
	view.dirty = true
	if msg then view.status = msg end
end

--
-- POI overlay
--

-- Waypoints that the poi mod is currently displaying (they have minimap
-- markers, which is exactly the set the fullscreen big map overlay draws).
local function get_active_pois()
	local pois = {}
	if not (poi and poi.getwps and poi.get_displayed_marker) then
		return pois
	end
	for _, name in ipairs(poi.getwps()) do
		if poi.get_displayed_marker(name) then
			local p = poi.get_waypoint(name)
			if p then
				local color = poi.group_color(poi.get_group(name))
					or poi.color_int(name) or 0x00ff00
				table.insert(pois, {
					name = name,
					x = p.x,
					z = p.z,
					color = string.format("#%06x", color),
				})
			end
		end
	end
	return pois
end

--
-- Layout: everything is computed from the content width/height so the same
-- content works standalone (size[13.5,10]) and as an inventory tab.
--

local function compute_layout(cw, ch)
	local m = 0.3        -- left/right margin
	local right_w = 3.0  -- control column width
	local gap = 0.4      -- gap between map and controls
	local avail_w = cw - m - right_w - gap - m
	local avail_h = ch - 0.7 - 0.6 - 0.3
	local s = math.max(math.min(avail_w, avail_h), 3)
	local map_x = m + (avail_w - s) / 2
	local map_y = 0.75
	return {
		cw = cw, ch = ch, m = m, right_w = right_w, gap = gap,
		s = s, map_x = map_x, map_y = map_y, right_x = map_x + s + gap,
	}
end

-- Project a node position onto the map element (north-up: larger Z is up).
local function project(px, pz, lay)
	local half = view.size / 2
	local sx = lay.map_x + (px - (view.center.x - half)) / view.size * lay.s
	local sy = lay.map_y + ((view.center.z + half) - pz) / view.size * lay.s
	-- Rim-clamp far waypoints to the inset map edge, mirroring the fullscreen
	-- big map overlay.
	local inset = lay.s * 0.01
	local half_w = lay.s / 2 - inset
	local half_h = lay.s / 2 - inset
	local dx = sx - (lay.map_x + lay.s / 2)
	local dy = sy - (lay.map_y + lay.s / 2)
	local max_abs = math.max(math.abs(dx) / half_w, math.abs(dy) / half_h)
	if max_abs > 1 then
		dx = dx / max_abs
		dy = dy / max_abs
		sx = lay.map_x + lay.s / 2 + dx * half_w
		sy = lay.map_y + lay.s / 2 + dy * half_h
	end
	return sx, sy
end

local function render_now()
	if not available() then
		view.tex = nil
		view.status = "Big map unavailable (enable_minimap off?)"
		return false
	end
	ensure_state()
	local tex = core.al_bigmap:render_section({
		pos = { x = view.center.x, z = view.center.z },
		size = { x = view.size, z = view.size },
	})
	if not tex then
		view.tex = nil
		view.status = "Render failed (no saved map data here?)"
		return false
	end
	view.tex = tex
	view.dirty = false
	save_state()
	return true
end

local function build_content(cw, ch)
	ensure_state()
	if view.dirty or not view.tex then
		render_now()
	end
	local lay = compute_layout(cw, ch)
	local sb = af.new()

	local info = "Center: " .. round(view.center.x) .. ", " .. round(view.center.z)
		.. "  |  View: " .. round(view.size) .. " m"
	sb:add(
		af.label(0.25, 0.1, "Map Viewer"),
		af.label(lay.map_x, 0.1, info)
	)

	if view.tex then
		sb:add(af.image(lay.map_x, lay.map_y, lay.s, lay.s, view.tex))
		local d = lay.s * 0.018
		for _, wp in ipairs(get_active_pois()) do
			local sx, sy = project(wp.x, wp.z, lay)
			sb:add(
				"box[" .. (sx - d / 2) .. "," .. (sy - d / 2) .. ";"
					.. d .. "," .. d .. ";" .. wp.color .. "]",
				af.label(sx + d + 0.05, sy - 0.1, wp.name)
			)
		end
	else
		sb:add(
			af.box(lay.map_x, lay.map_y, lay.s, lay.s, "#222222"),
			af.label(lay.map_x + lay.s / 2 - 1, lay.map_y + lay.s / 2, "No map data")
		)
	end

	local rx = lay.right_x
	local bw = lay.right_w
	local by = lay.map_y
	sb:add(
		af.button(rx, by,       bw, 0.6, "zoom_in",  "Zoom In"),
		af.button(rx, by + 0.7, bw, 0.6, "zoom_out", "Zoom Out"),
		af.button(rx, by + 1.4, bw, 0.6, "center",   "Center Player"),
		af.button(rx, by + 2.1, bw, 0.6, "fit",      "Fit Saved Area"),
		af.button(rx, by + 2.8, bw, 0.6, "refresh",  "Refresh"),
		af.button(rx, by + 3.5, bw, 0.6, "save",     "Save as Image")
	)

	local cxx = rx + bw / 2
	local b = 1.0
	local pan_y = by + 4.6
	sb:add(
		af.button(cxx - b / 2, pan_y,       b, 0.6, "pan_n", "N"),
		af.button(rx,          pan_y + 0.7, b, 0.6, "pan_w", "W"),
		af.button(rx + bw - b, pan_y + 0.7, b, 0.6, "pan_e", "E"),
		af.button(cxx - b / 2, pan_y + 1.4, b, 0.6, "pan_s", "S"),
		af.label(rx, pan_y + 2.1, "Pan"),
		af.button(rx, pan_y + 2.8, bw, 0.6, "close", "Close")
	)

	if view.status and view.status ~= "" then
		sb:add(af.label(lay.map_x, lay.map_y + lay.s + 0.05, view.status))
	end

	return sb:get()
end

--
-- Redraw plumbing (standalone vs inventory tab)
--

local function show_standalone()
	local sb = af.begin("size[13.5,10]")
	sb:add(build_content(13.5, 10))
	core.show_formspec("al_mapviewer", sb:get())
end

local mapviewer_redraw = show_standalone

function mapviewer.set_redraw(fn)
	mapviewer_redraw = fn or show_standalone
end

function mapviewer.redraw()
	mapviewer_redraw()
end

--
-- Actions
--

local function pan(dx, dz)
	ensure_state()
	local step = math.max(1, math.floor(view.size * pan_step_frac()))
	view.center.x = view.center.x + dx * step
	view.center.z = view.center.z + dz * step
	mark_dirty(nil)
end

local function zoom_in()
	ensure_state()
	local target = view.size * zoom_factor()
	if target >= min_size() - 0.001 then
		view.size = round(clamp(target, min_size(), max_size()))
		mark_dirty("Zoom: " .. view.size .. " m")
	end
end

local function zoom_out()
	ensure_state()
	local target = view.size / zoom_factor()
	if target <= max_size() + 0.001 then
		view.size = round(clamp(target, min_size(), max_size()))
		mark_dirty("Zoom: " .. view.size .. " m")
	end
end

local function recenter_player()
	local p = core.localplayer and core.localplayer:get_pos()
	if not p then
		view.status = "No player position"
		return
	end
	view.center = { x = round(p.x), z = round(p.z) }
	mark_dirty("Centered on player")
end

local function fit_coverage()
	if not available() then return end
	local cov = core.al_bigmap:get_coverage()
	if not cov or not cov.count or cov.count == 0 then
		view.status = "No saved area to fit"
		return
	end
	view.center = {
		x = round((cov.max.x + cov.min.x) / 2),
		z = round((cov.max.z + cov.min.z) / 2),
	}
	view.size = round(clamp(math.max(cov.max.x - cov.min.x, cov.max.z - cov.min.z) * 1.1,
		min_size(), max_size()))
	mark_dirty("Fitted to " .. cov.count .. " saved blocks")
end

-- Copies the currently displayed map section to a PNG in <data>/mapviewer/.
-- Returns the saved path (or nil + error message).
function mapviewer.save_current()
	if not available() then
		view.status = "Big map unavailable"
		return nil, "unavailable"
	end
	if not view.tex then
		view.status = "Nothing rendered yet"
		return nil, "no texture"
	end
	local dir = core.al_bigmap:get_save_dir()
	if not dir or dir == "" then
		view.status = "No big map data"
		return nil, "no save dir"
	end
	local data, err = core.read_file(dir .. "/images/" .. view.tex)
	if not data then
		view.status = "Read failed: " .. tostring(err)
		return nil, err
	end
	local base = core.get_data_path() .. "/mapviewer"
	core.mkdir(base)
	local name = string.format("map_%d_%d_%d_%d_%d.png",
		round(view.center.x), round(view.center.z), round(view.size),
		os.time(), math.random(10000, 99999))
	local path = base .. "/" .. name
	local ok, werr = core.write_file(path, data)
	if not ok then
		view.status = "Save failed: " .. tostring(werr)
		return nil, werr
	end
	view.status = "Saved: " .. path
	return path
end

--
-- Entry points
--

function mapviewer.open()
	if not available() then
		core.display_chat_message("Map viewer unavailable (enable_minimap is off or big map not ready).")
		return
	end
	ensure_state()
	-- Bound stale section PNGs from previous sessions. Safe here: it runs
	-- before any render in this session, so no pending formspec references.
	core.al_bigmap:clear_images()
	mark_dirty(nil)
	mapviewer_redraw()
end

core.register_chatcommand("mapviewer", {
	description = "Open the big map viewer (pan/zoom, POI overlay, save as image)",
	func = function()
		mapviewer.open()
		return true
	end,
})
if ws and ws.register_chatcommand_alias then
	ws.register_chatcommand_alias("mapviewer", "mv", "viewmap")
end

core.register_cheat("MapViewer", {
	category = "Render",
	description = "Open the big-map formspec viewer",
	func = mapviewer.open,
})

--
-- Formspec input (shared by the standalone formspec and the inventory tab).
-- Returns true when it consumed the fields.
--

function mapviewer.handle_fields(fields)
	if not fields then return true end
	if fields.quit then return true end
	if fields.close then
		-- Covers both the standalone form ("al_mapviewer") and the inventory
		-- tab ("al_inv"); closing an unopened name is a no-op.
		core.close_formspec("al_mapviewer")
		core.close_formspec("al_inv")
		return true
	end
	local handled = false
	if fields.pan_n then
		pan(0, 1); handled = true
	elseif fields.pan_s then
		pan(0, -1); handled = true
	elseif fields.pan_w then
		pan(-1, 0); handled = true
	elseif fields.pan_e then
		pan(1, 0); handled = true
	elseif fields.zoom_in then
		zoom_in(); handled = true
	elseif fields.zoom_out then
		zoom_out(); handled = true
	elseif fields.center then
		recenter_player(); handled = true
	elseif fields.fit then
		fit_coverage(); handled = true
	elseif fields.refresh then
		mark_dirty("Refreshed"); handled = true
	elseif fields.save then
		mapviewer.save_current(); handled = true
	end
	if handled then
		mapviewer.redraw()
	end
	return true
end

core.register_on_formspec_input(function(formname, fields)
	if formname ~= "al_mapviewer" then return end
	return mapviewer.handle_fields(fields)
end)

--
-- Inventory tab (registered directly: the mod loader orders the `inventory`
-- mod before mapviewer because mapviewer optionally depends on it)
--

if core.inv_tabs and core.inv_tabs.register_tab then
	core.inv_tabs.register_tab({
		id = "mapviewer",
		title = "Map",
		build = function(ctx)
			local w = (ctx and ctx.width) or 11.75
			local h = (ctx and ctx.height) or 10
			return build_content(w, h)
		end,
		handle = function(fields)
			return mapviewer.handle_fields(fields)
		end,
		show_inventory = false,
		pad = false,
	})
	mapviewer.set_redraw(function()
		if core.inv_tabs.is_open() then
			core.inv_tabs.set_active("mapviewer")
		else
			show_standalone()
		end
	end)
end
