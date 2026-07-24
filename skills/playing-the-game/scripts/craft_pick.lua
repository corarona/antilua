function move(from_list, from_idx, to_list, to_idx, count)
	local act = InventoryAction("move")
	act:from("current_player", from_list, from_idx)
	act:to("current_player", to_list, to_idx)
	act:set_count(count or 0)
	act:apply()
end

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

-- Wooden pickaxe recipe (3x3 grid):
-- [1=plank] [2=plank] [3=plank]
-- [4]       [5=stick] [6]
-- [7]       [8=stick] [9]
move("main", 3, "craft", 1, 1)
move("main", 3, "craft", 2, 1)
move("main", 3, "craft", 3, 1)
move("main", 10, "craft", 5, 1)
move("main", 10, "craft", 8, 1)

docraft()

-- Move result
move("craftresult", 1, "main", 11, 0)

return "pickaxe crafted"
