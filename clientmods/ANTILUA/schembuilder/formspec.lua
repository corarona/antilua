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
		fs = fs ..
			"dropdown[0,1;5,0.8;shape_type;Cube,Sphere,Circle,Ellipse,Pyramid,Cylinder;1]" ..
			"field[5.5,1;4.5,0.8;node_name;Node Name;mcl_core:stone]" ..
			"field[0,2;3,0.8;dim_x;Width;8]" ..
			"field[3.5,2;3,0.8;dim_y;Height;8]" ..
			"field[7,2;3,0.8;dim_z;Depth;8]" ..
			"checkbox[0,2.8;hollow;Hollow;false]" ..
			"label[0,3.5;Place offset from player:]" ..
			"field[0,3.8;2.5,0.8;offset_x;X;0]" ..
			"field[3,3.8;2.5,0.8;offset_y;Y;1]" ..
			"field[6,3.8;2.5,0.8;offset_z;Z;5]" ..
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
