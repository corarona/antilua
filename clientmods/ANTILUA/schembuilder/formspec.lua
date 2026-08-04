-- Schematic browser formspec
local _bx_status = ""
local _sel_bx_result = nil
local _sel_bx_dl = nil
local schem_cache = {}
local _selected_schem_name = nil

-- Right-side sub-tab system (shared with other inventory tabs).
schembuilder.browser_subtabs = core.al_subtabs.new({
	id = "schembrowser",
	labels = {
		"Browse Schematics", "Saved Builds", "BlockExchange", "Mapart", "Create Shapes",
	},
})

-- Builds only the schembuilder content for `tab`, reflowed to fit a content
-- width of `cw` (no formspec chrome, no sub-tab buttons).
function schembuilder.build_browser_content(tab, cw)
	cw = cw or 10
	local sid = get_server_id()
	local fs = ""

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
				"textlist[0,1;" .. cw .. ",7;schem_list;" .. table.concat(schems, ",") .. ";0]" ..
				"button[0,8.5;4,0.8;schem_load;Load]" ..
				"button[0,9.4;4,0.6;schem_stop;Stop Build]"
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
			local bw = (cw - 0.5) / 5
			fs = fs .. "label[0,0.6;Saved builds for " .. core.formspec_escape(sid) .. ":]" ..
				"textlist[0,1;" .. cw .. ",5;build_list;" .. table.concat(entries, ",") .. ";0]" ..
				"button[0,6.5;" .. bw .. ",0.8;build_load;Load]" ..
				"button[" .. (bw + 0.1) .. ",6.5;" .. bw .. ",0.8;build_restart;Restart]" ..
				"button[" .. (2 * (bw + 0.1)) .. ",6.5;" .. bw .. ",0.8;build_delete;Delete]" ..
				"button[" .. (3 * (bw + 0.1)) .. ",6.5;" .. bw .. ",0.8;build_clear_particles;Particles]" ..
				"button[" .. (4 * (bw + 0.1)) .. ",6.5;" .. bw .. ",0.8;build_stop;Stop]"
		end
	elseif tab == 2 then
		-- Tab 2: BlockExchange
		local logged_in = blockexchange and blockexchange.logged_in
		if logged_in then
			local bx_btn_x = cw - 2.5
			fs = fs .. "label[0,0.6;Logged in as: " .. core.formspec_escape(blockexchange.username) .. "]" ..
				"field[0,1.5;3.5,0.6;bx_user;;]" ..
				"label[0,2.3;Username]" ..
				"field[3.6,1.5;3.5,0.6;bx_name;;]" ..
				"label[3.6,2.3;Schematic name]" ..
				"button[" .. bx_btn_x .. ",1.5;2.5,0.6;bx_search;Search]"
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
			fs = fs .. "textlist[0,3;" .. cw .. ",4.5;bx_results;" .. table.concat(entries, ",") .. ";0]"
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
				"button[" .. (cw - 1.6) .. ",9;1.6,0.8;bx_load_dl;Load]"
		end
	elseif tab == 3 then
		if schembuilder._mapart_tab_fn then
			fs = schembuilder._mapart_tab_fn(fs, tab)
		else
			fs = fs .. "label[0,1;Mapart mod not loaded. Please wait...]"
		end
	elseif tab == 4 then
		local function sv(name, default)
			return core.settings:get(name) or default
		end
		local shape_names = {"Cube","Sphere","Circle","Ellipse","Pyramid","Cylinder","Dome","Cone"}
		local shape_idx = 1
		local saved_shape = sv("schembuilder_shape_type", "Cube")
		for i, n in ipairs(shape_names) do
			if n == saved_shape then shape_idx = i; break end
		end
		local node_w = cw - 5.6
		local dim_z_w = cw - 7.1
		local btn_w = (cw - 0.3) / 2
		fs = fs ..
			"dropdown[0,1;5,0.8;shape_type;" ..
				table.concat(shape_names, ",") .. ";" .. shape_idx .. "]" ..
			"field[5.5,1;" .. node_w .. ",0.8;node_name;Node Name;" ..
				core.formspec_escape(sv("schembuilder_node_name", "mcl_core:stone")) .. "]" ..
			"field[0,2;3,0.8;dim_x;Width;" .. sv("schembuilder_dim_x", "8") .. "]" ..
			"field[3.5,2;3,0.8;dim_y;Height;" .. sv("schembuilder_dim_y", "8") .. "]" ..
			"field[7.1,2;" .. dim_z_w .. ",0.8;dim_z;Depth;" .. sv("schembuilder_dim_z", "8") .. "]" ..
			"checkbox[0,2.8;hollow;Hollow;" ..
				(core.settings:get_bool("schembuilder_hollow") and "true" or "false") .. "]" ..
			"label[0,3.5;Place offset from player:]" ..
			"field[0,3.8;2.5,0.8;offset_x;X;" .. sv("schembuilder_offset_x", "0") .. "]" ..
			"field[3,3.8;2.5,0.8;offset_y;Y;" .. sv("schembuilder_offset_y", "1") .. "]" ..
			"field[6,3.8;2.5,0.8;offset_z;Z;" .. sv("schembuilder_offset_z", "5") .. "]" ..
			"button[0,5;" .. btn_w .. ",0.8;shape_generate;Generate to Memory]" ..
			"button[" .. (btn_w + 0.3) .. ",5;" .. btn_w .. ",0.8;shape_genplace;Generate && Place Now]"
	end

	return fs
end

local function schembuilder_show_standalone()
	local tab = schembuilder.browser_subtabs.get()
	local theme_bg = core.settings:get("theme_bg") or "#121212"
	local fs = "formspec_version[10]size[10,10]no_prepend[]bgcolor[" .. theme_bg .. ";true]" ..
		"tabheader[0,0;tabs;Browse Schematics,Saved Builds,BlockExchange,Mapart,Create Shapes;" .. (tab + 1) .. "]" ..
		schembuilder.build_browser_content(tab, 10) ..
		"button[8,9;2,0.8;close;Close]"
	core.show_formspec("schembuilder:browser", fs)
end

local schembuilder_redraw = schembuilder_show_standalone

-- Redirect where schembuilder re-renders itself. The inventory tab sets this
-- to re-show the tab page instead of the standalone formspec.
function schembuilder.set_redraw(fn)
	schembuilder_redraw = fn or schembuilder_show_standalone
end

function show_browser_form(tab)
	tab = tab or 0
	schembuilder.browser_subtabs.set(tab)
	return schembuilder_redraw()
end

function parse_list_event(event)
	if not event then return nil end
	local parts = event:split(":")
	if #parts == 2 then
		return tonumber(parts[2])
	end
	return tonumber(event)
end

--
-- Inventory tab (registered directly: the mod loader orders the `inventory`
-- mod before schembuilder because schembuilder optionally depends on it)
--

if core.inv_tabs and core.inv_tabs.register_tab then
	core.inv_tabs.register_tab({
		id = "schembuilder",
		title = "Schematics",
		build = function(ctx)
			local w = (ctx and ctx.width) or 11.75
			local lay = schembuilder.browser_subtabs.layout(w)
			return schembuilder.build_browser_content(schembuilder.browser_subtabs.get(), lay.content_right)
				.. schembuilder.browser_subtabs.render(w, (ctx and ctx.height) or 10)
		end,
		handle = function(fields)
			return schembuilder.handle_browser_fields(fields)
		end,
		-- The browser UI is self-contained and lays itself out against the
		-- right-side sub-tab column.
		show_inventory = false,
		pad = false,
	})
	-- Re-render inside the tab page when schembuilder asks to redraw, falling
	-- back to the standalone formspec when the tab isn't open.
	schembuilder.set_redraw(function()
		if core.inv_tabs.is_open() then
			core.inv_tabs.set_active("schembuilder")
		else
			schembuilder_show_standalone()
		end
	end)
end
