diglib = {}

function diglib.calculate_dig_time(toolcaps, groups)
	local best_time

	for group, groupdef in pairs(toolcaps.groupcaps) do
		local level = groups[group]

		if level then
			local tm = groupdef.times[level]

			if tm and (not best_time or best_time > tm) then
				best_time = tm
			end
		end
	end

	return best_time
end

function diglib.get_dig_time(pos)
	local node = minetest.get_node_or_nil(pos)
	local nodedef = node and minetest.get_node_def(node.name)
	local groups = nodedef and nodedef.groups

	if not groups then
		return
	end

	local player = minetest.localplayer
	local wielditem = player and player:get_wielded_item()
	local toolcaps = wielditem and wielditem:get_tool_capabilities()
	local tool_time = toolcaps and diglib.calculate_dig_time(toolcaps, groups)

	local inv = minetest.get_inventory("current_player")
	local hand = inv and inv.hand and inv.hand[1] or ItemStack("")
	local hand_toolcaps = hand and hand:get_tool_capabilities()
	local hand_time = hand_toolcaps and diglib.calculate_dig_time(hand_toolcaps, groups)

	local tm = math.min(tool_time or math.huge, hand_time or math.huge)

	if tm == math.huge then
		return
	end

	return tm
end

diglib.dig_node = async(function(pos, max_time)
	local tm = diglib.get_dig_time(pos)
	if not tm or max_time and max_time > 0 and tm > max_time then
		return
	end

	local debug_msgs = minetest.settings:get_bool("diglib_debug")

	if debug_msgs then
		print("start_digging", pos.x, pos.y, pos.z)
	end
	minetest.interact("start_digging", {type = "node", under = pos, above = pos})

	if debug_msgs then
		print("sleep", tm)
	end
	lua_async.sleep(tm * 1000)

	if debug_msgs then
		print("digging_completed", pos.x, pos.y, pos.z)
	end
	minetest.interact("digging_completed", {type = "node", under = pos, above = pos})
end)
