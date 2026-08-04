local PARTICLE_TTL = 600

function do_schembuild(param, use_pos)
	if param == "" then
		return false, "Need an argument to load"
	end
	local pos = use_pos or (core.localplayer and vector.round(core.localplayer:get_pos()))
	if not pos then
		return false, "No position available"
	end
	local value

	-- file:<path> — load an MTS file from disk
	if param:match("^file:") then
		local filepath = param:sub(6)
		if not filepath:find("/") then
			filepath = core.get_data_path() .. "schematics/" .. filepath
		end
		if filepath:find("%.%.") then
			return false, "Invalid path"
		end
		local ok, data = pcall(core.read_file, filepath)
		if not ok or not data then
			return false, "File not found: " .. filepath
		end
		local ok2, schem = pcall(core.read_schematic, data, {})
		if not ok2 or not schem or not schem.data then
			return false, "Failed to parse MTS file"
		end
		clear_supply_chests()
		place_nodes = {}
		for _, entry in ipairs(schem.data) do
			if entry.name ~= "air" and entry.prob ~= 0 then
				local node = {x=pos.x + (entry.x or 0), y=pos.y + (entry.y or 0), z=pos.z + (entry.z or 0), name=entry.name, param2=entry.param2 or 0}
				table.insert(place_nodes, node)
				add_preview_if_needed(node, node.name)
			end
		end
		ws.notify("Loaded " .. #place_nodes .. " nodes from " .. filepath, ws.NOTIFY_INFO)
		core.after(0.1, update_hud)
		return true, nil, param
	end

	if param == "$" then
		value = core.settings:get("schembuilder_output") or "{}"
	else
		value = param
	end
	clear_supply_chests()
	local count = load_schematic_nodes(value, pos)
	if not count then
		return false, "Failed to load schematic"
	end
	return true, nil, param
end

-- Stop the current build: clear preview/placement state and disable every
-- build cheat/bot. Unlike schemclear, the saved build is kept in Saved Builds.
function schembuilder.stop_build()
	place_nodes = {}
	clear_supply_chests()
	if type(schembuilder_clear_hud) == "function" then
		schembuilder_clear_hud()
	elseif hud_id then
		if core.localplayer then
			core.localplayer:hud_remove(hud_id)
		end
		hud_id = nil
	end
	if type(schemclear_cancel_wireframe) == "function" then
		schemclear_cancel_wireframe()
	end
	if type(core.clear_all_particles) == "function" then
		core.clear_all_particles()
	end
	for _, setting in ipairs({ "autoschemplace", "schembuilderbot", "rhythmbuildbot", "schematic_looter" }) do
		core.settings:set_bool(setting, false)
	end
	ws.notify("Build stopped (saved build kept in Saved Builds)", ws.NOTIFY_INFO)
end

local _selected_schem = nil
local _selected_build = nil

function load_bx_schematic(uid, name, mts_data)
	local schem, err
	if type(core.read_schematic) == "function" then
		schem = core.read_schematic(mts_data, {})
	else
		ws.notify("core.read_schematic not available", ws.NOTIFY_ERROR)
		return
	end
	if not schem or not schem.data then
		ws.notify("Failed to parse BlockExchange schematic", ws.NOTIFY_ERROR)
		return
	end

	local pos = core.localplayer and core.localplayer:get_pos() or { x = 0, y = 0, z = 0 }
	pos = vector.round(pos)
	pos = vector.add(pos, { x = 0, y = 2, z = 0 })

	place_nodes = {}
	for _, node in ipairs(schem.data) do
		if node.name ~= "air" and node.prob and node.prob > 0 then
			local wp = vector.add(pos, { x = node.x or 0, y = node.y or 0, z = node.z or 0 })
			table.insert(place_nodes, { x = wp.x, y = wp.y, z = wp.z, name = node.name, param2 = node.param2 or 0 })
		end
	end

	core.close_formspec("schembuilder:browser")
	create_build(uid, name)
	core.after(0.1, update_hud)
	for _, n in ipairs(place_nodes) do
		add_preview_if_needed(n, n.name)
	end
	ws.notify("Loaded: " .. name .. " (" .. #place_nodes .. " nodes)", ws.NOTIFY_SUCCESS)
end

function load_schematic_by_index(event_idx)
	if not event_idx then return end
	local schem_path2
	if type(core.get_modpath_real) == "function" then
		schem_path2 = core.get_modpath_real("schembuilder") .. "/schematics"
	else
		schem_path2 = modpath .. "/schematics"
	end
	local user_path = core.get_data_path() .. "schematics"
	local files = core.get_dir_list(schem_path2, false) or {}
	local user_files = core.get_dir_list(user_path, false) or {}
	local all_files = {}
	for _, f in ipairs(files) do
		if f:match("%.mts$") then
			table.insert(all_files, { name = f, path = schem_path2 .. "/" .. f })
		end
	end
	for _, f in ipairs(user_files) do
		if f:match("%.mts$") then
			table.insert(all_files, { name = f, path = user_path .. "/" .. f })
		end
	end
	local selected = all_files[event_idx]
	if selected then
		local param = "file:" .. selected.path
		local ok, err, sparam = do_schembuild(param)
		if ok then
			create_build(sparam or param, selected.name)
		end
		core.close_formspec("schembuilder:browser")
	end
end

function schembuilder.handle_browser_fields(fields)
	if fields.quit then return true end

	-- Sub-tab buttons (right-side column, embedded) / top tabheader (standalone).
	if schembuilder.browser_subtabs.handle(fields) ~= nil then
		_selected_schem = nil
		_selected_build = nil
		show_browser_form(schembuilder.browser_subtabs.get())
		return true
	end
	if fields.tabs then
		_selected_schem = nil
		_selected_build = nil
		show_browser_form(tonumber(fields.tabs) - 1)
		return true
	end

	if fields.close then
		_selected_schem = nil
		_selected_build = nil
		core.close_formspec("schembuilder:browser")
		return true
	end


	if schembuilder._mapart_event_fn and schembuilder._mapart_event_fn(fields) then
		show_browser_form(3)
		return true
	end

	-- Track textlist selections
	if fields.schem_list then
		local idx = parse_list_event(fields.schem_list)
		if idx then
			_selected_schem = idx
			-- Also fetch the display name for info display
			local schem_path
			if type(core.get_modpath_real) == "function" then
				schem_path = core.get_modpath_real("schembuilder") .. "/schematics"
			else
				schem_path = modpath .. "/schematics"
			end
			local user_path = core.get_data_path() .. "schematics"
			local file_list = {}
			local function add_dir(dir, prefix)
				local list = core.get_dir_list(dir, false)
				local files = (type(list) == "table") and list or {}
				for _, f in ipairs(files) do
					if f:match("%.mts$") then
						table.insert(file_list, prefix and (prefix .. f) or f)
					end
				end
			end
			add_dir(schem_path)
			add_dir(user_path, "[U] ")
			_selected_schem_name = file_list[idx]
			if fields.schem_list:match("^DCL:") then
				load_schematic_by_index(idx)
				return true
			end
		end
	end

	if fields.build_list then
		local idx = parse_list_event(fields.build_list)
		if idx then
			_selected_build = idx
		end
	end

	-- Tab 2: BlockExchange actions
	if fields.tabs and tonumber(fields.tabs) == 4 then
		-- Tab 3 (Mapart) — state is managed by mapart mod
	end
	if fields.tabs and tonumber(fields.tabs) == 3 then
		_bx_status = ""
	end

	if fields.bx_search then
		local user = fields.bx_user or ""
		local name = fields.bx_name or ""
		if user == "" or name == "" then
			_bx_status = "Enter username and schematic name"
			show_browser_form(2)
			return true
		end
		_bx_status = "Searching..."
		show_browser_form(2)
		if blockexchange and blockexchange.search then
			blockexchange.search(user, name, function(results)
				if results and #results > 0 then
					_bx_status = "Found " .. #results .. " results"
				else
					_bx_status = "No results found"
				end
				show_browser_form(2)
			end)
		end
		return true
	end

	if fields.bx_results then
		if fields.bx_results:match("^DCL:") then
			_sel_bx_result = parse_list_event(fields.bx_results)
		else
			_sel_bx_result = parse_list_event(fields.bx_results)
		end
	end

	if fields.bx_download and _sel_bx_result then
		local results = blockexchange and blockexchange.search_results or {}
		local entry = results[_sel_bx_result]
		if entry then
			_bx_status = "Downloading " .. entry.name .. "..."
			show_browser_form(2)
			if blockexchange and blockexchange.download then
			blockexchange.download(entry.uid, entry.name, entry.size_x, entry.size_y, entry.size_z,
				function(current, total)
					_bx_status = "Downloading: " .. current .. "/" .. total .. " parts"
					ws.notify_progress("bx_dl", "Downloading " .. entry.name, math.floor(current * 100 / total))
					show_browser_form(2)
				end,
					function(ok, result)
						if ok then
							_bx_status = "Done! Saved as " .. result
						else
							_bx_status = "Error: " .. result
						end
						show_browser_form(2)
					end
				)
			end
		end
		return true
	end

	if fields.bx_load_dl and fields.bx_downloads then
		local idx = parse_list_event(fields.bx_downloads)
		if idx then
			local downloads = blockexchange and blockexchange.get_downloaded_list and blockexchange.get_downloaded_list() or {}
			local entry = downloads[idx]
			if entry then
				local mts = blockexchange and blockexchange.get_mts_data and blockexchange.get_mts_data(entry.uid)
				if mts then
					load_bx_schematic(entry.uid, entry.name, mts)
				end
			end
		end
		return true
	end

	if fields.bx_load_dl_sel then
		_sel_bx_dl = parse_list_event(fields.bx_downloads)
	end

	-- Tab 0: Load schematic button
	if fields.schem_load and _selected_schem then
		load_schematic_by_index(_selected_schem)
		return true
	end

	if fields.schem_stop or fields.build_stop then
		schembuilder.stop_build()
		core.close_formspec("schembuilder:browser")
		return true
	end

	-- Tab 1: Build actions
	if fields.build_load or fields.build_restart or fields.build_delete or fields.build_clear_particles then
		if not _selected_build then return end
		local idx = get_build_index()
		local entry = idx[_selected_build]
		if not entry then return end

		if fields.build_load then
			clear_supply_chests()
			if load_build(entry.id) then
				for _, n in ipairs(place_nodes) do
					add_preview_if_needed(n, n.name)
				end
				core.after(0.1, update_hud)
				ws.notify("Loaded build: " .. entry.name, ws.NOTIFY_INFO)
			end
			core.close_formspec("schembuilder:browser")
		elseif fields.build_restart then
			local ok, err, sparam = do_schembuild(entry.source)
			if ok then
				delete_build(entry.id)
				create_build(sparam or entry.source, entry.name)
				core.after(0.1, update_hud)
				ws.notify("Restarted build: " .. entry.name, ws.NOTIFY_INFO)
			end
			core.close_formspec("schembuilder:browser")
		elseif fields.build_clear_particles then
			if type(core.clear_all_particles) == "function" then
				core.clear_all_particles()
			end
			if hud_id then
				core.localplayer:hud_remove(hud_id)
				hud_id = nil
			end
			ws.notify("Cleared particles", ws.NOTIFY_INFO)
			core.close_formspec("schembuilder:browser")
		elseif fields.build_delete then
			place_nodes = {}
			clear_supply_chests()
			if hud_id then
				core.localplayer:hud_remove(hud_id)
				hud_id = nil
			end
			delete_build(entry.id)
			ws.notify("Deleted build: " .. entry.name, ws.NOTIFY_INFO)
			_selected_build = nil
			show_browser_form(1)
		end
		return true
	end

	-- Tab 4: Persist checkbox state via setting (checkbox not included in button submissions)
	if fields.hollow ~= nil then
		core.settings:set_bool("schembuilder_hollow", fields.hollow == "true")
		show_browser_form(4)
		return true
	end

	-- Tab 4: Shape generation actions
	if fields.shape_generate or fields.shape_genplace then
		core.settings:set("schembuilder_shape_type", fields.shape_type or "Cube")
		core.settings:set("schembuilder_node_name", fields.node_name or "mcl_core:stone")
		core.settings:set("schembuilder_dim_x", fields.dim_x or "8")
		core.settings:set("schembuilder_dim_y", fields.dim_y or "8")
		core.settings:set("schembuilder_dim_z", fields.dim_z or "8")
		core.settings:set("schembuilder_offset_x", fields.offset_x or "0")
		core.settings:set("schembuilder_offset_y", fields.offset_y or "1")
		core.settings:set("schembuilder_offset_z", fields.offset_z or "5")

		local shape_type = fields.shape_type or "cube"
		local mat = fields.node_name or "mcl_core:stone"
		local dim_x = tonumber(fields.dim_x) or 8
		local dim_y = tonumber(fields.dim_y) or 8
		local dim_z = tonumber(fields.dim_z) or 8
		local hollow = core.settings:get_bool("schembuilder_hollow")
		local off_x = tonumber(fields.offset_x) or 0
		local off_y = tonumber(fields.offset_y) or 1
		local off_z = tonumber(fields.offset_z) or 5

		shape_type = shape_type:lower()

		local rel_nodes, err = schembuilder.generate_shape(shape_type, dim_x, dim_y, dim_z, mat, hollow)
		if not rel_nodes then
			ws.notify("Shape generation error: " .. (err or "unknown"), ws.NOTIFY_ERROR)
			return true
		end

		if #rel_nodes == 0 then
			ws.notify("Generated shape is empty (try larger dimensions)", ws.NOTIFY_WARNING)
			return true
		end

		local pos = core.localplayer and vector.round(core.localplayer:get_pos())
		if not pos then
			ws.notify("No player position", ws.NOTIFY_ERROR)
			return true
		end

		local origin = vector.add(pos, {x = off_x, y = off_y, z = off_z})

		clear_supply_chests()
		place_nodes = {}
		for _, n in ipairs(rel_nodes) do
			local wp = {x = origin.x + n.x, y = origin.y + n.y, z = origin.z + n.z, name = n.name, param2 = n.param2 or 0}
			table.insert(place_nodes, wp)
			add_preview_if_needed(wp, wp.name)
		end

		local shape_name = shape_type:gsub("^%l", string.upper)
		local label = shape_name .. " (" .. dim_x .. "x" .. dim_y .. "x" .. dim_z .. ")"
		create_build("shape:" .. label, label)
		core.after(0.1, update_hud)

		ws.notify("Generated " .. #place_nodes .. " nodes: " .. label, ws.NOTIFY_SUCCESS)

		if fields.shape_genplace then
			core.settings:set("autoschemplace", "true")
		end

		core.close_formspec("schembuilder:browser")
		return true
	end

	return true
end

core.register_on_formspec_input(function(formname, fields)
	if formname ~= "schembuilder:browser" then return end
	return schembuilder.handle_browser_fields(fields)
end)

core.register_chatcommand("sload", {
	params = "<name>",
	description = "Load a schematic from data/schematics/ by name",
	func = function(param)
		if param == "" then return false, "Usage: .sload <name>" end
		local ok, err = do_schembuild("file:" .. param)
		if ok then
			return true, "Loaded: " .. param
		end
		return false, err
	end,
})

core.register_chatcommand("schembrowse", {
	description = "Open the schematic browser GUI",
	func = function(param)
		show_browser_form(0)
		return true
	end,
})

core.register_chatcommand("schembuild", {
	description = "Load schematic. $ for schembuilder_output setting, file:<path> for MTS file from disk.",
	func = function(param)
		local ok, err, save_param = do_schembuild(param)
		if ok then
			core.settings:set("schembuilder_resume_pos",
				vector.round(core.localplayer:get_pos()).x .. "," ..
				vector.round(core.localplayer:get_pos()).y .. "," ..
				vector.round(core.localplayer:get_pos()).z)
			core.settings:set("schembuilder_resume_param", save_param or param)
			local name
			if param:match("^file:") then
				name = param:gsub("^file:", ""):match("([^/\\]+)$") or "Schematic"
			else
				name = "Schematic"
			end
			if current_build_id then
				delete_build(current_build_id)
			end
			create_build(save_param or param, name)
			if core.global_exists("poi") then
				local pos = vector.round(core.localplayer:get_pos())
				poi.set_waypoint(pos, name)
				poi.set_group(name, "schembuilder")
			end
		end
		return ok, err
	end,
})

core.register_chatcommand("schemresume", {
	description = "Resume the last schematic build at the saved position without teleporting",
	func = function(param)
		local saved_pos = core.settings:get("schembuilder_resume_pos")
		local saved_param = core.settings:get("schembuilder_resume_param")
		if not saved_pos or not saved_param then
			return false, "No saved schematic to resume"
		end
		local px, py, pz = saved_pos:match("([^,]+),([^,]+),([^,]+)")
		if not px then
			return false, "Invalid saved position: " .. saved_pos
		end
		local pos = {x = tonumber(px), y = tonumber(py), z = tonumber(pz)}
		local ok, err = do_schembuild(saved_param, pos)
		if ok then
			return true, "Resumed schematic build at saved position"
		end
		return false, err or "Failed to resume schematic"
	end,
})

function pos_marker(pos, texture)
	core.add_particle({
		pos = vector.new(math.floor(pos.x), math.floor(pos.y), math.floor(pos.z)),
		velocity = {x=0, y=0, z=0},
		acceleration = {x=0, y=0, z=0},
		expirationtime = PARTICLE_TTL,
		size = 0.5,
		collisiondetection = false,
		collision_removal = false,
		vertical = false,
		texture = texture,
		glow = 14,
	})
end

local wireframe_timer = nil

local function add_edge_particle(x, y, z)
	core.add_particle({
		pos = { x = x, y = y, z = z },
		velocity = {x=0, y=0, z=0},
		acceleration = {x=0, y=0, z=0},
		expirationtime = 3.0,
		size = 0.3,
		collisiondetection = false,
		collision_removal = false,
		vertical = false,
		texture = "bubble.png",
		glow = 14,
	})
end

local function cancel_wireframe()
	if wireframe_timer then
		wireframe_timer:cancel()
		wireframe_timer = nil
	end
end

-- Global wrapper so init_api.lua can cancel wireframe
function schemclear_cancel_wireframe()
	cancel_wireframe()
	if core.draw3d and core.draw3d.clear then
		core.draw3d:clear("schembuilder_wireframe")
	end
end

local function draw_wireframe()
	if not schembuilder.pos1 or not schembuilder.pos2 then
		wireframe_timer = nil
		return
	end

	-- Use draw3d if available and setting enabled
	if core.draw3d and core.draw3d.add_wirebox and core.settings:get_bool("schembuilder_wireframe_draw3d", false) then
		cancel_wireframe()
		local p1 = schembuilder.pos1
		local p2 = schembuilder.pos2
		local minp = vector.new(math.floor(math.min(p1.x, p2.x)), math.floor(math.min(p1.y, p2.y)), math.floor(math.min(p1.z, p2.z)))
		local maxp = vector.new(math.floor(math.max(p1.x, p2.x)), math.floor(math.max(p1.y, p2.y)), math.floor(math.max(p1.z, p2.z)))
		core.draw3d:add_wirebox("schembuilder_wireframe", minp, maxp, { r = 255, g = 255, b = 255 })
		wireframe_timer = core.after(2.5, draw_wireframe)
		return
	end

	local function lerp(a, b, t) return a + (b - a) * t end
	local p1 = schembuilder.pos1
	local p2 = schembuilder.pos2
	local x1, y1, z1 = math.floor(math.min(p1.x, p2.x)), math.floor(math.min(p1.y, p2.y)), math.floor(math.min(p1.z, p2.z))
	local x2, y2, z2 = math.floor(math.max(p1.x, p2.x)), math.floor(math.max(p1.y, p2.y)), math.floor(math.max(p1.z, p2.z))
	local dx, dy, dz = x2 - x1, y2 - y1, z2 - z1
	local maxd = math.max(dx, dy, dz, 1)
	for t = 0, 1, 1 / maxd do
		local x = lerp(x1, x2, t)
		add_edge_particle(math.floor(x), y1, z1)
		add_edge_particle(math.floor(x), y1, z2)
		add_edge_particle(math.floor(x), y2, z1)
		add_edge_particle(math.floor(x), y2, z2)
	end
	for t = 0, 1, 1 / maxd do
		local y = lerp(y1, y2, t)
		add_edge_particle(x1, math.floor(y), z1)
		add_edge_particle(x1, math.floor(y), z2)
		add_edge_particle(x2, math.floor(y), z1)
		add_edge_particle(x2, math.floor(y), z2)
	end
	for t = 0, 1, 1 / maxd do
		local z = lerp(z1, z2, t)
		add_edge_particle(x1, y1, math.floor(z))
		add_edge_particle(x1, y2, math.floor(z))
		add_edge_particle(x2, y1, math.floor(z))
		add_edge_particle(x2, y2, math.floor(z))
	end
	cancel_wireframe()
	wireframe_timer = core.after(2.5, draw_wireframe)
end

core.register_chatcommand("spos1", {
	description = "Set pos1",
	func = function(param)
		schembuilder.pos1 = vector.round(core.localplayer:get_pos())
		ws.notify("pos1 set", ws.NOTIFY_INFO)
		pos_marker(schembuilder.pos1, "worldedit_pos1.png")
		draw_wireframe()
	end,
})

core.register_chatcommand("spos2", {
	description = "Set pos2",
	func = function(param)
		schembuilder.pos2 = vector.round(core.localplayer:get_pos())
		ws.notify("pos2 set", ws.NOTIFY_INFO)
		pos_marker(schembuilder.pos2, "worldedit_pos2.png")
		draw_wireframe()
	end,
})

core.register_chatcommand("schemstop", {
	description = "Stop the current schematic build and disable build cheats (saved build kept in Saved Builds)",
	func = function(param)
		schembuilder.stop_build()
		return true
	end,
})

-- Quick Access Palette (~) entry: stop the current build with one keypress.
if core.register_quick_menu_provider then
	core.register_quick_menu_provider(function()
		if #place_nodes == 0 then return {} end
		return {
			{
				label = "Stop Schematic Build",
				action = function() schembuilder.stop_build() end,
				keywords = { "schem", "build", "stop", "clear" },
				description = "Stop the current schematic build and disable build cheats (saved build kept)",
			},
		}
	end)
end
