local function get_node_invs(pos)
	local invs = {}
	for _, p in pairs(core.find_nodes_with_meta(
		vector.offset(pos, -4.5, -4.5, -4.5),
		vector.offset(pos, 4.5, 4.5, 4.5))) do
		local inv = core.get_inventory("nodemeta:" .. p.x .. "," .. p.y .. "," .. p.z)
		if inv then
			table.insert(invs, {pos = p, inv = inv})
		end
	end
	return invs
end

invviewer = {}

local _sel_nearby_node
local _sel_nearby_list
local inv_node_filter = ""
local inv_item_filter = ""

-- Current openInv sub-view (0 = Inventories, 1 = Nearby), rendered as a
-- right-side vertical sub-tab column.
local inv_subtabs = core.al_subtabs.new({
	id = "openinv",
	labels = { "Inventories", "Nearby" },
})

-- Current selection state (list name / nearby node), used when the UI is
-- embedded as an inventory tab.
local _cur_param = nil
local _cur_ll = nil

-- Builds only the openInv content (sub-views + right-side sub-tab column).
-- Returns nil if the requested inventory list doesn't exist. `width`/`height`
-- are the page dimensions the content is rendered into.
function invviewer.build_content(param, ll, tab, width, height)
	tab = tab or 0
	width = width or 11.75
	height = height or 12.425
	local name = core.localplayer:get_name()
	local inv = core.get_inventory("player:" .. name)
	local af = core.al_formspec

	-- Right-side vertical sub-tab column, clear of the Antilua inventory tab
	-- bar at the top.
	local lay = inv_subtabs.layout(width)
	local content_right = lay.content_right

	-- "Your inventory" anchored to the bottom, left of the tab column.
	local main_y = height - 4.4
	local hot_y = height - 1.4
	local content_bottom = main_y - 0.6

	local sb = af.new()

	-- Sub-tab buttons (vertical, right side).
	sb:add(inv_subtabs.render(width, height))

	if tab == 0 then
		local dlist_tb = {}
		local i, idx = 1, 1
		for k in pairs(inv) do
			if not param or param == "" then
				param = k
			end
			dlist_tb[i] = k
			if k == param then idx = i end
			i = i + 1
		end

		if not inv[param] then
			return nil
		end

		local x, y = 0, 1
		for _ in pairs(inv[param]) do
			if x < 8 then x = x + 1 elseif y < 3 then y = y + 1 end
		end
		y = math.min(y, math.max(math.floor(content_bottom - 1.75), 1))

		sb:add(
			af.label(0.375, 0.375, "Show Inv List"),
			af.dropdown(content_right - 2.3, 0.175, 2.3, "select_list", dlist_tb, idx),
			ws.get_itemslot_bg_v4(0.375, 1.75, x, y),
			"list[current_player;" .. param .. ";0.375,1.75;" .. x .. "," .. y .. ";]",
			"listring[current_player;" .. param .. "]",
			"listring[current_player;main]"
		)
	else
		local pos = core.localplayer and core.localplayer:get_pos()
		local range = 6
		local minp = vector.offset(pos, -range, -range, -range)
		local maxp = vector.offset(pos, range, range, range)
		local nodes = core.find_nodes_with_meta(minp, maxp) or {}
		local selected_node = ll

		local node_entries = {}
		local sel_idx = 1
		for id, p in ipairs(nodes) do
			local n = core.get_node_or_nil(p)
			if n then
				if inv_node_filter == "" or ws.fuzzy_match(n.name, inv_node_filter) then
					local label = n.name .. " (" .. p.x .. "," .. p.y .. "," .. p.z .. ")"
					table.insert(node_entries, label)
					if selected_node and vector.equals(p, selected_node) then
						sel_idx = #node_entries
						selected_node = p
					end
				end
			end
		end
		if not selected_node and #nodes > 0 then
			selected_node = nodes[1]
		end

		sb:add(
			af.label(0.375, 0.375, "Nearby inventory nodes"),
			af.searchbar(0.375, 0.7, content_right - 0.375, "inv_node_filter", { default = inv_node_filter, button_width = 1.2 })
		)

		if #node_entries == 0 then
			sb:add(af.label(0.375, 1.5, inv_node_filter ~= "" and "No matching nodes" or "No inventory nodes nearby"))
		else
			local tl_h = math.max(content_bottom - 1.6, 1)
			sb:add(af.textlist(0.375, 1.4, 4.5, tl_h, "nearby_nodes", node_entries, sel_idx))

			if selected_node then
				local spos = selected_node.x .. "," .. selected_node.y .. "," .. selected_node.z
				local ninv = core.get_inventory("nodemeta:" .. spos)
				if ninv then
					local list_keys = {}
					for k in pairs(ninv) do
						table.insert(list_keys, k)
					end
					table.sort(list_keys)

					local chosen_list = param or list_keys[1]
					local list_idx = 1
					for idx2, k in ipairs(list_keys) do
						if k == chosen_list then list_idx = idx2; break end
					end

					local node_name = core.get_node_or_nil(selected_node)
					node_name = node_name and node_name.name or "unknown"
					local dx = 5.25
					local dw = math.max(content_right - dx - 0.1, 1)
					sb:add(
						af.label(dx, 0.375, node_name),
						af.label(dx, 0.75, spos),
						af.dropdown(dx, 1.4, dw, "nearby_list", list_keys, list_idx),
						af.searchbar(dx, 2.0, dw, "inv_item_filter", { default = inv_item_filter, button_width = 1.2 })
					)

					local list_data = ninv[chosen_list]
					if list_data then
						local lines = {}
						local slots = 0
						for _ in pairs(list_data) do slots = slots + 1 end
						local shown = 0
						for si, stack in ipairs(list_data) do
							if shown >= 54 then
								table.insert(lines, "... and " .. (slots - 54) .. " more")
								break
							end
							shown = shown + 1
							if stack and not stack:is_empty() then
								if inv_item_filter == "" or ws.fuzzy_match(stack:get_name(), inv_item_filter) then
									table.insert(lines, string.format("[%d] %s x%d", si, stack:get_name(), stack:get_count()))
								end
							elseif inv_item_filter == "" then
								table.insert(lines, string.format("[%d] (empty)", si))
							end
						end
						if slots > 54 then
							table.insert(lines, "... and " .. (slots - 54) .. " more")
						end
						if #lines == 0 then
							lines = {"(no matching items)"}
						end
						local items_h = math.max(content_bottom - 3.0, 1)
						sb:add(af.textlist(dx, 2.8, dw, items_h, "nearby_items", lines, 0))
					end
				end
			end
		end
	end

	-- Player inventory at the bottom (if the page has room), left of the tab
	-- column.
	if content_bottom >= 2.5 then
		sb:add(
			af.label(0.375, main_y - 0.5, "Your Inventory"),
			ws.get_itemslot_bg_v4(0.375, main_y, 8, 3),
			"list[current_player;main;0.375," .. main_y .. ";8,3;9]",
			ws.get_itemslot_bg_v4(0.375, hot_y, 8, 1),
			"list[current_player;main;0.375," .. hot_y .. ";8,1;]"
		)
	end

	return sb:get()
end

local function invviewer_show_standalone(param, ll, tab)
	tab = tab or 0
	local af = core.al_formspec
	local form_h = (tab == 0) and "12.425" or "13.5"
	local lay = inv_subtabs.layout(11.75)
	local sb = af.begin("size[11.75," .. form_h .. "]")
	sb:add(invviewer.build_content(param, ll, tab, 11.75, tonumber(form_h)))
	sb:add(af.button_exit(lay.tab_x, tonumber(form_h) - 1.4, lay.tab_w, 0.9, "close", "Close"))
	return core.show_formspec("inv_list", sb:get())
end

local function invviewer_redraw_default(param, ll, tab)
	return invviewer_show_standalone(param, ll, tab)
end

local invviewer_redraw = invviewer_redraw_default

-- Redirect where openInv re-renders itself. The inventory tab sets this to
-- re-show the tab page instead of the standalone formspec.
function invviewer.set_redraw(fn)
	invviewer_redraw = fn or invviewer_redraw_default
end

local function show_list_fs(param, ll, tab)
	tab = tab or 0
	inv_subtabs.set(tab)
	_cur_param, _cur_ll = param, ll
	if not invviewer.build_content(param, ll, tab) then
		return false, "List doesn't exist"
	end
	return invviewer_redraw(param, ll, tab)
end

core.register_chatcommand("openlist", {
	description = "Show inventory list",
	params = "[listname]",
	func = function(param)
		return show_list_fs(param)
	end,
})

core.register_cheat("OpenInvLists", { category = "Inventory", description = "View all inventory lists", func = function()
	show_list_fs()
end })

-- Handles openInv formspec input. Used by both the standalone formspec
-- ("inv_list") and the inventory tab. Returns true when it consumed the
-- fields.
function invviewer.handle_fields(fields)
	if fields.close then
		core.close_formspec("inv_list")
		return true
	end

	-- Search: handle Enter in filter fields
	if fields.key_enter_field == "inv_node_filter" then
		inv_node_filter = fields.inv_node_filter or ""
		show_list_fs(_sel_nearby_list, _sel_nearby_node, 1)
		return true
	end
	if fields.key_enter_field == "inv_item_filter" then
		inv_item_filter = fields.inv_item_filter or ""
		show_list_fs(_sel_nearby_list, _sel_nearby_node, 1)
		return true
	end

	-- Sub-tab buttons (right-side column).
	if inv_subtabs.handle(fields) ~= nil then
		show_list_fs(nil, nil, inv_subtabs.get())
		return true
	end

	if inv_subtabs.get() == 0 then
		if fields.select_list then
			show_list_fs(fields.select_list, nil, 0)
			return true
		end
		if fields.select_llist then
			show_list_fs(fields.select_list or "", fields.select_llist, 0)
			return true
		end
	else
		if fields.__inv_node_filter_search then
			inv_node_filter = fields.inv_node_filter or ""
			show_list_fs(_sel_nearby_list, _sel_nearby_node, 1)
			return true
		end
		if fields.__inv_item_filter_search then
			inv_item_filter = fields.inv_item_filter or ""
			show_list_fs(_sel_nearby_list, _sel_nearby_node, 1)
			return true
		end
		if fields.nearby_nodes then
			local event = fields.nearby_nodes
			local colon = event and event:find(":")
			local idx = colon and tonumber(event:sub(colon + 1)) or tonumber(event or "0") or 0
			local range = 6
			local pos = core.localplayer and core.localplayer:get_pos()
			local minp = vector.offset(pos, -range, -range, -range)
			local maxp = vector.offset(pos, range, range, range)
			local nodes = core.find_nodes_with_meta(minp, maxp) or {}
			if idx > 0 and idx <= #nodes then
				_sel_nearby_node = nodes[idx]
			end
		end

		if fields.nearby_list then
			_sel_nearby_list = fields.nearby_list
		end

		local range = 6
		local ppos = core.localplayer and core.localplayer:get_pos()
		local minp = vector.offset(ppos, -range, -range, -range)
		local maxp = vector.offset(ppos, range, range, range)
		local nodes = core.find_nodes_with_meta(minp, maxp) or {}

		if not _sel_nearby_node and #nodes > 0 then
			_sel_nearby_node = nodes[1]
		end

		show_list_fs(_sel_nearby_list, _sel_nearby_node, 1)
		return true
	end

	return true
end

core.register_on_formspec_input(function(formname, fields)
	if formname == "inv_list" then
		return invviewer.handle_fields(fields)
	end
end)

local punch_pos

core.register_on_punchnode(function(pos, node)
	if not core.settings:get_bool("punchinv") then return end
	punch_pos = pos
	show_list_fs(nil, pos)
end)

core.register_cheat("PunchInv", { category = "Inventory", setting = "punchinv", description = "Open inventory by punching" })

--
-- Inventory tab (openInv UI embedded as a tab)
--

if core.inv_tabs and core.inv_tabs.register_tab then
	core.inv_tabs.register_tab({
		id = "openinv",
		title = "Inventories",
		build = function(ctx)
			return invviewer.build_content(_cur_param, _cur_ll, inv_subtabs.get(),
					ctx and ctx.width or 11.75, ctx and ctx.height or 12.425) or ""
		end,
		handle = function(fields)
			return invviewer.handle_fields(fields)
		end,
		-- The openInv UI draws its own inventory lists and lays itself out
		-- against the right-side sub-tab column.
		show_inventory = false,
		pad = false,
	})
	-- Re-render inside the tab page when openInv asks to redraw, falling back
	-- to the standalone formspec when the tab isn't open.
	invviewer.set_redraw(function(param, ll, tab)
		if core.inv_tabs.is_open() then
			inv_subtabs.set(tab or inv_subtabs.get())
			_cur_param, _cur_ll = param, ll
			core.inv_tabs.set_active("openinv")
		else
			invviewer_show_standalone(param, ll, tab)
		end
	end)
end
