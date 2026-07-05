PARTICLE_TTL = PARTICLE_TTL or 600

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
			if entry.name == "air" or entry.prob == 0 then goto skip_file end
			local node = {x=pos.x + (entry.x or 0), y=pos.y + (entry.y or 0), z=pos.z + (entry.z or 0), name=entry.name}
			table.insert(place_nodes, node)
			add_preview_if_needed(node, node.name)
			::skip_file::
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
	local count = load_schematic_nodes(value, pos)
	if not count then
		return false, "Failed to load schematic"
	end
	return true, nil, param
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
			table.insert(place_nodes, { x = wp.x, y = wp.y, z = wp.z, name = node.name })
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
	local files = core.get_dir_list(schem_path2, false) or {}
	local schems = {}
	for _, f in ipairs(files) do
		if f:match("%.mts$") then
			table.insert(schems, f)
		end
	end
	local selected = schems[event_idx]
	if selected then
		local real_modpath
		if type(core.get_modpath_real) == "function" then
			real_modpath = core.get_modpath_real("schembuilder")
		else
			real_modpath = modpath
		end
		local param = "file:" .. real_modpath .. "/schematics/" .. selected
		local ok, err, sparam = do_schembuild(param)
		if ok then
			create_build(sparam or param, selected)
		end
		core.close_formspec("schembuilder:browser")
	end
end

core.register_on_formspec_input(function(formname, fields)
	if formname ~= "schembuilder:browser" then return end

	if fields.quit then return end

	if fields.close then
		_selected_schem = nil
		_selected_build = nil
		core.close_formspec("schembuilder:browser")
		return
	end

	if fields.tabs then
		_selected_schem = nil
		_selected_build = nil
		show_browser_form(tonumber(fields.tabs) - 1)
		return
	end

	if type(handle_mapart_events) == "function" and handle_mapart_events(fields) then
		show_browser_form(3)
		return
	end

	-- Track textlist selections
	if fields.schem_list then
		local idx = parse_list_event(fields.schem_list)
		if idx then
			_selected_schem = idx
			if fields.schem_list:match("^DCL:") then
				load_schematic_by_index(idx)
				return
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
			return
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
		return
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
		return
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
		return
	end

	if fields.bx_load_dl_sel then
		_sel_bx_dl = parse_list_event(fields.bx_downloads)
	end

	-- Tab 0: Load schematic button
	if fields.schem_load and _selected_schem then
		load_schematic_by_index(_selected_schem)
		return
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
		return
	end
end)

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

core.register_chatcommand("spos1", {
	description = "Set pos1",
	func = function(param)
		schembuilder.pos1 = vector.round(core.localplayer:get_pos())
		ws.notify("pos1 set", ws.NOTIFY_INFO)
		pos_marker(schembuilder.pos1, "worldedit_pos1.png")
	end,
})

core.register_chatcommand("spos2", {
	description = "Set pos2",
	func = function(param)
		schembuilder.pos2 = vector.round(core.localplayer:get_pos())
		ws.notify("pos2 set", ws.NOTIFY_INFO)
		pos_marker(schembuilder.pos2, "worldedit_pos2.png")
	end,
})
