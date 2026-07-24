-- Helper: move items between inventory lists
function move(from_list, from_idx, to_list, to_idx, count)
	local act = InventoryAction("move")
	act:from("current_player", from_list, from_idx)
	act:to("current_player", to_list, to_idx)
	act:set_count(count or 0)
	act:apply()
end

-- Helper: craft
function docraft()
	local act = InventoryAction("craft")
	act:craft("current_player")
	act:set_count(1)
	act:apply()
end

local inv = core.get_inventory("player:singleplayer")

-- Clear craft grid
for i = 1, 9 do
	local s = inv.craft[i]
	if s and s:get_count() > 0 and s:get_name() ~= "" then
		move("craft", i, "main", 1, 0)
	end
end

-- Place 2 planks vertically in the 3x3 craft grid (for stick recipe)
-- Planks at slots 1 and 4 (column 1, rows 1 and 2)
move("main", 3, "craft", 1, 1)
move("main", 3, "craft", 4, 1)

-- Craft sticks
docraft()

-- Move result to inventory
move("craftresult", 1, "main", 10, 0)

return "sticks crafted"
