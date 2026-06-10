-- Inventory: merged from invutil, inv_open, chest_stealer

--
-- AutoRefill & AutoEject (from invutil)
--

local etime = 0

core.register_globalstep(function(dtime)
	local player = core.localplayer
	if not player then return end
	local item = player:get_wielded_item()
	local itemname = item:get_name()
	local itemdef = core.get_item_def(itemname)
	local wieldindex = player:get_wield_index()
	etime = etime + dtime
	if core.settings:get_bool("autorefill") and itemname ~= "" and itemdef and etime > 0.1 then
		etime = 0
		local space = item:get_free_space()
		local i = core.find_item(item:get_name(), wieldindex + 1)
		if i and space > 0 then
			ws.move_stack("current_player", "main", i, "current_player", "main", wieldindex, space)
		end
	end
	if core.settings:get_bool("autoeject") then
		local invact = InventoryAction("drop")
		local list = (core.settings:get("eject_items") or ""):split(",")
		local inventory = core.get_inventory("current_player")
		for index, stack in pairs(inventory.main) do
			if table.indexof(list, stack:get_name()) ~= -1 then
				invact:from("current_player", "main", index)
				invact:apply()
			end
		end
	end
end)

core.register_chatcommand("eject", {
	params = "<item_string>",
	description = "Configure AutoEject items (comma-separated)",
	func = function(param)
		core.settings:set("eject_items", param)
		return true, "Eject items set to: " .. param
	end,
})

core.register_cheat("AutoRefill", { category = "Inventory", setting = "autorefill" })
core.register_cheat("AutoEject", { category = "Inventory", setting = "autoeject" })

--
-- DumpFull (from invutil)
--

core.register_cheat("DumpFull", { category = "Inventory", func = function()
	local pt = core.get_pointed_thing().under
	local inv = core.get_inventory("nodemeta:"..pt.x..","..pt.y..","..pt.z)
	local plinv = core.get_inventory("current_player")
	for i, v in pairs(plinv.main) do
		ws.move_stack("current_player", "main", i, "nodemeta:"..pt.x..","..pt.y..","..pt.z, "main", i)
	end
end})

--
-- AutoBlock (from invutil)
--

local blockable = { "default:diamond" }
local blocks = { "default:diamondblock" }

ws.rg("AutoBlock", "Inventory", "autoblock", function()
	local inv = core.get_inventory("current_player")
	local item
	local count = 0
	local items = {}

	for idx, it in pairs(inv.main) do
		for _, b in pairs(blockable) do
			if ((item and item == it:get_name()) or it:get_name() == b) and it:get_count() == it:get_stack_max() then
				items[idx] = it
				item = b
				count = count + 1
			end
		end
	end
	if item and count >= 9 then
		local cidx = 1
		for idx, it in pairs(items) do
			ws.move_stack("current_player", "main", idx, "current_player", "craft", cidx, it:get_count())
			cidx = cidx + 1
		end
	end

	local empty = ws.find_empty(inv.main)
	if empty and inv.craftpreview[1]:get_name() == blocks[1] then
		for _ = 1, inv.craft[1]:get_count() do
			ws.move_stack("current_player", "craftpreview", 1, "current_player", "main", empty)
		end
	end
end)

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

core.register_cheat("OpenCraftGrid", { category = "Inventory", func = function()
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

local function show_list_fs(param, ll)
	local name = core.localplayer:get_name()
	local inv = core.get_inventory("player:" .. name)
	local dlists = ""
	local llists = ""
	local i, j, idx, idxl = 1, 1, 1, 1

	for k in pairs(inv) do
		if not param or param == "" then
			param = k
		end
		dlists = dlists .. k .. ","
		if k == param then idx = i end
		i = i + 1
	end
	dlists = dlists:sub(1, -2)

	for _, v in pairs(get_node_invs(core.localplayer:get_pos())) do
		local n = core.get_node_or_nil(v.pos)
		if n then
			if vector.equals(v.pos, ll) then idxl = j end
			llists = llists .. n.name .. ","
			j = j + 1
		end
	end
	llists = llists:sub(1, -2)

	if not inv[param] then
		return false, "List doesn't exist"
	end

	local x, y = 0, 1
	for _ in pairs(inv[param]) do
		if x < 9 then x = x + 1 elseif y < 3 then y = y + 1 end
	end

	local fs = table.concat({
		"formspec_version[4]",
		"size[11.75,12.425]",
		"label[0.375,0.375;Show Inv List]",
		"dropdown[8,0.175;3,1;select_list;" .. dlists .. ";" .. idx .. "]",
		"dropdown[8,2.175;3,1;select_llist;" .. llists .. ";" .. idxl .. "]",
		ws.get_itemslot_bg_v4(0.375, 1.75, x, y),
		"list[current_player;" .. param .. ";0.375,1.75;" .. x .. "," .. y .. ";]",
		"label[0.375,6.7;Inventory]",
		ws.get_itemslot_bg_v4(0.375, 7.1, 9, 3),
		"list[current_player;main;0.375,7.1;9,3;9]",
		ws.get_itemslot_bg_v4(0.375, 11.05, 9, 1),
		"list[current_player;main;0.375,11.05;9,1;]",
		"listring[current_player;" .. param .. "]",
		"listring[current_player;main]",
	})
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

core.register_cheat("OpenInvLists", { category = "Inventory", func = function()
	show_list_fs()
end })

core.register_on_formspec_input(function(formname, fields)
	if formname == "inv_list" then
		if fields.select_list then
			show_list_fs(fields.select_list)
		end
		if fields.select_llist then
			show_list_fs(fields.select_list or "", fields.select_llist)
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

core.register_cheat("PunchInv", { category = "Inventory", setting = "punchinv" })

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

core.register_cheat("AutoSort", { category = "Inventory", func = function()
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
end, setting = "auto_sort" })
