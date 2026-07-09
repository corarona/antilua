local inv = core.get_inventory("player:singleplayer")

-- Helper: move items
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

-- Clear craft grid first
for i = 1, 9 do
  local s = inv.craft[i]
  if s and s:get_count() > 0 and s:get_name() ~= "" then
    move("craft", i, "main", 1, 0)
  end
end

-- Place planks in the correct 2x2 slots: 1,2,4,5 (width=3)
move("main", 3, "craft", 1, 1)
move("main", 3, "craft", 2, 1)
move("main", 3, "craft", 4, 1)
move("main", 3, "craft", 5, 1)

-- Craft
docraft()

-- Move result to main
move("craftresult", 1, "main", 9, 0)

return "done"
