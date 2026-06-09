local function tablearg(arg)
	local tb = {}
	if type(arg) == 'string' then
		tb = {arg}
	elseif type(arg) == 'table' then
		tb = arg
	elseif type(arg) == 'function' then
		tb = arg()
	end
	return tb
end

function ws.buildable_to(pos)
	local node = core.get_node_or_nil(pos)
	if node then
		return core.get_node_def(node.name).buildable_to
	end
end

function ws.tplace(p, n, stay)
	if not p then return end
	if n then ws.switch_to_item(n) end
	local opos = ws.dircoord(0, 0, 0)
	local tpos = vector.add(p, vector.new(0, 1, 0))
	core.localplayer:set_pos(tpos)
	ws.place(p, {n})
	if not stay then
		core.after(0.1, function()
			core.localplayer:set_pos(opos)
		end)
	end
end

core.register_chatcommand("tplace", {
	description = "tp-place",
	param = "Y",
	func = function(param)
		return ws.tplace(core.string_to_pos(param))
	end
})

function ws.ytp(param)
	local y = tonumber(param)
	local lp = ws.dircoord(0, 0, 0)
	if lp.y < y + 50 then return false, "Can't TP up." end
	if y < -30912 then return false, "Don't TP into the void lol." end
	core.localplayer:set_pos(vector.new(lp.x, y, lp.z))
end

function ws.isnode(pos, arg)
	local nodename = tablearg(arg)
	local nd = core.get_node_or_nil(pos)
	if nd and nodename and ws.in_list(nd.name, nodename) then
		return true
	end
end

function ws.can_place_at(pos)
	local node = core.get_node_or_nil(pos)
	return (node and (node.name == "air"
		or node.name == "mcl_core:water_source"
		or node.name == "mcl_core:water_flowing"
		or node.name == "mcl_core:lava_source"
		or node.name == "mcl_core:lava_flowing"
		or (core.get_node_def(node.name) or {}).buildable_to))
end

function ws.can_place_wielded_at(pos)
	local wield_empty = core.localplayer:get_wielded_item():is_empty()
	return not wield_empty and ws.can_place_at(pos)
end

function ws.find_any_swap(items, hslot)
	hslot = hslot or 8
	for i, v in ipairs(items) do
		local n = core.find_item(v)
		if n then
			ws.switch_to_item(v, hslot)
			return true
		end
	end
	return false
end

function ws.place(pos, items, hslot, place)
	if not pos then return end
	if not ws.can_place_at(pos) then return end
	items = tablearg(items)
	place = place or core.place_node

	local node = core.get_node_or_nil(pos)
	if not node then return end
	if ws.isnode(pos, items) then
		return true
	else
		if ws.find_any_swap(items, hslot) then
			place(pos)
			return true
		end
	end
end

function ws.place_if_able(pos)
	if not pos then return end
	if ws.can_place_wielded_at(pos) then
		core.place_node(pos)
	end
end

function ws.is_diggable(pos)
	if not pos then return false end
	local nd = core.get_node_or_nil(pos)
	if not nd or not nd.name then return false end
	local n = core.get_node_def(nd.name)
	if n and n.diggable then return true end
	return false
end

function ws.dig(pos, condition, autotool)
	if autotool == nil then autotool = true end
	if condition and not condition(pos) then return false end
	if not ws.is_diggable(pos) then return end
	local nd = core.get_node_or_nil(pos)
	if nd and core.get_node_def(nd.name).diggable then
		if autotool then ws.select_best_tool(pos) end
		local wear = core.localplayer:get_wielded_item():get_wear()
		if wear > 60000 then return false end
		core.dig_node(pos)
	end
	return true
end

function ws.chunk_loaded()
	local ign = core.find_nodes_near(ws.dircoord(0, 0, 0), 10, {'ignore'}, true)
	if #ign == 0 then return true end
	return false
end

function ws.get_near(nodes, range)
	range = range or 5
	local nds = core.find_nodes_near(ws.dircoord(0, 0, 0), range, nodes, true)
	if #nds > 0 then return nds end
	return false
end

function ws.is_laggy()
	if tps_client and tps_client.ping and tps_client.ping > 1000 then return true end
end

function ws.donodes(poss, func, condition)
	if ws.is_laggy() then return end
	local dn_i = 0
	table.shuffle(poss)
	for k, v in ipairs(poss) do
		if dn_i > 32 then return end
		if condition == nil or condition(v) then
			if func(v) == false then return false end
			dn_i = dn_i + 1
		end
	end
	return true
end

function ws.allow_dig(pos)
	return true
end

function ws.dignodes(poss, condition)
	return ws.donodes(poss, ws.dig, function(pos)
		if not ws.allow_dig(pos) then
			return false
		end
		if condition and condition(v) == false then return false end
		local n = core.get_node_or_nil(pos)
		return n and n.name ~= "air" or false
	end)
end

function ws.replace(pos, arg)
	arg = tablearg(arg)
	local nd = core.get_node_or_nil(pos)
	if nd and not ws.in_list(nd.name, arg) and ws.buildable_to(pos) then
		local tm = ws.get_digtime(nd.name) or 0
		ws.dig(pos)
		core.after(tm + 0.1, function()
			ws.place(pos, arg)
		end)
		return tm
	else
		return ws.place(pos, arg)
	end
end

local wall_pos1 = {x = -1255, y = 6, z = 792}
local wall_pos2 = {x = -1452, y = 80, z = 981}
local iwall_pos1 = {x = -1266, y = 6, z = 802}
local iwall_pos2 = {x = -1442, y = 80, z = 971}

function ws.in_cube(tpos, wpos1, wpos2)
	local xmax = wpos2.x
	local xmin = wpos1.x
	local ymax = wpos2.y
	local ymin = wpos1.y
	local zmax = wpos2.z
	local zmin = wpos1.z
	if wpos1.x > wpos2.x then
		xmax = wpos1.x
		xmin = wpos2.x
	end
	if wpos1.y > wpos2.y then
		ymax = wpos1.y
		ymin = wpos2.y
	end
	if wpos1.z > wpos2.z then
		zmax = wpos1.z
		zmin = wpos2.z
	end
	if ws.between(tpos.x, xmin, xmax) and ws.between(tpos.y, ymin, ymax) and ws.between(tpos.z, zmin, zmax) then
		return true
	end
	return false
end

function ws.in_wall(pos)
	if ws.in_cube(pos, wall_pos1, wall_pos2) and not ws.in_cube(pos, iwall_pos1, iwall_pos2) then
		return true
	end
	return false
end

function ws.inside_wall(pos)
	if ws.in_cube(pos, iwall_pos1, iwall_pos2) then return true end
	return false
end

function ws.find_closest_reachable_airpocket(pos)
	local lp = ws.dircoord(0, 0, 0)
	local nds = core.find_nodes_near(lp, 5, {'air'})
	local odst = 10
	local rt = lp
	for k, v in ipairs(nds) do
		local dst = vector.distance(pos, v)
		if dst < odst then odst = dst rt = v end
	end
	if odst == 10 then return false end
	return vector.add(rt, vector.new(0, -1.5, 0))
end

function ws.find_closest_pos(poss)
	if not poss or not poss[1] then return end
	local lp = ws.dircoord(0, 0, 0)
	local odst = 100000
	local rt = poss[1]
	for k, v in pairs(poss) do
		local dst = vector.distance(lp, v)
		if dst < odst then
			rt = v
			odst = dst
		end
	end
	return rt
end

-- MakeBlocks: auto-craft blocks from wielded item (extracted from emicor)
function ws.make_blocks()
	local slot = 9
	local it = core.get_wielded_item()
	local wi = core.get_wield_index()
	local nn = it:get_count() / 9
	for i = 1, 9 do
		ws.move_stack("current_player", "main", wi, "current_player", "craft", i, nn)
	end

	local craft_act = InventoryAction("craft")
	craft_act:craft("current_player")
	craft_act:apply()

	local tslot = ws.find_empty(core.get_inventory("current_player").main)
	if not tslot then tslot = 9 end
	ws.move_stack("current_player", "craft_result", 1, "current_player", "main", tslot)
end

core.register_cheat("MakeBlocks", { category = "Inventory", func = ws.make_blocks })

-- Inventory dump via quint (extracted from emicor)
function ws.invdump(src, dst)
	local lp = ws.dircoord(0, 0, 0)
	if type(src) ~= 'table' then
		src = {location = ws.invparse(src), inventory = "main"}
	end
	if type(dst) ~= 'table' then
		dst = {location = ws.invparse(dst), inventory = "main"}
	end

	local srcbounds = {min = 0, max = 0}
	if src.location == "current_player" then
		srcbounds.min = 10
	end

	local q = quint.invaction_new()
	local rt = quint.invaction_dump(q, src, dst, srcbounds)
	quint.invaction_apply(q)
	return rt
end

function ws.dumpto()
	local ptd = core.get_pointed_thing()
	if ptd then
		ws.invdump("current_player", ws.invparse(ptd.under))
	end
end

function ws.loot()
	local ptd = core.get_pointed_thing()
	if ptd then
		ws.invdump(ws.invparse(ptd.under), "current_player")
	end
end

core.register_cheat('Loot', { category = 'Inventory', func = ws.dumpto })
core.register_chatcommand("dumpto", {
	description = "Dump main inv (not hotbar) to pointed storage block.",
	func = ws.dumpto
})
core.register_chatcommand("loot", {
	description = "Take as many items from pointed block as possible.",
	func = ws.loot
})

-- IceBreaker: dig ice in range (extracted from emicor)
function ws.icebreaker()
	local owx = core.localplayer:get_wield_index()
	local nds = core.find_nodes_near(ws.dircoord(0, 0, 0), 4, {'mcl_core:ice'}, true)
	ws.dignodes(nds)
	core.localplayer:set_wield_index(owx)
end

core.register_cheat('IceBreaker', { category = 'Dig', setting = 'icebreaker' })

-- Inventory to/from ender chest (extracted from emicor)
function ws.invtoec()
	local src = {location = "current_player", inventory = "main"}
	local dst = {location = "current_player", inventory = "enderchest"}
	local srcbounds = {min = 10, max = 0}
	local q = quint.invaction_new()
	local rt = quint.invaction_dump(q, src, dst, srcbounds)
	quint.invaction_apply(q)
	src = {location = "current_player", inventory = "armor"}
	local qq = quint.invaction_new()
	local rtt = quint.invaction_dump(qq, src, dst)
	quint.invaction_apply(qq)
end

function ws.ectoinv()
	local src = {location = "current_player", inventory = "enderchest"}
	local dst = {location = "current_player", inventory = "main"}
	local srcbounds = {min = 0, max = 0}
	local dstbounds = {min = 10, max = 0}
	local q = quint.invaction_new()
	local rt = quint.invaction_dump(q, src, dst, srcbounds, dstbounds)
	quint.invaction_apply(q)
	local ainv = core.get_inventory('current_player').armor
	local plinv = core.get_inventory('current_player').main
	for k, v in ipairs(plinv) do
		if v:get_name():find("helmet") then
			ws.move_stack("current_player", "main", k, "current_player", "armor", 2)
		elseif v:get_name():find("chestplate") then
			ws.move_stack("current_player", "main", k, "current_player", "armor", 3)
		elseif v:get_name():find("leggings") then
			ws.move_stack("current_player", "main", k, "current_player", "armor", 4)
		elseif v:get_name():find("boots") then
			ws.move_stack("current_player", "main", k, "current_player", "armor", 5)
		end
	end
end
