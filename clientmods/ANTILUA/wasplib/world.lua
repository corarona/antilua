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

function ws.dignodes(poss, condition)
	return ws.donodes(poss, ws.dig, function(pos)
		if condition and condition(pos) == false then return false end
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

core.register_cheat("MakeBlocks", { category = "Inventory", func = ws.make_blocks, description = "Create a block of the selected node type" })

--- Loot matching items from nearby containers into player inventory.
-- @param items  Array of item name strings to loot (e.g. {"mcl_core:stone"})
-- @param range  Search radius (default 5)
-- @param max_per_scan  Max items to move per call (default 16)
-- @return number of items moved
function ws.loot_list(items, range, max_per_scan)
	if not core.localplayer then return 0 end
	range = range or 5
	max_per_scan = max_per_scan or 16
	if #items == 0 then return 0 end

	local needed = {}
	for _, name in ipairs(items) do
		needed[name] = true
	end

	local pos = core.localplayer:get_pos()
	local minp = vector.offset(pos, -range, -range, -range)
	local maxp = vector.offset(pos, range, range, range)
	local containers = core.find_nodes_with_meta(minp, maxp)
	if #containers == 0 then return 0 end

	local plinv = core.get_inventory("current_player")
	if not plinv then return 0 end
	local main_size = #plinv.main

	local moved = 0
	for _, cpos in ipairs(containers) do
		if moved >= max_per_scan then break end
		local loc = "nodemeta:" .. cpos.x .. "," .. cpos.y .. "," .. cpos.z
		local inv = core.get_inventory(loc)
		if inv then
			for listname, stacks in pairs(inv) do
				if moved >= max_per_scan then break end
				for idx, stack in ipairs(stacks) do
					if moved >= max_per_scan then break end
					if not stack:is_empty() then
						local name = stack:get_name()
						if needed[name] then
							for slot = 1, main_size do
								local plstack = plinv.main[slot]
								if plstack:is_empty() then
									ws.move_stack(loc, listname, idx,
										"current_player", "main", slot)
									moved = moved + 1
									break
								end
							end
						end
					end
				end
			end
		end
	end
	return moved
end

-- IceBreaker: dig ice in range (extracted from emicor)
function ws.icebreaker()
	local owx = core.localplayer:get_wield_index()
	local nds = core.find_nodes_near(ws.dircoord(0, 0, 0), 4, {'mcl_core:ice'}, true)
	ws.dignodes(nds)
	core.localplayer:set_wield_index(owx)
end

core.register_cheat('IceBreaker', { category = 'Dig', setting = 'icebreaker', description = "Break ice by walking on it" })
