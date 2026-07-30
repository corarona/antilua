-- Schematic browser formspec
local _bx_status = ""
local _sel_bx_result = nil
local _sel_bx_dl = nil
local schem_cache = {}
local _selected_schem_name = nil

function show_browser_form(tab)
	tab = tab or 0
	local sid = get_server_id()
	local theme_bg = core.settings:get("theme_bg") or "#121212"
	local fs = "formspec_version[10]size[10,10]no_prepend[]bgcolor[" .. theme_bg .. ";true]" ..
		"tabheader[0,0;tabs;Browse Schematics,Saved Builds,BlockExchange,Mapart,Create Shapes;" .. (tab + 1) .. "]" ..
		"button[8,9;2,0.8;close;Close]"

	if tab == 0 then
		local schem_path
		if type(core.get_modpath_real) == "function" then
			schem_path = core.get_modpath_real("schembuilder") .. "/schematics"
		else
			schem_path = modpath .. "/schematics"
		end
		local user_path = core.get_data_path() .. "schematics"
		local schems = {}
		schem_cache = {}

		local function scan_dir(dir, prefix)
			local list = core.get_dir_list(dir, false)
			local files = (type(list) == "table") and list or {}
			for _, f in ipairs(files) do
				if f:match("%.mts$") then
					local display = prefix and (prefix .. f) or f
					local fullpath = dir .. "/" .. f
					table.insert(schems, core.formspec_escape(display))
					-- Parse header for size info
					local ok, data = pcall(core.read_file, fullpath)
					if ok then
						local ok2, schem = pcall(core.read_schematic, data, {})
						if ok2 and schem then
							local count = 0
							for _, entry in ipairs(schem.data) do
								if entry.name ~= "air" and entry.prob ~= 0 then
									count = count + 1
								end
							end
							schem_cache[display] = {
								size = schem.size,
								count = count,
							}
						end
					end
				end
			end
		end

		scan_dir(schem_path)
		scan_dir(user_path, "[U] ")

		if #schems == 0 then
			fs = fs .. "label[0,1;No .mts schematics found]"
		else
			fs = fs .. "label[0,0.6;Available schematics:  ([U] = user)]" ..
				"textlist[0,1;10,7;schem_list;" .. table.concat(schems, ",") .. ";0]" ..
				"button[0,8.5;4,0.8;schem_load;Load]"
			-- Show info for selected schematic
			if _selected_schem_name and schem_cache[_selected_schem_name] then
				local info = schem_cache[_selected_schem_name]
				fs = fs .. "label[4.5,8.5;Size: " .. info.size.x .. "x" .. info.size.y .. "x" .. info.size.z
					.. " (" .. info.count .. " nodes)]"
			end
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
	elseif tab == 4 then
		local function sv(name, default)
			return core.settings:get(name) or default
		end
		local shape_names = {"Cube","Sphere","Circle","Ellipse","Pyramid","Cylinder"}
		local shape_idx = 1
		local saved_shape = sv("schembuilder_shape_type", "Cube")
		for i, n in ipairs(shape_names) do
			if n == saved_shape then shape_idx = i; break end
		end
		fs = fs ..
			"dropdown[0,1;5,0.8;shape_type;" ..
				table.concat(shape_names, ",") .. ";" .. shape_idx .. "]" ..
			"field[5.5,1;4.5,0.8;node_name;Node Name;" ..
				core.formspec_escape(sv("schembuilder_node_name", "mcl_core:stone")) .. "]" ..
			"field[0,2;3,0.8;dim_x;Width;" .. sv("schembuilder_dim_x", "8") .. "]" ..
			"field[3.5,2;3,0.8;dim_y;Height;" .. sv("schembuilder_dim_y", "8") .. "]" ..
			"field[7,2;3,0.8;dim_z;Depth;" .. sv("schembuilder_dim_z", "8") .. "]" ..
			"checkbox[0,2.8;hollow;Hollow;" ..
				(core.settings:get_bool("schembuilder_hollow") and "true" or "false") .. "]" ..
			"label[0,3.5;Place offset from player:]" ..
			"field[0,3.8;2.5,0.8;offset_x;X;" .. sv("schembuilder_offset_x", "0") .. "]" ..
			"field[3,3.8;2.5,0.8;offset_y;Y;" .. sv("schembuilder_offset_y", "1") .. "]" ..
			"field[6,3.8;2.5,0.8;offset_z;Z;" .. sv("schembuilder_offset_z", "5") .. "]" ..
			"button[0,5;4.5,0.8;shape_generate;Generate to Memory]" ..
			"button[5.5,5;4.5,0.8;shape_genplace;Generate && Place Now]"
	end

	core.show_formspec("schembuilder:browser", fs)
end

function parse_list_event(event)
	if not event then return nil end
	local parts = event:split(":")
	if #parts == 2 then
		return tonumber(parts[2])
	end
	return tonumber(event)
end

ws.rg("AutoSchemPlace", {
	category = "Place",
	setting = "autoschemplace",
	description = "Auto-place schematic nodes within range using strategy system",
	on_step = function(self, dtime)
		if #place_nodes == 0 then
			if hud_id then
				core.localplayer:hud_remove(hud_id)
				hud_id = nil
			end
			return
		end
		local pp = core.localplayer:get_pos()
		if not pp then return end

		local range = tonumber(core.settings:get("autoschemplace.range")) or 4
		local strat_name = core.settings:get("autoschemplace.place_strategy") or "closest"
		local strat = schembuilder.placer.strategies[strat_name] or schembuilder.placer.strategies.closest
		local item_cache = self._item_cache or schembuilder.placer.make_item_cache()
		self._item_cache = item_cache

		local has_item = function(name) return item_cache.has(name) end
		local is_allowed = function(name)
			local mode = core.settings:get("autoschemplace.filter_mode") or "all"
			local list = core.settings:get("autoschemplace.filter_list") or "schembuilder"
			return schembuilder.placer.is_node_allowed(name, mode, list)
		end

		local placer_state = self._placer_state or {}
		self._placer_state = placer_state

		-- Find target from nodes within range
		local candidates = {}
		for i, entry in ipairs(place_nodes) do
			if entry.name ~= "air" and has_item(entry.name) and is_allowed(entry.name) then
				local dx = entry.x - pp.x
				local dy = entry.y - pp.y
				local dz = entry.z - pp.z
				if dx*dx + dy*dy + dz*dz <= range*range then
					table.insert(candidates, i)
				end
			end
		end

		if #candidates == 0 then
			-- Try supply chests
			local closest_key, closest_dsq
			for key, cpos in pairs(supply_chests) do
				local dx = cpos.x - pp.x
				local dy = cpos.y - pp.y
				local dz = cpos.z - pp.z
				local dsq = dx*dx + dy*dy + dz*dz
				if not closest_dsq or dsq < closest_dsq then
					closest_dsq = dsq
					closest_key = key
				end
			end
			if closest_key then
				-- Loot supply chest
				local items = {}
				local seen = {}
				for _, entry in ipairs(place_nodes) do
					if entry.name ~= "air" and entry.name ~= "ignore" and not seen[entry.name] then
						seen[entry.name] = true
						table.insert(items, entry.name)
					end
				end
				if #items > 0 then
					local lrange = tonumber(core.settings:get("schematic_looter.range")) or 5
					ws.loot_list(items, lrange, 64)
				end
			end
			return
		end

		-- Pick target using strategy
		local filtered = {}
		for _, i in ipairs(candidates) do
			filtered[#filtered + 1] = place_nodes[i]
		end
		local idx = strat.find_target(filtered, pp, has_item, is_allowed, placer_state)
		if not idx then return end
		local target_entry = filtered[idx]

		local opts = {
			batch_size = tonumber(core.settings:get("autoschemplace.batch_size")) or 4,
			range = range,
			cooldown = 0,
			strategy_name = strat_name,
			filter_mode = core.settings:get("autoschemplace.filter_mode") or "all",
			filter_list = core.settings:get("autoschemplace.filter_list") or "schembuilder",
			item_cache = item_cache,
		}

		local placed = schembuilder.placer.execute_batch(placer_state, target_entry, pp, place_nodes, opts)
		if placed > 0 then
			update_hud()
			save_job()
		end
	end,
	on_start = function(self)
		self._placer_state = {}
		self._item_cache = nil
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
		batch_size = { type = "number", default = 4, min = 1, max = 64 },
		place_strategy = { type = "enum", default = "closest",
			values = {"closest", "layer", "top_to_bottom", "column", "by_material", "random", "cluster"} },
		filter_mode = { type = "enum", default = "all", values = {"all", "include", "exclude"} },
		filter_list = { type = "string", default = "schembuilder" },
	},
})
