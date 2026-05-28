local function get_slot(x, y, size, texture)
	local t = "image[" .. x - size .. "," .. y - size .. ";" .. 1 + (size * 2) ..
		"," .. 1 + (size * 2) .. ";" .. (texture and texture or "mcl_formspec_itemslot.png") .. "]"
	return t
end

local function get_itemslot_bg_v4(x, y, w, h, size, texture)
	if not size then
		size = 0.05
	end
	local out = ""
	for i = 0, w - 1, 1 do
		for j = 0, h - 1, 1 do
			out = out .. get_slot(x + i + (i * 0.25), y + j + (j * 0.25), size, texture)
		end
	end
	return out
end

local sel_pos

local function show_formspec(p, list)
	p = p or sel_pos
	if not p then return end
	--local name = minetest.localplayer:get_name()
	local inv = minetest.get_inventory("nodemeta:"..p.x..","..p.y..","..p.z)
	if not inv then return end
	local dlists = ""
	local i = 1
	local idx = 1
	for k, _ in pairs(inv) do
		if not list or list == "" then
			list = k
		end
		dlists = dlists .. k .. ","
		if k == list then idx = i end
		i = i + 1
	end
	dlists = dlists:sub(1, -2)
	if inv[list] then
		local x = 0
		local y = 1
		for _, _ in pairs(inv[list]) do
			if x < 9 then
				x = x + 1
			elseif y < 3 then
				y = y + 1
			end
		end
		local fs = table.concat({
			"formspec_version[4]",
			"size[11.75,12.425]",

			"label[0.375,0.375;Show Inv List]",

			"dropdown[8,0.175;3,1;select_list;"..dlists..";"..idx.."]",

			get_itemslot_bg_v4(0.375, 1.75, x, y),
			"list[nodemeta:"..p.x..","..p.y..","..p.z..";"..list..";0.375,1.75;"..x..","..y..";]",

			"label[0.375,6.7;Inventory]",

			get_itemslot_bg_v4(0.375, 7.1, 9, 3),
			"list[current_player;main;0.375,7.1;9,3;9]",

			get_itemslot_bg_v4(0.375, 11.05, 9, 1),
			"list[current_player;main;0.375,11.05;9,1;]",

			"listring[nodemeta:"..p.x..","..p.y..","..p.z..";"..list.."]",
			"listring[current_player;main]",
		})
		minetest.show_formspec("invutil_punchinv", fs)
		return true
	else
		return false, "List doesn't exists"
	end
end

-- Register cheat menu entry in dragonfire
if minetest.register_cheat then
	core.register_cheat("PunchInv", { category = "Inventory", setting = "punchinv" })
end
minetest.register_on_punchnode(function(pos, node)
	if not core.settings:get_bool("punchinv", false) then return end
	sel_pos = pos
	show_formspec(pos)
end)

minetest.register_on_formspec_input(function(formname, fields)
	if formname ~= 'invutil_punchinv' then return end
	if fields.select_list then
		show_formspec(sel_pos, fields.select_list)
	end
end)
