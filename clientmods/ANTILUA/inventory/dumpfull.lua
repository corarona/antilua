core.register_cheat("DumpFull", { category = "Inventory", description = "Dump entire inventory to the ground", func = function()
	local pt = core.get_pointed_thing().under
	local inv = core.get_inventory("nodemeta:"..pt.x..","..pt.y..","..pt.z)
	local plinv = core.get_inventory("current_player")
	for i, v in pairs(plinv.main) do
		ws.move_stack("current_player", "main", i, "nodemeta:"..pt.x..","..pt.y..","..pt.z, "main", i)
	end
end})
