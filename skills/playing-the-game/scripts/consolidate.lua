-- Move planks from main[5] to main[3]
local act = InventoryAction("move")
act:from("current_player", "main", 5)
act:to("current_player", "main", 3)
act:set_count(0)
act:apply()
return "consolidated"
