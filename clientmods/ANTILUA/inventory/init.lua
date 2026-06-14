--
-- AutoRefill & AutoEject (from invutil)
--

ws.rg("AutoRefill", {
	category = "Inventory",
	setting = "autorefill",
	description = "Auto-refill hotbar from inventory",
	delay = 0.1,
	on_step = function()
		local player = core.localplayer
		if not player then return end
		local item = player:get_wielded_item()
		local itemname = item:get_name()
		if itemname == "" then return end
		local space = item:get_free_space()
		if space <= 0 then return end
		local wieldindex = player:get_wield_index()
		local i = core.find_item(itemname, wieldindex + 1)
		if i then
			ws.move_stack("current_player", "main", i, "current_player", "main", wieldindex, space)
		end
	end,
})

ws.rg("AutoEject", {
	category = "Inventory",
	setting = "autoeject",
	description = "Auto-eject items from inventory",
	on_step = function()
		local invact = InventoryAction("drop")
		local list = (core.settings:get("eject_items") or ""):split(",")
		local inventory = core.get_inventory("current_player")
		if not inventory or not inventory.main then return end
		for index, stack in pairs(inventory.main) do
			if table.indexof(list, stack:get_name()) ~= -1 then
				invact:from("current_player", "main", index)
				invact:apply()
			end
		end
	end,
})

core.register_chatcommand("eject", {
	params = "<item_string>",
	description = "Configure AutoEject items (comma-separated)",
	func = function(param)
		core.settings:set("eject_items", param)
		return true, "Eject items set to: " .. param
	end,
})

--
-- DumpFull (from invutil)
--

core.register_cheat("DumpFull", { category = "Inventory", description = "Dump entire inventory to the ground", func = function()
	local pt = core.get_pointed_thing().under
	local inv = core.get_inventory("nodemeta:"..pt.x..","..pt.y..","..pt.z)
	local plinv = core.get_inventory("current_player")
	for i, v in pairs(plinv.main) do
		ws.move_stack("current_player", "main", i, "nodemeta:"..pt.x..","..pt.y..","..pt.z, "main", i)
	end
end})
--
-- Crafting GUI (from inv_open)
--

local craft_fs = table.concat({
	"formspec_version[4]",
	"size[11.75,10.425]",
	"label[2.25,0.375;Crafting]",
	ws.get_itemslot_bg_v4(2.25, 0.75, 3, 3),
	"list[current_player;craft;2.25,0.75;3,3;]",
	"image[6.125,2;1.5,1;gui_crafting_arrow.png]",
	ws.get_itemslot_bg_v4(8.2, 2, 1, 1, 0.2),
	"list[current_player;craftpreview;8.2,2;1,1;]",
	"label[0.375,4.7;Inventory]",
	ws.get_itemslot_bg_v4(0.375, 5.1, 9, 3),
	"list[current_player;main;0.375,5.1;9,3;9]",
	ws.get_itemslot_bg_v4(0.375, 9.05, 9, 1),
	"list[current_player;main;0.375,9.05;9,1;]",
	"listring[current_player;craft]",
	"listring[current_player;main]",
	"image_button[0.325,1.95;1.1,1.1;craftguide_book.png;__mcl_craftguide;]",
	"tooltip[__mcl_craftguide;Recipe book]",
})

core.register_chatcommand("craft", {
	description = "Open a crafting grid",
	func = function()
		core.show_formspec("inv_craft", craft_fs)
	end,
})

core.register_cheat("OpenCraftGrid", { category = "Inventory", description = "Open the crafting grid", func = function()
	core.show_formspec("inv_craft", craft_fs)
end })

--
-- Inventory list viewer (from inv_open)
--

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

-- Persistent state for the Nearby tab
local _sel_nearby_node  -- v3s16 of selected node, or nil
local _sel_nearby_list  -- string name of selected list

local function show_list_fs(param, ll, tab)
	tab = tab or 0
	local name = core.localplayer:get_name()
	local inv = core.get_inventory("player:" .. name)
	local theme_bg = core.settings:get("theme_bg") or "#121212"

	local form_h = (tab == 0) and "12.425" or "13.5"
	local fs = "formspec_version[10]size[11.75," .. form_h .. "]no_prepend[]bgcolor[" .. theme_bg .. ";true]" ..
		"tabheader[0,0;inv_tabs;Inventories,Nearby;" .. (tab + 1) .. "]" ..
		"button[10.5," .. (tab == 0 and "11.5" or "12.5") .. ";1,0.8;close;Close]"

	if tab == 0 then
		-- Tab 0: Player inventories (existing)
		local dlists = ""
		local i, idx = 1, 1

		for k in pairs(inv) do
			if not param or param == "" then
				param = k
			end
			dlists = dlists .. k .. ","
			if k == param then idx = i end
			i = i + 1
		end
		dlists = dlists:sub(1, -2)

		if not inv[param] then
			return false, "List doesn't exist"
		end

		local x, y = 0, 1
		for _ in pairs(inv[param]) do
			if x < 9 then x = x + 1 elseif y < 3 then y = y + 1 end
		end

		fs = fs ..
			"label[0.375,0.375;Show Inv List]" ..
			"dropdown[8,0.175;3,1;select_list;" .. dlists .. ";" .. idx .. "]" ..
			ws.get_itemslot_bg_v4(0.375, 1.75, x, y) ..
			"list[current_player;" .. param .. ";0.375,1.75;" .. x .. "," .. y .. ";]" ..
			"label[0.375,6.7;Inventory]" ..
			ws.get_itemslot_bg_v4(0.375, 7.1, 9, 3) ..
			"list[current_player;main;0.375,7.1;9,3;9]" ..
			ws.get_itemslot_bg_v4(0.375, 11.05, 9, 1) ..
			"list[current_player;main;0.375,11.05;9,1;]" ..
			"listring[current_player;" .. param .. "]" ..
			"listring[current_player;main]"
	else
		-- Tab 1: Nearby node inventories
		local pos = core.localplayer and core.localplayer:get_pos()
		local range = 6
		local minp = vector.offset(pos, -range, -range, -range)
		local maxp = vector.offset(pos, range, range, range)
		local nodes = core.find_nodes_with_meta(minp, maxp) or {}
		local selected_node = ll

		-- Build node list
		local node_entries = {}
		local sel_idx = 1
		for id, p in ipairs(nodes) do
			local n = core.get_node_or_nil(p)
			if n then
				local label = n.name .. " (" .. p.x .. "," .. p.y .. "," .. p.z .. ")"
				table.insert(node_entries, core.formspec_escape(label))
				if selected_node and vector.equals(p, selected_node) then
					sel_idx = id
					selected_node = p
				end
			end
		end
		-- Default to first node if none selected
		if not selected_node and #nodes > 0 then
			selected_node = nodes[1]
		end

		fs = fs .. "label[0.375,0.375;Nearby inventory nodes]"

		if #node_entries == 0 then
			fs = fs .. "label[0.375,1.5;No inventory nodes nearby]"
		else
			fs = fs .. "textlist[0.375,1;5.5,7.5;nearby_nodes;" ..
				table.concat(node_entries, ",") .. ";" .. sel_idx .. "]"

			-- Inventory lists for selected node
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
					fs = fs ..
						"label[6.375,0.375;" .. core.formspec_escape(node_name) .. "]" ..
						"label[6.375,0.75;" .. spos .. "]" ..
						"dropdown[6.375,1.5;3,1;nearby_list;" ..
							table.concat(list_keys, ",") .. ";" .. list_idx .. "]"

					-- Show items as text
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
								table.insert(lines, string.format("[%d] %s x%d", si, stack:get_name(), stack:get_count()))
							else
								table.insert(lines, string.format("[%d] (empty)", si))
							end
						end
						if slots > 54 then
							table.insert(lines, "... and " .. (slots - 54) .. " more")
						end
						local text = table.concat(lines, ",")
						fs = fs .. "textlist[6.375,2.5;5,4;nearby_items;" .. core.formspec_escape(text) .. ";0]"
					end
				end
			end
		end

		-- Player inventory at the bottom
		fs = fs ..
			"label[0.375,8.5;Your Inventory]" ..
			ws.get_itemslot_bg_v4(0.375, 9, 9, 3) ..
			"list[current_player;main;0.375,9;9,3;9]" ..
			ws.get_itemslot_bg_v4(0.375, 12.05, 9, 1) ..
			"list[current_player;main;0.375,12.05;9,1;]"
	end

	core.show_formspec("inv_list", fs)
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
			-- Tab 1: update persistent selections from form fields
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

			-- Build nearby nodes list to find index of current selection
			local range = 6
			local ppos = core.localplayer and core.localplayer:get_pos()
			local minp = vector.offset(ppos, -range, -range, -range)
			local maxp = vector.offset(ppos, range, range, range)
			local nodes = core.find_nodes_with_meta(minp, maxp) or {}

			-- If no node selected yet, pick the first one
			if not _sel_nearby_node and #nodes > 0 then
				_sel_nearby_node = nodes[1]
			end

			show_list_fs(_sel_nearby_list, _sel_nearby_node, 1)
			return
		end

		-- Tab switch without other field changes
		if fields.inv_tabs then
			show_list_fs(nil, nil, tab)
		end
	end
end)

--
-- Punch-to-open inventory (from inv_open)
--

local punch_pos

core.register_on_punchnode(function(pos, node)
	if not core.settings:get_bool("punchinv") then return end
	punch_pos = pos
	show_list_fs(nil, pos)
end)

core.register_cheat("PunchInv", { category = "Inventory", setting = "punchinv", description = "Open inventory by punching" })

--
-- Chest Stealer (from chest_stealer)
--

local function pos_to_str(pos)
	return pos.x .. "," .. pos.y .. "," .. pos.z
end

local function steal_from(pos_str)
	local inv = core.get_inventory("nodemeta:" .. pos_str)
	local plinv = core.get_inventory("current_player")
	if not inv or not plinv then
		return
	end
	for listname, stacks in pairs(inv) do
		for idx, stack in ipairs(stacks) do
			if not stack:is_empty() then
				for slot = 1, 32 do
					local plstack = plinv.main[slot]
					if plstack:is_empty() then
						ws.move_stack("nodemeta:" .. pos_str, listname, idx, "current_player", "main", slot, stack:get_count())
						break
					end
				end
			end
		end
	end
end

core.register_on_open_nodemeta_form(function(pos, formspec)
	if not core.settings:get_bool("chest_stealer") then
		return false
	end
	if not pos or not pos.x then
		return false
	end
	steal_from(pos_to_str(pos))
	return false
end)

core.register_cheat("ChestStealer", {
	category = "Inventory",
	setting = "chest_stealer",
	description = "Auto-steal all items when opening a container",
})

--
-- mcl_chests input slot injector
--

core.register_on_receiving_formspec(function(formname, formspec)
	local x, y, z = formname:match("^mcl_chests:chest_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
	if not x then
		return nil
	end
	local loc = "nodemeta:" .. x .. "," .. y .. "," .. z

	local px, py = 0.3, 5
	local inject = ws.get_itemslot_bg_v4(px, py, 1, 1) ..
	"list[" .. loc .. ";input;"..px..","..py..";1,1;]"..
	"label["..px..","..py..";Input]"
	local modified = formspec..inject --formspec:gsub('(list%["' .. loc .. '";main;%d+,%d+;%d+,%d+;%d*%])', "%1" .. inject, 1)
	if modified ~= formspec then
		return modified
	end
	return nil
end)

--
-- Auto-Torch
--

local torch_items = { "default:torch", "mcl_torches:torch" }
local torch_threshold = 7

if nlist and nlist.get then
	local custom = nlist.get("auto_torch_items")
	if #custom > 0 then
		torch_items = custom
	end
end

local torch_etime = 0

core.register_globalstep(function(dtime)
	if not core.settings:get_bool("auto_torch") then
		return
	end
	local player = core.localplayer
	if not player then return end
	if not player:is_touching_ground() then return end

	torch_etime = torch_etime + dtime
	if torch_etime < 0.5 then return end
	torch_etime = 0

	local pos = player:get_pos()
	if not pos then return end

	local light = core.get_node_light(vector.offset(pos, 0, 1, 0))
	if not light or light >= torch_threshold then return end

	for _, item in ipairs(torch_items) do
		local idx = core.find_item(item)
		if idx then
			core.switch_to_item(item)
			local below = { x = pos.x, y = math.floor(pos.y) - 1, z = pos.z }
			ws.place(below)
			return
		end
	end
end)

core.register_cheat("AutoTorch", {
	category = "Place",
	setting = "auto_torch",
	description = "Auto-place light source in dark areas",
})

--
-- Auto-Sort
--

core.register_cheat("AutoSort", { category = "Inventory", setting = "auto_sort", description = "Auto-sort inventory", func = function()
	local inv = core.get_inventory("current_player")
	if not inv or not inv.main then return end

	local items = {}
	for i, stack in ipairs(inv.main) do
		if not stack:is_empty() then
			table.insert(items, { slot = i, stack = stack })
		end
	end

	table.sort(items, function(a, b)
		if a.stack:get_name() == b.stack:get_name() then
			return a.slot < b.slot
		end
		return a.stack:get_name() < b.stack:get_name()
	end)

	for target_slot, entry in ipairs(items) do
		if entry.slot ~= target_slot then
			ws.move_stack("current_player", "main", entry.slot,
				"current_player", "main", target_slot, entry.stack:get_count())
		end
	end
end })
