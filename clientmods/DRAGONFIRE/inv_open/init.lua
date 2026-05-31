-- inv_open: inventory/craft GUI (merged from open_inv + enderchest + punchinv)

-- Crafting GUI (from enderchest + open_inv)
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

-- Inventory list viewer (from open_inv)
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
	local name = minetest.localplayer:get_name()
	local inv = minetest.get_inventory("player:" .. name)
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
	minetest.show_formspec("inv_open_list", fs)
	return true
end

-- Punch-to-open (from punchinv)
local punch_pos

minetest.register_on_punchnode(function(pos, node)
	if not core.settings:get_bool("punchinv") then return end
	punch_pos = pos
	show_list_fs(nil, pos)
end)

-- Chat commands
minetest.register_chatcommand("craft", {
	description = "Open a crafting grid",
	func = function()
		minetest.show_formspec("inv_open", craft_fs)
	end,
})

minetest.register_chatcommand("openlist", {
	description = "Show inventory list",
	params = "[listname]",
	func = function(param)
		return show_list_fs(param)
	end,
})

-- Formspec handlers
core.register_on_formspec_input(function(formname, fields)
	if formname == "inv_open_list" then
		if fields.select_list then
			show_list_fs(fields.select_list)
		end
		if fields.select_llist then
			show_list_fs(fields.select_list or "", fields.select_llist)
		end
	end
end)

-- Cheat menu entries
core.register_cheat("OpenInvLists", { category = "Inventory", func = function() show_list_fs() end })
core.register_cheat("OpenCraftGrid", { category = "Inventory", func = function()
	minetest.show_formspec("inv_open", craft_fs)
end })
core.register_cheat("PunchInv", { category = "Inventory", setting = "punchinv" })
