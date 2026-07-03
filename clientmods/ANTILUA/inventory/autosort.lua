core.register_cheat("AutoSort", { category = "Inventory", setting = "auto_sort", description = "Auto-sort inventory", func = function()
	local inv = core.get_inventory("current_player")
	if not inv or not inv.main then return end

	local items = {}
	for i, stack in ipairs(inv.main) do
		if not stack:is_empty() then
			table.insert(items, { slot = i, stack = stack })
		end
	end

	table.sort(items, function(a, b)
		if a.stack:get_name() == b.stack:get_name() then
			return a.slot < b.slot
		end
		return a.stack:get_name() < b.stack:get_name()
	end)

	for target_slot, entry in ipairs(items) do
		if entry.slot ~= target_slot then
			ws.move_stack("current_player", "main", entry.slot,
				"current_player", "main", target_slot, entry.stack:get_count())
		end
	end
end })
