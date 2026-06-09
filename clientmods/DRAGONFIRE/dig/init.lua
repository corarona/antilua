-- dig: dig timing library merged from diglib + digcustom
-- plus dig operations from scaffold: Excavator, TBM, Nuke, Digcyl, etc.

dig = {}

function dig.calculate_dig_time(toolcaps, groups)
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

function dig.get_dig_time(pos)
	local node = core.get_node_or_nil(pos)
	local nodedef = node and core.get_node_def(node.name)
	local groups = nodedef and nodedef.groups
	if not groups then return end
	local player = core.localplayer
	local wielditem = player and player:get_wielded_item()
	local toolcaps = wielditem and wielditem:get_tool_capabilities()
	local tool_time = toolcaps and dig.calculate_dig_time(toolcaps, groups)
	local inv = core.get_inventory("current_player")
	local hand = inv and inv.hand and inv.hand[1] or ItemStack("")
	local hand_toolcaps = hand and hand:get_tool_capabilities()
	local hand_time = hand_toolcaps and dig.calculate_dig_time(hand_toolcaps, groups)
	local tm = math.min(tool_time or math.huge, hand_time or math.huge)
	if tm == math.huge then return end
	return tm
end

function dig.dig_node(pos, max_time)
	local tm = dig.get_dig_time(pos)
	if not tm or (max_time and max_time > 0 and tm > max_time) then return end
	coroutine.wrap(function()
		local debug_msgs = core.settings:get_bool("dig_debug")
		if debug_msgs then print("start_digging", pos.x, pos.y, pos.z) end
		core.interact("start_digging", {type = "node", under = pos, above = pos})
		if debug_msgs then print("sleep", tm) end
		lua_async.sleep(tm * 1000)
		if debug_msgs then print("digging_completed", pos.x, pos.y, pos.z) end
		core.interact("digging_completed", {type = "node", under = pos, above = pos})
	end)()
end

dofile(core.get_modpath(core.get_current_modname()) .. "/autocustom.lua")
dofile(core.get_modpath(core.get_current_modname()) .. "/tunnel.lua")
dofile(core.get_modpath(core.get_current_modname()) .. "/blast.lua")
dofile(core.get_modpath(core.get_current_modname()) .. "/sponge.lua")
