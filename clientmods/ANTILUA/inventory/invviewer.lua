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

local _sel_nearby_node
local _sel_nearby_list
local inv_node_filter = ""
local inv_item_filter = ""

local function show_list_fs(param, ll, tab)
	tab = tab or 0
	local name = core.localplayer:get_name()
	local inv = core.get_inventory("player:" .. name)
	local af = core.al_formspec

	local form_h = (tab == 0) and "12.425" or "13.5"
	local sb = af.begin("size[11.75," .. form_h .. "]")
	sb:add(
		af.tabheader(0, 0, "inv_tabs", {"Inventories", "Nearby"}, tab + 1),
		af.button_exit(10.5, tab == 0 and 11.5 or 12.5, 1, 0.8, "close", "Close")
	)

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
			return false, "List doesn't exist"
		end

		local x, y = 0, 1
		for _ in pairs(inv[param]) do
			if x < 9 then x = x + 1 elseif y < 3 then y = y + 1 end
		end

		sb:add(
			af.label(0.375, 0.375, "Show Inv List"),
			af.dropdown(8, 0.175, 3, "select_list", dlist_tb, idx),
			ws.get_itemslot_bg_v4(0.375, 1.75, x, y),
			"list[current_player;" .. param .. ";0.375,1.75;" .. x .. "," .. y .. ";]",
			af.label(0.375, 6.7, "Inventory"),
			ws.get_itemslot_bg_v4(0.375, 7.1, 9, 3),
			"list[current_player;main;0.375,7.1;9,3;9]",
			ws.get_itemslot_bg_v4(0.375, 11.05, 9, 1),
			"list[current_player;main;0.375,11.05;9,1;]",
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
			af.searchbar(0.375, 0.7, 10.5, "inv_node_filter", { default = inv_node_filter, button_width = 1.2 })
		)

		if #node_entries == 0 then
			sb:add(af.label(0.375, 1.5, inv_node_filter ~= "" and "No matching nodes" or "No inventory nodes nearby"))
		else
			sb:add(af.textlist(0.375, 1.4, 5.5, 6.6, "nearby_nodes", node_entries, sel_idx))

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
					sb:add(
						af.label(6.375, 0.375, node_name),
						af.label(6.375, 0.75, spos),
						af.dropdown(6.375, 1.4, 3, "nearby_list", list_keys, list_idx),
						af.searchbar(6.375, 2.0, 5, "inv_item_filter", { default = inv_item_filter, button_width = 1.2 })
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
						sb:add(af.textlist(6.375, 2.8, 5, 3.2, "nearby_items", lines, 0))
					end
				end
			end
		end

		sb:add(
			af.label(0.375, 8.5, "Your Inventory"),
			ws.get_itemslot_bg_v4(0.375, 9, 9, 3),
			"list[current_player;main;0.375,9;9,3;9]",
			ws.get_itemslot_bg_v4(0.375, 12.05, 9, 1),
			"list[current_player;main;0.375,12.05;9,1;]"
		)
	end

	core.show_formspec("inv_list", sb:get())
	return true
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

core.register_on_formspec_input(function(formname, fields)
	if formname == "inv_list" then
		if fields.close then
			core.close_formspec("inv_list")
			return
		end

		-- Search: handle Enter in filter fields
		if fields.key_enter_field == "inv_node_filter" then
			inv_node_filter = fields.inv_node_filter or ""
			show_list_fs(_sel_nearby_list, _sel_nearby_node, 1)
			return
		end
		if fields.key_enter_field == "inv_item_filter" then
			inv_item_filter = fields.inv_item_filter or ""
			show_list_fs(_sel_nearby_list, _sel_nearby_node, 1)
			return
		end

		local tab = 0
		if fields.inv_tabs then
			tab = tonumber(fields.inv_tabs) - 1
		end

		if tab == 0 then
			if fields.select_list then
				show_list_fs(fields.select_list, nil, 0)
				return
			end
			if fields.select_llist then
				show_list_fs(fields.select_list or "", fields.select_llist, 0)
				return
			end
		else
			if fields.__inv_node_filter_search then
				inv_node_filter = fields.inv_node_filter or ""
				show_list_fs(_sel_nearby_list, _sel_nearby_node, 1)
				return
			end
			if fields.__inv_item_filter_search then
				inv_item_filter = fields.inv_item_filter or ""
				show_list_fs(_sel_nearby_list, _sel_nearby_node, 1)
				return
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
			return
		end

		if fields.inv_tabs then
			show_list_fs(nil, nil, tab)
		end
	end
end)

local punch_pos

core.register_on_punchnode(function(pos, node)
	if not core.settings:get_bool("punchinv") then return end
	punch_pos = pos
	show_list_fs(nil, pos)
end)

core.register_cheat("PunchInv", { category = "Inventory", setting = "punchinv", description = "Open inventory by punching" })
