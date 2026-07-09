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

-- Get inventory
local inv = core.get_inventory("player:singleplayer")

-- Step 1: Clear any items from craft grid
for i = 1, 9 do
  local s = inv.craft[i]
  if s and s:get_count() > 0 and s:get_name() ~= "" then
    move("craft", i, "main", 1, 0)
  end
end

-- Step 2: Find planks in main inventory
local plank_slot = nil
for i = 1, 36 do
  local s = inv.main[i]
  if s and s:get_name() == "mcl_trees:wood_pale_oak" and s:get_count() >= 4 then
    plank_slot = i
    break
  end
end

if not plank_slot then
  -- Check craft grid for stray items
  for i = 1, 36 do
    local s = inv.main[i]
    if s and s:get_name() == "mcl_trees:wood_pale_oak" and s:get_count() >= 1 then
      plank_slot = i
      break
    end
  end
end

if not plank_slot then
  return "ERROR: no planks found"
end

-- Step 3: Place 4 planks in 2x2 craft grid (slots 1,2,3,4)
-- The 2x2 grid is: [1][2] on top row, [3][4] on bottom row
move("main", plank_slot, "craft", 1, 1)
move("main", plank_slot, "craft", 2, 1)
move("main", plank_slot, "craft", 3, 1)
move("main", plank_slot, "craft", 4, 1)

-- Step 4: Craft the crafting table
docraft()

-- Step 5: Move result to inventory
-- First find a free slot
local free = 1
for i = 1, 36 do
  local s = inv.main[i]
  if not s or s:is_empty() then
    free = i
    break
  end
end
move("craftresult", 1, "main", free, 0)

return "crafting table crafted"
