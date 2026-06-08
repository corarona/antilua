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
