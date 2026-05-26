local function get_wall(a, b)
	if not a then return end
	b = b or a
	local a1 = math.floor(a / 2) * -1
	local a2 = math.ceil(a / 2) - 1
	local b1 = math.floor(b / 2) * -1
	local b2 = math.ceil(b / 2) - 1
	local rt = {}
	for y = 1, 4 do
		for i = a1, a2 do
			table.insert(rt, ws.dircoord(b2, y, i))
			table.insert(rt, ws.dircoord(b1, y, i))
		end
		for i = b1, b2 do
			table.insert(rt, ws.dircoord(i, y, a2))
			table.insert(rt, ws.dircoord(i, y, a1))
		end
	end
	return rt
end

local wallin_a = 8
local wallin_b = 8

ws.rg("WallIn", "Scaffold", "scaffold_wallin", function()
	local poss = get_wall(wallin_a, wallin_b)
	for k, v in pairs(poss) do
		minetest.place_node(v)
	end
end, function() end, function() end, {}, 0.5)

-- SkyPltfrm

local skypltfrm_nd
local skypltfrm_glassmode
local multiscaff_width = 5

ws.rg("SkyPltfrm", "Scaffold", "scaffold_skypltfrm", function()
	local n = math.floor(multiscaff_width / 2)
	if not skypltfrm_nd then skypltfrm_nd = minetest.localplayer:get_wielded_item():get_name() end
	for i = -n, n do
		local obpos = ws.dircoord(0, -2, i)
		ws.place(ws.dircoord(0, -1, i), skypltfrm_nd, 7)
		if skypltfrm_glassmode and obpos.x % 8 == 0 and obpos.z % 8 == 0 then
			ws.place(obpos, 'mcl_ocean:sea_lantern', 5)
			ws.place(ws.dircoord(0, -3, i), 'mcl_core:obsidian', 6)
		else
			ws.place(obpos, 'mcl_core:obsidian', 6)
		end
	end
end, function()
	skypltfrm_nd = minetest.localplayer:get_wielded_item():get_name()
	if skypltfrm_nd:find('glass') then skypltfrm_glassmode = true end
end, function()
	skypltfrm_nd = nil
end)

-- PCeiling

local multiscaff_node

local function get_nodes_over_air(pos, range, nodes)
	local nds = minetest.find_nodes_near(pos, range, nodes)
	local rt = {}
	for k, v in ipairs(nds) do
		local under = vector.add(v, vector.new(0, -1, 0))
		local un = minetest.get_node_or_nil(under)
		if un and un.name == "air" then table.insert(rt, v) end
	end
	return rt
end

ws.rg("PCeiling", "Scaffold", "pceiling", function()
	if not multiscaff_node then return end
	local lp = ws.dircoord(0, 0, 0)
	local nds = get_nodes_over_air(lp, 4, nlist.get(nlist.selected))
	for k, v in pairs(nds) do
		local pos = ws.dircoord(0, -1, 0, v)
		ws.place(pos, multiscaff_node)
	end
end, function()
	multiscaff_node = minetest.localplayer:get_wielded_item():get_name()
	ws.dcm("Ceilingscaff started. Selected node: " .. multiscaff_node)
end)
