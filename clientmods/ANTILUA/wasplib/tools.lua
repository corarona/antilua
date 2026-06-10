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
	local player = core.localplayer
	local inventory = core.get_inventory("current_player")
	local node_groups = core.get_node_def(nodename).groups
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

function ws.find_best_tool(nodename)
	return find_best_tool(nodename)
end

function ws.get_digtime(nodename)
	local idx, tm = ws.find_best_tool(nodename)
	return tm
end

function ws.select_best_tool(pos)
	local nodename = 'air'
	if type(pos) == "table" then
		local nd = core.get_node_or_nil(pos)
		if nd then nodename = nd.name end
	elseif type(pos) == "string" then
		nodename = pos
	end
	local t = find_best_tool(nodename)
	core.localplayer:set_wield_index(ws.to_hotbar(t, ws.hotbar_slot))
end
