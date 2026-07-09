---
name: playing-the-game
description: Guide for using the Antilua Lua pipe to play MineClonia/MineClone2 — gathering resources, crafting tools, mining, and surviving. Use when you need to automate gameplay tasks, craft items, or interact with the world programmatically.
---

# Playing The Game via Lua Pipe

## Overview

The Antilua Lua pipe lets you control a running client by sending Lua code.
The pipe is a FIFO at `/tmp/antilua_lua` (needs `pipe_lua_enable = true`).

### Quick Start

```bash
python3 -c "
import json
with open('/tmp/code.lua') as f:
    code = f.read()
with open('/tmp/antilua_lua', 'w') as f:
    f.write(json.dumps({'code': code, 'file': '/tmp/resp'}) + chr(10))
"
sleep 1 && cat /tmp/resp
```

Or use the helper script at `skills/playing-the-game/scripts/send_lua.py`.

## Player Info

```lua
core.localplayer:get_pos()           -- {x,y,z}
core.localplayer:get_hp()            -- 0-20
core.localplayer:get_name()          -- player name string
core.localplayer:get_wielded_item()  -- ItemStack in hand
core.localplayer:set_pos({x,y,z})    -- teleport
core.localplayer:set_wield_index(n)  -- select hotbar slot (1-9)
```

## World Interaction

```lua
core.get_node_or_nil({x,y,z})                    -- node name or nil
core.dig_node({x,y,z})                           -- punch/dig a block
core.place_node({x,y,z})                         -- place wielded item
core.find_node_near(pos, radius, {"name",...})   -- nearest matching node
core.find_nodes_in_area(minp, maxp, "name")      -- all matching in area
```

## Inventory

```lua
-- Get the player's inventory (player name from core.localplayer:get_name())
local inv = core.get_inventory("player:" .. core.localplayer:get_name())
-- Lists:
inv.main          -- 36 slots: slots 1-9 = hotbar, 10-36 = backpack
inv.craft         -- 9 slots (3x3 internal, but 2x2 visible without crafting table)
inv.craftpreview  -- 1 slot: recipe preview (read-only)
inv.craftresult   -- 1 slot: craft output
inv.armor         -- armor slots
inv.hand          -- hand slot

-- ItemStack methods:
stack:get_name()   -- "mcl_trees:tree_pale_oak"
stack:get_count()  -- stack size
stack:is_empty()   -- boolean
stack:take_item(n) -- returns new ItemStack with n items
```

## Crafting System

Crafting uses `InventoryAction` objects sent to the server.

### 2x2 Grid (No Crafting Table)

Without a crafting table, only 2x2 recipes work. The craft list is 9 slots with width=3, so the visual 2x2 is at indices **1,2,4,5**:

```
[1] [2]          ← craft[1], craft[2]
[4] [5]          ← craft[4], craft[5]
```

### Moving Items

```lua
local a = InventoryAction("move")
a:from("current_player", "main", 3)   -- from list "main" slot 3
a:to("current_player", "craft", 1)    -- to list "craft" slot 1
a:set_count(1)                         -- 1 item, or 0 for all
a:apply()
```

### Triggering Craft

```lua
local a = InventoryAction("craft")
a:craft("current_player")
a:set_count(1)
a:apply()
```

### Taking Result

```lua
local a = InventoryAction("move")
a:from("current_player", "craftresult", 1)
a:to("current_player", "main", 99)    -- 99 = first available slot
a:set_count(0)
a:apply()
```

## Complete: Get a Stone Pickaxe

### Step 1: Find & Gather Wood

```lua
local pos = core.localplayer:get_pos()
local logs = core.find_nodes_in_area(
  {x = pos.x - 20, y = pos.y - 5, z = pos.z - 20},
  {x = pos.x + 20, y = pos.y + 10, z = pos.z + 20},
  "mcl_trees:tree_pale_oak"
)
-- Move near first log and dig it
core.localplayer:set_pos({x = logs[1].x + 1, y = logs[1].y, z = logs[1].z})
core.dig_node(logs[1])
-- Move to pick up drops
core.localplayer:set_pos({x = logs[1].x, y = logs[1].y, z = logs[1].z})
```

### Step 2: Craft Planks

```lua
function move(from_list, from_idx, to_list, to_idx, count)
  local a = InventoryAction("move")
  a:from("current_player", from_list, from_idx)
  a:to("current_player", to_list, to_idx)
  a:set_count(count or 0)
  a:apply()
end
function docraft()
  local a = InventoryAction("craft")
  a:craft("current_player")
  a:set_count(1)
  a:apply()
end

-- 1 log in craft[1] (any slot in 2x2 works for plank recipe)
move("main", 1, "craft", 1, 1)
docraft()
move("craftresult", 1, "main", 2, 0)
-- Result: mcl_trees:wood_pale_oak x4
```

### Step 3: Craft Crafting Table

Recipe: 4 planks in 2x2 (craft slots 1,2,4,5).

```lua
move("main", 2, "craft", 1, 1)
move("main", 2, "craft", 2, 1)
move("main", 2, "craft", 4, 1)
move("main", 2, "craft", 5, 1)
docraft()
move("craftresult", 1, "main", 3, 0)
-- Result: mcl_crafting_table:crafting_table
```

### Step 4: Place Crafting Table

```lua
-- Move to hotbar and select
move("main", 3, "main", 8, 0)
core.localplayer:set_wield_index(8)
-- Place adjacent to player
local pos = core.localplayer:get_pos()
core.place_node({x = pos.x + 1, y = pos.y, z = pos.z})
```

### Step 5: Craft Sticks

Requires being near the crafting table (3x3 grid). Recipe: 2 planks vertically.

```lua
-- 3x3 grid indices: [1][2][3] / [4][5][6] / [7][8][9]
-- Sticks: planks at slots 1, 4 (vertical column)
move("main", 2, "craft", 1, 1)
move("main", 2, "craft", 4, 1)
docraft()
move("craftresult", 1, "main", 10, 0)
-- Result: mcl_core:stick x4
```

### Step 6: Craft Wooden Pickaxe

Recipe: 3 planks across top + 2 sticks down middle.

```lua
move("main", 2, "craft", 1, 1)  -- plank
move("main", 2, "craft", 2, 1)  -- plank
move("main", 2, "craft", 3, 1)  -- plank
move("main", 10, "craft", 5, 1) -- stick
move("main", 10, "craft", 8, 1) -- stick
docraft()
move("craftresult", 1, "main", 6, 0)
-- Result: mcl_tools:pick_wood
```

### Step 7: Equip & Mine Cobblestone

```lua
core.localplayer:set_wield_index(6)  -- select pickaxe slot
-- Find stone nearby
local stone = core.find_node_near(core.localplayer:get_pos(), 20, "mcl_core:stone")
if stone then
  core.localplayer:set_pos({x = stone.x, y = stone.y + 2, z = stone.z})
  core.dig_node(stone)
end
-- Moves to pick up drops
-- Result (with wood pickaxe): mcl_core:cobble
```

### Step 8: Craft Stone Pickaxe

Same recipe as wooden, but with cobblestone. Requires 3 cobble + 2 sticks.

```lua
move("main", 6, "craft", 1, 1)  -- cobble (adjust slot)
move("main", 6, "craft", 2, 1)  -- cobble
move("main", 6, "craft", 3, 1)  -- cobble
move("main", 10, "craft", 5, 1) -- stick
move("main", 10, "craft", 8, 1) -- stick
docraft()
move("craftresult", 1, "main", 7, 0)
-- Result: mcl_tools:pick_stone
```

## Respawning

`core.send_respawn()` sends the **legacy** packet (TOSERVER_RESPAWN_LEGACY, opcode 0x38) which has **no handler** on modern servers. Instead:

1. The server shows a death formspec `__builtin:death` with a "Respawn" `button_exit`
2. Closing the formspec sends `fields.quit = true`, triggering `player:respawn()`

To respawn from the Lua pipe:

```lua
core.send_inventory_fields("__builtin:death", {quit = "true"})
```

Or enable auto-respawn before dying:

```lua
core.settings:set_bool("autorespawn", true)
```

The `autorespawn` cheat calls `core.send_respawn()` from the `register_on_death` callback, which doesn't work either (same legacy packet). Use `send_inventory_fields` for the server-side death formspec.

## Helper Scripts

Scripts are in `skills/playing-the-game/scripts/`:

| Script | Purpose |
|--------|---------|
| `send_lua.py` | Send a .lua file to the pipe and print response |
| `check_inv.lua` | Show all inventory contents |
| `check_hp.lua` | Show HP |
| `where.lua` | Show position + surrounding blocks |
| `craft_table.lua` | Craft a crafting table from planks |
| `craft_sticks.lua` | Craft sticks from planks |
| `craft_pick.lua` | Craft a wooden pickaxe |
| `place_table.lua` | Place the crafting table |
| `dig_stone.lua` | Mine stone with equipped pickaxe |
| `find_trees.lua` | Find nearby trees |
| `gather_wood.lua` | Gather wood from nearest tree |
| `consolidate.lua` | Stack item stacks in inventory |

## Item Names (MineClonia)

| Item | Name |
|------|------|
| Pale Oak Log | `mcl_trees:tree_pale_oak` |
| Pale Oak Planks | `mcl_trees:wood_pale_oak` |
| Stick | `mcl_core:stick` |
| Crafting Table | `mcl_crafting_table:crafting_table` |
| Wooden Pickaxe | `mcl_tools:pick_wood` |
| Stone Pickaxe | `mcl_tools:pick_stone` |
| Stone | `mcl_core:stone` |
| Cobblestone | `mcl_core:cobble` |
| Dirt | `mcl_core:dirt` |
| Dirt with Grass | `mcl_core:dirt_with_grass` |
| Pale Oak Leaves | `mcl_trees:leaves_pale_oak` |

## Common Pitfalls

| Mistake | Fix |
|---------|-----|
| `get_inventory("player:singleplayer")` fails | Use actual player name from `core.localplayer:get_name()` |
| Craft grid indices wrong for 2x2 | Use 1,2,4,5 (not 1,2,3,4) — craft list has width=3 internally |
| `core.send_respawn()` does nothing | Sends legacy packet; use `send_inventory_fields("__builtin:death", {quit="true"})` |
| Items don't appear after digging | Walk/move to where they dropped; run `set_pos` near the dig site |
| InventoryAction moves reverted by sync | The server syncs inventory between actions; wait for next read |
| Pipe stops responding | Don't delete/recreate the FIFO — client keeps old inode. Restart client |
| `#` in Lua code breaks bash echo | Use Python or write code to a `.lua` file and read it |
