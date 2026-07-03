ws.rg("AutoRefill", {
	category = "Inventory",
	setting = "autorefill",
	description = "Auto-refill hotbar from inventory",
	delay = 0.1,
	on_step = function()
		local player = core.localplayer
		if not player then return end
		local item = player:get_wielded_item()
		local itemname = item:get_name()
		if itemname == "" then return end
		local space = item:get_free_space()
		if space <= 0 then return end
		local wieldindex = player:get_wield_index()
		local i = core.find_item(itemname, wieldindex + 1)
		if i then
			ws.move_stack("current_player", "main", i, "current_player", "main", wieldindex, space)
		end
	end,
})

ws.rg("AutoEject", {
	category = "Inventory",
	setting = "autoeject",
	description = "Auto-eject items from inventory",
	on_step = function()
		local invact = InventoryAction("drop")
		local list = (core.settings:get("eject_items") or ""):split(",")
		local inventory = core.get_inventory("current_player")
		if not inventory or not inventory.main then return end
		for index, stack in pairs(inventory.main) do
			if table.indexof(list, stack:get_name()) ~= -1 then
				invact:from("current_player", "main", index)
				invact:apply()
			end
		end
	end,
})

core.register_chatcommand("eject", {
	params = "<item_string>",
	description = "Configure AutoEject items (comma-separated)",
	func = function(param)
		core.settings:set("eject_items", param)
		return true, "Eject items set to: " .. param
	end,
})
