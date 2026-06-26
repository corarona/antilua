local modpath = core.get_modpath(core.get_current_modname())

-- Forward declarations for optional mapart integration
handle_mapart_events = nil
get_mapart_tab = nil
schembuilder_api = nil

local schembuilder = {pos1={x=nil,y=nil,z=nil}, pos2={x=nil,y=nil,z=nil}}
local place_nodes = {}
local supply_chests = {}

local storage
if type(core.get_mod_storage) == "function" then
	local ok, mod = pcall(core.get_mod_storage, "schembuilder")
	if ok then storage = mod end
end

local current_build_id = nil

local function get_server_id()
	local info = core.get_server_info()
	if info then
		return info.address .. ":" .. info.port
	end
	return "localhost:30000"
end

local function build_index_key()
	return "idx_" .. get_server_id()
end

local function build_data_key(id)
	return "build_" .. id
end

local function get_build_index()
	if not storage then return {} end
	local data = storage:get_string(build_index_key())
	if data and data ~= "" then
		local ok, idx = pcall(core.parse_json, data)
		if ok and type(idx) == "table" then
			return idx
		end
	end
	return {}
end

local function save_build_index(idx)
	if not storage then return end
	storage:set_string(build_index_key(), core.write_json(idx) or "[]")
end

local function gen_build_id()
	return os.time() .. "_" .. math.random(10000, 99999)
end

local function save_job()
	if not storage or not current_build_id then return end
	local data = core.write_json(place_nodes)
	storage:set_string(build_data_key(current_build_id), data or "[]")
	local idx = get_build_index()
	for _, entry in ipairs(idx) do
		if entry.id == current_build_id then
			entry.remaining = #place_nodes
			break
		end
	end
	save_build_index(idx)
end

local function load_build(id)
	if not storage then return false end
	local data = storage:get_string(build_data_key(id))
	if data and data ~= "" then
		local ok, nodes = pcall(core.parse_json, data)
		if ok and type(nodes) == "table" and #nodes > 0 then
			current_build_id = id
			place_nodes = nodes
			return true
		end
	end
	return false
end

local function load_job()
	if not storage then return false end
	local idx = get_build_index()
	if #idx == 0 then return false end
	return load_build(idx[1].id)
end

local function delete_build(id)
	if not storage then return end
	storage:set_string(build_data_key(id), "")
	local idx = get_build_index()
	for i = #idx, 1, -1 do
		if idx[i].id == id then
			table.remove(idx, i)
			break
		end
	end
	save_build_index(idx)
	if current_build_id == id then
		current_build_id = nil
	end
end

local function clear_job()
	if current_build_id then
		delete_build(current_build_id)
	end
end

local function create_build(source, name)
	if not storage then return end
	local id = gen_build_id()
	local data = core.write_json(place_nodes)
	storage:set_string(build_data_key(id), data or "[]")
	local idx = get_build_index()
	table.insert(idx, {
		id = id,
		name = name,
		source = source,
		count = #place_nodes,
		remaining = #place_nodes,
	})
	save_build_index(idx)
	current_build_id = id
end

local function get_build_name(param)
	local name = param:match("^file:(.+)") or param
	name = name:match("([^/\\]+)%.?[^.]*$") or name
	return name
end

local function chest_key(pos)
	return math.floor(pos.x) .. "," .. math.floor(pos.y) .. "," .. math.floor(pos.z)
end

local function clear_supply_chests()
	supply_chests = {}
end

local function add_supply_chest(pos)
	supply_chests[chest_key(pos)] = {x = math.floor(pos.x), y = math.floor(pos.y), z = math.floor(pos.z)}
end

local function deserialize_workaround(content)
	local nodes, err = core.deserialize(content, true)
	if err then
		core.log("warning", "schembuilder: deserialize: " .. err)
	end
	return nodes or {}
end

local function get_preview_texture(name)
	local def = core.get_node_def(name)
	if def then
		if def.tiles and def.tiles[1] and def.tiles[1] ~= "" then
			local tex = def.tiles[1]
			if tex:find("%^") then
				tex = tex:match("^([^%^]+)")
			end
			return tex
		end
		if def.inventory_image and def.inventory_image ~= "" then
			return def.inventory_image
		end
	end
	return "unknown_node.png"
end

local function add_preview_particle(pos, node_name)
	local tex = get_preview_texture(node_name)
	if tex == "unknown_node.png" then return end
	core.add_particle({
		pos = vector.new(math.floor(pos.x), math.floor(pos.y), math.floor(pos.z)),
		velocity = {x=0, y=0, z=0},
		acceleration = {x=0, y=0, z=0},
		expirationtime = 9999,
		size = 12,
		collisiondetection = false,
		collision_removal = false,
		vertical = false,
		texture = tex .. "^[opacity:191",
		glow = 14,
	})
end

-- Only add a particle if the target isn't already in place
local function add_preview_if_needed(pos, node_name)
	local current = core.get_node_or_nil(pos)
	if current and current.name == node_name then
		return
	end
	add_preview_particle(pos, node_name)
end

local function load_schematic(value)
	local content = value:match("^5:(.*)$")
	if not content then
		return nil
	end
	return deserialize_workaround(content)
end

local function load_schematic_nodes(value, pos)
	if not value or value == "" then
		return nil
	end
	local nodes, count

	-- Try base64 MTS (new format)
	local raw = core.decode_base64(value)
	if raw and raw ~= "" then
		local ok, schem = pcall(core.read_schematic, raw, {})
		if ok and schem and schem.data then
			nodes = {}
			for _, entry in ipairs(schem.data) do
				if entry.name == "air" or entry.prob == 0 then
					goto skip
				end
				table.insert(nodes, {
					x = pos.x + (entry.x or 0),
					y = pos.y + (entry.y or 0),
					z = pos.z + (entry.z or 0),
					name = entry.name,
				})
				::skip::
			end
			count = #nodes
			if count > 0 then
				clear_supply_chests()
				place_nodes = nodes
				for _, n in ipairs(nodes) do add_preview_if_needed(n, n.name) end
				ws.notify("Loaded " .. count .. " nodes", ws.NOTIFY_INFO)
				core.after(0.1, update_hud)
			end
			return count
		end
	end

	-- Try WorldEdit string format (old format)
	local we_nodes = load_schematic(value)
	if we_nodes then
		clear_supply_chests()
		place_nodes = {}
		local ox, oy, oz = pos.x, pos.y, pos.z
		for _, entry in ipairs(we_nodes) do
			if entry.name == "air" then goto skip2 end
			entry.x, entry.y, entry.z = ox + entry.x, oy + entry.y, oz + entry.z
			table.insert(place_nodes, entry)
			add_preview_if_needed(entry, entry.name)
			::skip2::
		end
		if #place_nodes > 0 then
			ws.notify("Loaded " .. #place_nodes .. " nodes", ws.NOTIFY_INFO)
			core.after(0.1, update_hud)
		end
		return #place_nodes
	end

	return nil
end

local function format_per_item(count)
	local sh_size = 27 * 64
	local shulkers = math.floor(count / sh_size)
	local after_sh = count % sh_size
	local stacks = math.floor(after_sh / 64)
	local items = after_sh % 64

	local parts = {}
	if shulkers > 0 then
		table.insert(parts, shulkers .. "sh")
	end
	if stacks > 0 then
		table.insert(parts, stacks .. "s")
	end
	if items > 0 or #parts == 0 then
		table.insert(parts, items .. "i")
	end
	return table.concat(parts, ", ")
end

local hud_id = nil

local function update_hud()
	if not core.localplayer then return end
	if #place_nodes == 0 then
		clear_job()
		if hud_id then
			core.localplayer:hud_remove(hud_id)
			hud_id = nil
		end
		return
	end
	-- Count nodes by name
	local counts = {}
	for _, entry in ipairs(place_nodes) do
		local n = entry.name
		if n ~= "air" then
			counts[n] = (counts[n] or 0) + 1
		end
	end
	-- Build sorted list
	local sorted = {}
	for name, count in pairs(counts) do
		table.insert(sorted, {name = name, count = count})
	end
	table.sort(sorted, function(a, b) return a.count > b.count end)
	-- Truncate to top 45
	local lines = {"Missing:"}
	local total = 0
	for i = 1, math.min(#sorted, 45) do
		local s = sorted[i]
		table.insert(lines, format_per_item(s.count) .. " X " .. s.name)
		total = total + s.count
	end
	if #sorted > 45 then
		table.insert(lines, "... +" .. (#sorted - 45) .. " more")
	end
	table.insert(lines, "Total: " .. total)

	local text = table.concat(lines, "\n")

	if hud_id then
		core.localplayer:hud_change(hud_id, "text", text)
	else
		hud_id = core.localplayer:hud_add({
			type = "text",
			direction = 0,
			position = {x = 0.85, y = 0.05},
			alignment = {x = 1, y = 1},
			offset = {x = 0, y = 0},
			number = 0x00FF00,
			text = text,
		})
	end
end

-- Schematic browser formspec
local _bx_status = ""
local _sel_bx_result = nil
local _sel_bx_dl = nil

local function show_browser_form(tab)
	tab = tab or 0
	local sid = get_server_id()
	local theme_bg = core.settings:get("theme_bg") or "#121212"
	local fs = "formspec_version[10]size[10,10]no_prepend[]bgcolor[" .. theme_bg .. ";true]" ..
		"tabheader[0,0;tabs;Browse Schematics,Saved Builds,BlockExchange,Mapart;" .. (tab + 1) .. "]" ..
		"button[8,9;2,0.8;close;Close]"

	if tab == 0 then
		local schem_path
		if type(core.get_modpath_real) == "function" then
			schem_path = core.get_modpath_real("schembuilder") .. "/schematics"
		else
			schem_path = modpath .. "/schematics"
		end
		local files = core.get_dir_list(schem_path, false) or {}
		local schems = {}
		for _, f in ipairs(files) do
			if f:match("%.mts$") then
				table.insert(schems, core.formspec_escape(f))
			end
		end
		if #schems == 0 then
			fs = fs .. "label[0,1;No .mts schematics found in schematics/]"
		else
			fs = fs .. "label[0,0.6;Available schematics:]" ..
				"textlist[0,1;10,7;schem_list;" .. table.concat(schems, ",") .. ";0]" ..
				"button[0,8.5;4,0.8;schem_load;Load]"
		end
	elseif tab == 1 then
		local idx = get_build_index()
		if #idx == 0 then
			fs = fs .. "label[0,1;No saved builds for " .. core.formspec_escape(sid) .. "]"
		else
			local entries = {}
			for _, entry in ipairs(idx) do
				table.insert(entries, core.formspec_escape(entry.name .. " (" .. entry.remaining .. "/" .. entry.count .. ")"))
			end
			fs = fs .. "label[0,0.6;Saved builds for " .. core.formspec_escape(sid) .. ":]" ..
				"textlist[0,1;10,5;build_list;" .. table.concat(entries, ",") .. ";0]" ..
				"button[0,6.5;2.4,0.8;build_load;Load]" ..
				"button[2.5,6.5;2.4,0.8;build_restart;Restart]" ..
				"button[5,6.5;2.4,0.8;build_delete;Delete]" ..
				"button[7.5,6.5;2.4,0.8;build_clear_particles;Clear Particles]"
		end
	elseif tab == 2 then
		-- Tab 2: BlockExchange
		local logged_in = blockexchange and blockexchange.logged_in
		if logged_in then
			fs = fs .. "label[0,0.6;Logged in as: " .. core.formspec_escape(blockexchange.username) .. "]" ..
				"field[0,1.5;3.5,0.6;bx_user;;]" ..
				"label[0,2.3;Username]" ..
				"field[3.6,1.5;3.5,0.6;bx_name;;]" ..
				"label[3.6,2.3;Schematic name]" ..
				"button[7.2,1.5;2.5,0.6;bx_search;Search]"
		else
			fs = fs .. "label[0,1;Not logged in. Use .bx_login to connect.]"
		end

		-- Search results
		local results = blockexchange and blockexchange.search_results or {}
		if #results > 0 then
			local entries = {}
			for _, r in ipairs(results) do
				local label = r.name .. " (" .. r.user_name .. ") [" .. r.size_x .. "x" .. r.size_y .. "x" .. r.size_z .. "]"
				table.insert(entries, core.formspec_escape(label))
			end
			fs = fs .. "textlist[0,3;10,4.5;bx_results;" .. table.concat(entries, ",") .. ";0]"
		end

		-- Download button + status
		if logged_in then
			local status_text = _bx_status or ""
			if status_text ~= "" then
				fs = fs .. "label[0,8;" .. core.formspec_escape(status_text) .. "]"
			end
			fs = fs .. "button[0,7.5;3,0.8;bx_download;Download]"
		end

		-- Downloaded schematics
		local downloads = blockexchange and blockexchange.get_downloaded_list and blockexchange.get_downloaded_list() or {}
		if #downloads > 0 then
			local entries = {}
			for _, d in ipairs(downloads) do
				table.insert(entries, core.formspec_escape(d.name .. " (" .. d.size_x .. "x" .. d.size_y .. "x" .. d.size_z .. ")"))
			end
			local y = results and results > 0 and 3 or 3
			fs = fs .. "label[0,8.5;Downloads:]" ..
				"textlist[0,9;8,1.5;bx_downloads;" .. table.concat(entries, ",") .. ";0]" ..
				"button[8.2,9;1.6,0.8;bx_load_dl;Load]"
		end
	elseif tab == 3 then
		if type(get_mapart_tab) == "function" then
			fs = get_mapart_tab(fs, tab)
		else
			fs = fs .. "label[0,1;Mapart mod not loaded. Please wait...]"
		end
	end

	core.show_formspec("schembuilder:browser", fs)
end

local function parse_list_event(event)
	if not event then return nil end
	local parts = event:split(":")
	if #parts == 2 then
		return tonumber(parts[2])
	end
	return tonumber(event)
end

ws.rg("PlaceLiteM", {
	category = "Place",
	setting = "placelitem",
	description = "Place schematic from memory",
	on_step = function(self, dtime)
		if #place_nodes == 0 then
			if hud_id then
				core.localplayer:hud_remove(hud_id)
				hud_id = nil
			end
			return
		end
		local pp = vector.round(core.localplayer:get_pos())
		local range = tonumber(core.settings:get("placelitem.range")) or 4

		local changed = false
		for i = #place_nodes, 1, -1 do
			local entry = place_nodes[i]
			if math.abs(entry.x - pp.x) <= range
			and math.abs(entry.y - pp.y) <= range
			and math.abs(entry.z - pp.z) <= range then
				local pos_v = vector.new(entry.x, entry.y, entry.z)
				if entry.name == "air" then
					local node = core.get_node_or_nil(pos_v)
					if node and node.name ~= "air" then
						ws.dig(pos_v)
						table.remove(place_nodes, i)
						changed = true
					end
				else
					if ws.place(pos_v, entry.name) then
						table.remove(place_nodes, i)
						changed = true
					end
				end
			end
			::continue::
		end
		if changed then
			update_hud()
			save_job()
		end
	end,
	on_start = function(self)
		core.after(0.2, update_hud)
	end,
	on_stop = function(self)
		if hud_id then
			core.localplayer:hud_remove(hud_id)
			hud_id = nil
		end
	end,
	cheat_settings = {
		range = { type = "number", default = 4, min = 1, max = 20 },
	},
})



local function do_schembuild(param, use_pos)
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

local function load_bx_schematic(uid, name, mts_data)
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

local function load_schematic_by_index(event_idx)
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

local function pos_marker(pos, texture)
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

local function sort_pos(pos1, pos2)
	pos1 = vector.copy(pos1)
	pos2 = vector.copy(pos2)
	if pos1.x > pos2.x then pos2.x, pos1.x = pos1.x, pos2.x end
	if pos1.y > pos2.y then pos2.y, pos1.y = pos1.y, pos2.y end
	if pos1.z > pos2.z then pos2.z, pos1.z = pos1.z, pos2.z end
	return pos1, pos2
end

local function schembuilder_serialize(pos1, pos2)
	pos1, pos2 = sort_pos(pos1, pos2)
	local get_node = core.get_node_or_nil
	local pos = vector.new(pos1.x, 0, 0)
	local count = 0
	local result = {}
	while pos.x <= pos2.x do
		pos.y = pos1.y
		while pos.y <= pos2.y do
			pos.z = pos1.z
			while pos.z <= pos2.z do
				local node = get_node(pos)
				if node.name ~= "air" and node.name ~= "ignore" then
					count = count + 1
					result[count] = {
						x = pos.x - pos1.x,
						y = pos.y - pos1.y,
						z = pos.z - pos1.z,
						name = node.name,
						param1 = node.param1 ~= 0 and node.param1 or nil,
						param2 = node.param2 ~= 0 and node.param2 or nil,
					}
				end
				pos.z = pos.z + 1
			end
			pos.y = pos.y + 1
		end
		pos.x = pos.x + 1
	end

	-- Build a schematic table for core.serialize_schematic
	local schem = {
		size = {x = pos2.x - pos1.x + 1, y = pos2.y - pos1.y + 1, z = pos2.z - pos1.z + 1},
		data = {},
	}
	-- Fill all positions (air if no node was captured)
	local idx = 1
	local pos_iter = vector.new(pos1.x, 0, 0)
	while pos_iter.x <= pos2.x do
		pos_iter.y = pos1.y
		while pos_iter.y <= pos2.y do
			pos_iter.z = pos1.z
			while pos_iter.z <= pos2.z do
				local node = get_node(pos_iter)
				if node.name ~= "air" and node.name ~= "ignore" then
					schem.data[idx] = {
						name = node.name,
						prob = node.param1 ~= 0 and node.param1 * 2 or 254,
						param2 = node.param2 or 0,
					}
				else
					schem.data[idx] = {name = "air", prob = 0, param2 = 0}
				end
				idx = idx + 1
				pos_iter.z = pos_iter.z + 1
			end
			pos_iter.y = pos_iter.y + 1
		end
		pos_iter.x = pos_iter.x + 1
	end

	return schem, count
end

core.register_chatcommand("ssave", {
	description = "Save the current region to schembuilder_output setting",
	func = function(param)
		if schembuilder.pos1 ~= nil and schembuilder.pos2 ~= nil then
			local schem, count = schembuilder_serialize(schembuilder.pos1, schembuilder.pos2)
			local mts_data = core.serialize_schematic(schem, "mts")
			local b64 = core.encode_base64(mts_data)
			core.settings:set("schembuilder_output", b64)
			ws.notify("Saved " .. count .. " nodes to schembuilder_output", ws.NOTIFY_INFO)
		end
	end,
})

-- SchemBuilder bot: walks to the nearest unplaced node and places it
if sbots and sbots.register_bot then
	local _item_cache = {}
	local _item_cache_time = 0

	-- Find a safe stand position near a target block so the player's head
	-- doesn't end up inside another block (to-be-placed or existing).
	local function compute_safe_stand_pos(target, nodes)
		local standing_candidates = {
			{x = 0, y = -2, z = 0},
			{x = 1, y = -1, z = 0},
			{x = -1, y = -1, z = 0},
			{x = 0, y = -1, z = 1},
			{x = 0, y = -1, z = -1},
			{x = 1, y = -2, z = 0},
			{x = -1, y = -2, z = 0},
			{x = 0, y = -2, z = 1},
			{x = 0, y = -2, z = -1},
		}

		-- Build a set of to-be-placed block positions for fast lookup
		local place_set = {}
		for _, entry in ipairs(nodes) do
			if entry.name ~= "air" then
				local key = entry.x .. "," .. entry.y .. "," .. entry.z
				place_set[key] = true
			end
		end

		for _, off in ipairs(standing_candidates) do
			local sx = target.x + off.x
			local sy = target.y + off.y
			local sz = target.z + off.z
			local head_y = sy + 1

			-- Check if a to-be-placed block occupies the head space
			if not place_set[sx .. "," .. head_y .. "," .. sz] then
				-- Check if an existing solid node is at the head space
				local node
				if core.get_node_or_nil then
					node = core.get_node_or_nil({x = sx, y = head_y, z = sz})
				end
				local blocked = node and node.name ~= "air"
					and node.name ~= "ignore"
					and (not core.registered_nodes or not core.registered_nodes[node.name]
						or not core.registered_nodes[node.name].buildable_to)
				if not blocked then
					return {x = sx, y = sy, z = sz}
				end
			end
		end
		return nil
	end

	local function has_item(name)
		local now = os.clock()
		if now - _item_cache_time > 0.3 then
			_item_cache = {}
			_item_cache_time = now
			if core.localplayer then
				local inv = core.get_inventory("current_player")
				if inv then
					for _, stack in ipairs(inv.main) do
						if not stack:is_empty() then
							_item_cache[stack:get_name()] = true
						end
					end
				end
			end
		end
		return _item_cache[name] or false
	end

	local function is_node_allowed(name)
		local mode = core.settings:get("schembuilderbot.filter_mode") or "all"
		if mode == "all" then return true end
		if not nlist then return true end
		local list_name = core.settings:get("schembuilderbot.filter_list") or "schembuilder"
		local items = nlist.get(list_name)
		if not items then return true end
		for _, item in ipairs(items) do
			if item == name then
				return mode == "include"
			end
		end
		return mode == "exclude"
	end

	local strategies = {}
	local function register_strategy(name, impl)
		strategies[name] = impl
	end

	register_strategy("closest", {
		find_target = function(nodes, pos, has_item, is_allowed)
			local px, py, pz = pos.x, pos.y, pos.z
			local best_idx, best_dist_sq
			for i, entry in ipairs(nodes) do
				if entry.name ~= "air" and has_item(entry.name) and is_allowed(entry.name) then
					local dx = entry.x - px
					local dy = entry.y - py
					local dz = entry.z - pz
					local dist_sq = dx*dx + dy*dy + dz*dz
					if not best_dist_sq or dist_sq < best_dist_sq then
						best_dist_sq = dist_sq
						best_idx = i
					end
				end
			end
			return best_idx
		end,
	})

	register_strategy("layer", {
		find_target = function(nodes, pos, has_item, is_allowed)
			local px, py, pz = pos.x, pos.y, pos.z
			local by_y = {}
			for i, entry in ipairs(nodes) do
				if entry.name ~= "air" and has_item(entry.name) and is_allowed(entry.name) then
					local y = entry.y
					by_y[y] = by_y[y] or {}
					table.insert(by_y[y], {index = i, entry = entry})
				end
			end
			local ys = {}
			for y, _ in pairs(by_y) do
				table.insert(ys, y)
			end
			table.sort(ys)
			if #ys == 0 then return nil end
			local target_y = ys[1]
			local best_idx, best_dist_sq
			for _, item in ipairs(by_y[target_y]) do
				local dx = item.entry.x - px
				local dy = item.entry.y - py
				local dz = item.entry.z - pz
				local dist_sq = dx*dx + dy*dy + dz*dz
				if not best_dist_sq or dist_sq < best_dist_sq then
					best_dist_sq = dist_sq
					best_idx = item.index
				end
			end
			return best_idx
		end,
		max_batch_y = function(pos) return pos.y end,
		get_needed_items = function(nodes, state)
			if not state or not state.target then return nil end
			local target_y = state.target.y
			local seen = {}
			local items = {}
			for _, entry in ipairs(nodes) do
				if entry.y >= target_y and entry.y <= target_y + 2
					and entry.name ~= "air" and entry.name ~= "ignore"
					and not seen[entry.name] then
					seen[entry.name] = true
					table.insert(items, entry.name)
				end
			end
			return items
		end,
	})

	register_strategy("top_to_bottom", {
		find_target = function(nodes, pos, has_item, is_allowed)
			local px, py, pz = pos.x, pos.y, pos.z
			local by_y = {}
			for i, entry in ipairs(nodes) do
				if entry.name ~= "air" and has_item(entry.name) and is_allowed(entry.name) then
					local y = entry.y
					by_y[y] = by_y[y] or {}
					table.insert(by_y[y], {index = i, entry = entry})
				end
			end
			local ys = {}
			for y, _ in pairs(by_y) do
				table.insert(ys, y)
			end
			table.sort(ys, function(a, b) return a > b end)
			if #ys == 0 then return nil end
			local target_y = ys[1]
			local best_idx, best_dist_sq
			for _, item in ipairs(by_y[target_y]) do
				local dx = item.entry.x - px
				local dy = item.entry.y - py
				local dz = item.entry.z - pz
				local dist_sq = dx*dx + dy*dy + dz*dz
				if not best_dist_sq or dist_sq < best_dist_sq then
					best_dist_sq = dist_sq
					best_idx = item.index
				end
			end
			return best_idx
		end,
		max_batch_y = function(pos) return pos.y end,
		get_needed_items = function(nodes, state)
			if not state or not state.target then return nil end
			local target_y = state.target.y
			local seen = {}
			local items = {}
			for _, entry in ipairs(nodes) do
				if entry.y == target_y and entry.name ~= "air" and entry.name ~= "ignore" and not seen[entry.name] then
					seen[entry.name] = true
					table.insert(items, entry.name)
				end
			end
			return items
		end,
	})

	register_strategy("column", {
		find_target = function(nodes, pos, has_item, is_allowed)
			local px, py, pz = pos.x, pos.y, pos.z
			local by_col = {}
			for i, entry in ipairs(nodes) do
				if entry.name ~= "air" and has_item(entry.name) and is_allowed(entry.name) then
					local key = entry.x .. "," .. entry.z
					by_col[key] = by_col[key] or {}
					table.insert(by_col[key], {index = i, entry = entry})
				end
			end
			local best_col, best_dist_sq
			for _, col in pairs(by_col) do
				local e = col[1].entry
				local dx = e.x - px
				local dz = e.z - pz
				local dist_sq = dx*dx + dz*dz
				if not best_dist_sq or dist_sq < best_dist_sq then
					best_dist_sq = dist_sq
					best_col = col
				end
			end
			if not best_col then return nil end
			local best_idx, best_y
			for _, item in ipairs(best_col) do
				if not best_y or item.entry.y < best_y then
					best_y = item.entry.y
					best_idx = item.index
				end
			end
			return best_idx
		end,
		get_needed_items = function(nodes, state)
			if not state or not state.target then return nil end
			local key = state.target.x .. "," .. state.target.z
			local seen = {}
			local items = {}
			for _, entry in ipairs(nodes) do
				local ek = entry.x .. "," .. entry.z
				if ek == key and entry.name ~= "air" and entry.name ~= "ignore" and not seen[entry.name] then
					seen[entry.name] = true
					table.insert(items, entry.name)
				end
			end
			return items
		end,
	})

	register_strategy("by_material", {
		find_target = function(nodes, pos, has_item, is_allowed)
			local px, py, pz = pos.x, pos.y, pos.z
			local by_name = {}
			for i, entry in ipairs(nodes) do
				if entry.name ~= "air" and has_item(entry.name) and is_allowed(entry.name) then
					local n = entry.name
					by_name[n] = by_name[n] or {}
					table.insert(by_name[n], {index = i, entry = entry})
				end
			end
			local best_group, best_count
			for _, group in pairs(by_name) do
				if not best_count or #group > best_count then
					best_count = #group
					best_group = group
				end
			end
			if not best_group then return nil end
			local best_idx, best_dist_sq
			for _, item in ipairs(best_group) do
				local dx = item.entry.x - px
				local dy = item.entry.y - py
				local dz = item.entry.z - pz
				local dist_sq = dx*dx + dy*dy + dz*dz
				if not best_dist_sq or dist_sq < best_dist_sq then
					best_dist_sq = dist_sq
					best_idx = item.index
				end
			end
			return best_idx
		end,
		batch_filter = function(entry, state)
			return entry.name == state.target.name
		end,
		get_needed_items = function(nodes, state)
			if not state or not state.target then return nil end
			return {state.target.name}
		end,
	})

	register_strategy("random", {
		find_target = function(nodes, pos, has_item, is_allowed)
			local candidates = {}
			for i, entry in ipairs(nodes) do
				if is_allowed(entry.name) then
					table.insert(candidates, i)
				end
			end
			if #candidates == 0 then return nil end
			return candidates[math.random(1, #candidates)]
		end,
		get_needed_items = function() return {} end,
		batch_filter = function() return true end,
	})

	local function pick_random_block()
		local inv = core.get_inventory("current_player")
		if not inv or not inv.main then return nil end
		local pool, total = {}, 0
		for _, stack in ipairs(inv.main) do
			if not stack:is_empty() then
				local name = stack:get_name()
				if core.get_node_def(name) then
					local count = stack:get_count()
					pool[name] = (pool[name] or 0) + count
					total = total + count
				end
			end
		end
		if total == 0 then return nil end
		local r = math.random(1, total)
		local acc = 0
		for name, count in pairs(pool) do
			acc = acc + count
			if r <= acc then return name end
		end
		return nil
	end

	sbots.register_bot("SchemBuilderBot", {
		description = "Bot that builds schematics",
		moving_target = true,
		stand_waiting = true,
		landing_distance = 3,
		cheat_settings = {
			place_cooldown = { type = "number", default = 0.1, min = 0, max = 5 },
			batch_size = { type = "number", default = 8, min = 1, max = 64 },
			place_strategy = { type = "enum", default = "closest", values = {"closest", "layer", "top_to_bottom", "column", "by_material", "random"} },
			filter_mode = { type = "string", default = "all" },
			filter_list = { type = "string", default = "schembuilder" },
		},
		find_pos = function(self, pos)
			if #place_nodes == 0 then return end
			local px, py, pz = pos.x, pos.y, pos.z
			self._current_entry = nil
			self._strat_state = nil

			local name = core.settings:get("schembuilderbot.place_strategy") or "closest"
			local strat = strategies[name] or strategies.closest

			local idx = strat.find_target(place_nodes, pos, has_item, is_node_allowed)
			if idx then
				self._current_entry = place_nodes[idx]
				local target = place_nodes[idx]
				self._strat_state = {
					target = target,
					max_batch_y = strat.max_batch_y and strat.max_batch_y(pos),
				}
				self._is_supply_target = nil
				-- Layer strategy: place 3 layers at once
				if name == "layer" then
					self._strat_state.max_batch_y = target.y + 2
				end
				-- Compute a safe stand position so the player's head isn't in a block
				local safe = compute_safe_stand_pos(target, place_nodes)
				if safe then
					return vector.new(safe.x, safe.y, safe.z)
				end
				return vector.new(target.x, target.y - 1, target.z)
			end

			-- No buildable nodes found, try nearest supply chest
			local closest_key, closest_dist_sq2
			for key, cpos in pairs(supply_chests) do
				local dx = cpos.x - px
				local dy = cpos.y - py
				local dz = cpos.z - pz
				local dist_sq = dx*dx + dy*dy + dz*dz
				if not closest_dist_sq2 or dist_sq < closest_dist_sq2 then
					closest_dist_sq2 = dist_sq
					closest_key = key
				end
			end
			if closest_key then
				self._current_entry = supply_chests[closest_key]
				self._is_supply_target = true
				return supply_chests[closest_key]
			end
		end,
		update_pos = function(self, pos)
			if self._is_supply_target then
				return self._current_entry
			end
			if self._current_entry then
				local found = false
				for _, e in ipairs(place_nodes) do
					if e == self._current_entry then
						found = true
						break
					end
				end
				if found and has_item(self._current_entry.name) then
					return self._current_entry
				end
			end
			self._is_supply_target = nil
			self._current_entry = nil
			return self:find_pos(pos)
		end,
		do_pos = function(self, pos)
			if not self._current_entry then return true end

			if self._is_supply_target then
				self._is_supply_target = nil
				self._current_entry = nil
				local items
				local strat_name = core.settings:get("schembuilderbot.place_strategy") or "closest"
				local strat = strategies[strat_name] or strategies.closest
				if strat.get_needed_items then
					items = strat.get_needed_items(place_nodes, self._strat_state)
				end
				if not items then
					items = {}
					local seen = {}
					for _, entry in ipairs(place_nodes) do
						if entry.name ~= "air" and entry.name ~= "ignore" and not seen[entry.name] then
							seen[entry.name] = true
							table.insert(items, entry.name)
						end
					end
				end
				if #items > 0 then
					local range = tonumber(core.settings:get("schematic_looter.range")) or 5
					ws.loot_list(items, range, 64)
				end
				self.target_pos = nil
				return true
			end

			local cooldown = tonumber(core.settings:get("schembuilderbot.place_cooldown")) or 0.1
			if self._last_place_time and os.clock() - self._last_place_time < cooldown then
				return false
			end
			local batch = tonumber(core.settings:get("schembuilderbot.batch_size")) or 8
			local range = tonumber(core.settings:get("placelitem.range")) or 4
			local strat_name = core.settings:get("schembuilderbot.place_strategy") or "closest"
			local strat = strategies[strat_name] or strategies.closest
			local is_random = strat_name == "random"
			local px, py, pz = pos.x, pos.y, pos.z
			local placed = 0

			-- Place the primary target first
			local target_entry = self._current_entry
			-- Dig any existing node at the target position first
			local tpos = {x = target_entry.x, y = target_entry.y, z = target_entry.z}
			local existing = core.get_node_or_nil(tpos)
			if existing and existing.name ~= "air" and existing.name ~= "ignore" then
				if ws.dig then
					ws.dig(tpos)
				end
			end
			local place_item = is_random and pick_random_block() or target_entry.name
			if place_item and ws.place(target_entry, place_item) then
				self._last_place_time = os.clock()
				for i = #place_nodes, 1, -1 do
					if place_nodes[i] == target_entry then
						table.remove(place_nodes, i)
						break
					end
				end
				placed = 1
			else
				local node = core.get_node_or_nil(target_entry)
				if node and (is_random and node.name ~= "air" or node.name == target_entry.name) then
					for i = #place_nodes, 1, -1 do
						if place_nodes[i] == target_entry then
							table.remove(place_nodes, i)
							break
						end
					end
				end
			end
			self._current_entry = nil

			-- Also place nearby nodes in the same tick
			if placed > 0 and #place_nodes > 0 then
				local max_y = self._strat_state and self._strat_state.max_batch_y
				for i = #place_nodes, 1, -1 do
					if placed >= batch then break end
					local entry = place_nodes[i]
					if entry.name ~= "air" and (not max_y or entry.y <= max_y) and is_node_allowed(entry.name) then
						if not strat.batch_filter or strat.batch_filter(entry, self._strat_state) then
							local dx = entry.x - px
							local dy = entry.y - py
							local dz = entry.z - pz
							if dx*dx + dy*dy + dz*dz <= range*range then
								local batch_item = is_random and pick_random_block() or entry.name
								if batch_item then
									local epos = {x = entry.x, y = entry.y, z = entry.z}
									local enode = core.get_node_or_nil(epos)
									if enode and enode.name ~= "air" and enode.name ~= "ignore" then
										if ws.dig then ws.dig(epos) end
									end
								end
								if batch_item and ws.place(entry, batch_item) then
									table.remove(place_nodes, i)
									placed = placed + 1
								else
									local node = core.get_node_or_nil(entry)
									if node and (is_random and node.name ~= "air" or node.name == entry.name) then
										table.remove(place_nodes, i)
									end
								end
							end
						end
					end
				end
			end

			self.target_pos = nil
			update_hud()
			save_job()
			return true
		end,
		do_step = function(self, dtime)
			-- If target was placed by PlaceLiteM, reset
			if self._current_entry then
				local found = false
				for _, e in ipairs(place_nodes) do
					if e == self._current_entry then
						found = true
						break
					end
				end
				if not found then
					self._current_entry = nil
					self.stage = 0
				end
			end
		end,
	})
end

-- SchematicLooter: scan nearby containers for items needed by the current schematic
ws.rg("SchematicLooter", {
	category = "Inventory",
	setting = "schematic_looter",
	description = "Auto-loot materials from schematics",
	delay = 1,
	on_step = function(self, dtime)
		if #place_nodes == 0 then return end
		local items = {}
		local seen = {}
		for _, entry in ipairs(place_nodes) do
			if entry.name ~= "air" and entry.name ~= "ignore" and not seen[entry.name] then
				seen[entry.name] = true
				table.insert(items, entry.name)
			end
		end
		if #items == 0 then return end
		local range = tonumber(core.settings:get("schematic_looter.range")) or 5
		local max_per = tonumber(core.settings:get("schematic_looter.max_per_scan")) or 16

		if core.localplayer then
			local pos = core.localplayer:get_pos()
			local minp = vector.offset(pos, -range, -range, -range)
			local maxp = vector.offset(pos, range, range, range)
			for _, cpos in ipairs(core.find_nodes_with_meta(minp, maxp)) do
				add_supply_chest(cpos)
			end
		end

		ws.loot_list(items, range, max_per)
	end,
	cheat_settings = {
		range = { type = "number", default = 5, min = 1, max = 20 },
		max_per_scan = { type = "number", default = 16, min = 1, max = 64 },
	},
})

core.register_chatcommand("schemclear", {
	description = "Clear the current schematic build and saved job data",
	func = function(param)
		place_nodes = {}
		clear_supply_chests()
		clear_job()
		if hud_id then
			core.localplayer:hud_remove(hud_id)
			hud_id = nil
		end
		ws.notify("Schematic build cleared", ws.NOTIFY_INFO)
		return true
	end,
})

-- Restore saved job on init and reconnect
local function restore_job()
	if load_job() and #place_nodes > 0 then
		for _, n in ipairs(place_nodes) do
			add_preview_if_needed(n, n.name)
		end
		core.after(0.1, update_hud)
	end
end

restore_job()

core.register_on_connect(function()
	restore_job()
end)

-- Exposed for other mods (e.g., mapart)
schembuilder_api = {
	load_mts = function(filepath, label, use_pos)
		if type(do_schembuild) ~= "function" then
			return false, "schembuilder not initialized"
		end
		local ok, err, sparam = do_schembuild("file:" .. filepath, use_pos)
		if ok then
			create_build(sparam or ("file:" .. filepath), label or "schematic")
		end
		return ok, err
	end,
}
