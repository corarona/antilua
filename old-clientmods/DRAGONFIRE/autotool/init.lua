autotool = {}

local function check_tool(stack, node_groups, old_best_time)
	local toolcaps = stack:get_tool_capabilities()
	if not toolcaps then return end
	local best_time = old_best_time
	for group, groupdef in pairs(toolcaps.groupcaps) do
		local level = node_groups[group]
		if level then
			local this_time = groupdef.times[level]
			if this_time and this_time < best_time then
				best_time = this_time
			end
		end
	end
	return best_time < old_best_time, best_time
end

local function find_best_tool(nodename)
	local player = minetest.localplayer
	local inventory = minetest.get_inventory("current_player")
	local node_groups = minetest.get_node_def(nodename).groups
	local new_index = player:get_wield_index()
	local is_better, best_time = false, math.huge
	is_better, best_time = check_tool(player:get_wielded_item(), node_groups, best_time)
	if inventory.hand then
		is_better, best_time = check_tool(inventory.hand[1], node_groups, best_time)
	end
	for index, stack in ipairs(inventory.main) do
		is_better, best_time = check_tool(stack, node_groups, best_time)
		if is_better then
			new_index = index
		end
	end
	return new_index, best_time
end

function autotool.select_best_tool(nodename)
	local new_index, best_time = find_best_tool(nodename)
	minetest.localplayer:set_wield_index(new_index)
	return best_time
end

local new_index, old_index, pointed_pos, best_time

minetest.register_on_punchnode(function(pos, node)
	if minetest.settings:get_bool("autotool") then
		pointed_pos = pos
		old_index = old_index or minetest.localplayer:get_wield_index()
		new_index, best_time = find_best_tool(node.name)
	end
end)

minetest.register_globalstep(function()
	local player = minetest.localplayer
	if not new_index then return end
	if minetest.settings:get_bool("autotool") then
		local pt = minetest.get_pointed_thing()
		if pt and pt.type == "node" and vector.equals(minetest.get_pointed_thing_position(pt), pointed_pos) and player:get_control().dig then
			player:set_wield_index(new_index)
			if best_time == 0 then
				minetest.dig_node(pointed_pos)
			end
			return
		end
	end
	player:set_wield_index(old_index)
	new_index, old_index, pointed_pos, best_time = nil
end)

minetest.register_cheat("AutoTool", "Inventory", "autotool")
