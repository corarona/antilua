# wasplib

Core utility library for DragonfireClient client-side mods. Provides the `ws`
namespace with coordinate math, inventory manipulation, combat helpers, tool
optimization, world interaction (placement/digging), waypoint HUD, and a
global hack registration system (`ws.rg`). All other DRAGONFIRE mods depend
on wasplib.

## Player usage

### Chat commands

| Command | Description |
|---------|-------------|
| `/giveme` | Give items from the currently selected nlist |
| `/givegear` | Give diamond armor/tools with enchants |
| `/tplace <pos>` | Teleport to position, place a node, teleport back |
| `/dumpto` | Dump inventory (non-hotbar) to pointed storage node |
| `/loot` | Take all items from pointed storage node |
| `/cpos1 [x,y,z]` | Set constraint position 1 (defaults to current pos) |
| `/cpos2 [x,y,z]` | Set constraint position 2 |
| `/creset` | Reset constraint positions |
| `/mcl2_invul` | Trigger MCL2 invulnerability exploit (single-use, disconnects) |

### Cheats

| Cheat | Setting | Category | Description |
|-------|---------|----------|-------------|
| HeadSaver | `headsaver` | Player | Prevents suffocation in solid blocks |
| LockView | `lockview` | Bots | Locks camera pitch/yaw to current angles |
| LavaAlarm | `lavaalarm` | Player | Plays alarm bell when lava is detected nearby |
| AutoTool | `autotool` | Inventory | Automatically switches to best tool on dig |
| mcl2-invul | `mcl2-invul` | Player | Invulnerability via damage spam |
| MakeBlocks | — | Inventory | Auto-craft 9x9 blocks from wielded item |
| Loot | — | Inventory | Dump pointed container into player inventory |
| IceBreaker | `icebreaker` | Dig | Dig all ice blocks within 4m radius |

### Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `ws_nodes_per_tick` | int | 8 | Max nodes to process per globalstep |
| `lavaalarm.detect_range` | int | 3 | Range for lava detection |

## API

### Global state

- `ws` — main namespace table
- `ws.c` — alias for `core` (minetest)
- `ws.range` — default interaction range (4)
- `ws.target` — current target entity
- `ws.targetpos` — current target position
- `ws.hotbar_slot` — default hotbar slot (8)
- `ws.registered_globalhacks` — list of registered hack functions
- `ws.displayed_wps` — list of active HUD waypoint IDs

---

### init.lua — Global hack system

`ws.register_globalhacktemplate(name, def)` / `ws.rg(name, def)`

Registers a cheat with a lifecycle template. The `def` table can have:

```lua
{
    name     = "CheatName",       -- display name
    category = "Player",          -- cheat category
    setting  = "cheat_setting",   -- minetest setting toggling this cheat
    on_step  = function(self, dtime) end,  -- called every tick when active
    on_start = function(self) end,         -- called on activation (return true to abort)
    on_stop  = function(self) end,         -- called on deactivation
    daughters = {},               -- sub-settings to enable/disable with parent
    delay    = 0.2,               -- min seconds between on_step calls
    cheat_settings = {},          -- formspec settings UI definitions
    get_formspec = function(setting) end,  -- custom formspec builder for settings
}
```

Legacy signature: `ws.rg(name, category, setting, func, funcstart, funcstop, daughters, delay)`

`ws.step_globalhacks(dtime)` — iterate and execute all registered hacks.

`ws.on_connect(func)` — schedule `func()` to run after localplayer exists.

---

### settings.lua — Settings and utilities

`ws.s(name, [value])` — get or set a string setting.

`ws.sb(name, [value])` — get or set a boolean setting.

`ws.dcm(msg)` — display chat message (`minetest.display_chat_message`).

`ws.set_bool_bulk(settings, value)` — set multiple boolean settings (`true`/`false`).

`ws.shuffle(tbl)` — Fisher-Yates shuffle; returns the table.

`ws.in_list(val, list)` — check if `val` is in `list` table.

`ws.random_table_element(tbl)` — return a random value from a table.

`ws.register_chatcommand_alias(old, ...)` — create aliases for existing chat commands.

`ws.round2(num, numDecimalPlaces)` — round to N decimal places.

`ws.pos_to_string(pos)` — convert position to string (handles tables and strings).

`ws.string_to_pos(pos)` — convert string to rounded position vector.

`ws.between(x, y, z)` — returns `y <= x and x <= z`.

---

### coord.lua — Coordinate math

`ws.coord(x, y, z)` — create a vector.

`ws.ordercoord(c)` — normalize `{x,y,z}` or `{1,2,3}` to `{x=,y=,z=}`.

`ws.optcoord(x, y, z)` — flexible coord constructor (raw numbers or table).

`ws.cadd(c1, c2)` — vector add.

`ws.relcoord(x, y, z, rpos)` — relative coordinate from position.

`ws.is_same_pos(pos1, pos2)` — check if two rounded positions are equal.

`ws.get_reachable_positions(range, under)` — generate list of positions in a cube around player.

`ws.do_area(radius, func, plane)` — iterate reachable positions with callback.

`ws.getaxis()` — return `"x"` or `"z"` based on current facing direction.

`ws.setdir(dir)` — set yaw to face `"north"`/`"south"`/`"east"`/`"west"`.

`ws.getdir(yaw)` — return cardinal direction string from yaw (`"north"`, `"south"`, `"east"`, `"west"`).

`ws.dircoord(f, y, r, rpos, rdir)` — forward/yaw/right relative coordinate; accounts for facing direction. Parameters are in order: forward offset, vertical offset, right offset, optional reference position, optional yaw.

`ws.get_dimension(pos)` — return dimension name based on Y level: `"overworld"`, `"void"`, `"end"`, `"nether"`.

---

### inventory.lua — Inventory operations

`ws.find_item_in_table(items, rnd)` — search inventory for any of the given item strings; returns item name or `false`.

`ws.find_empty(inv)` — return index of first empty slot, or `false`.

`ws.count_empty_slots(inv)` — count empty slots in inventory list.

`ws.find_named(inv, name)` — find slot index of item by name, or `-1`.

`ws.itemnameformat(description)` — strip color codes and truncate to first line.

`ws.find_nametagged(list, name)` — find index by formatted description.

`ws.to_hotbar(it, hslot)` — move item at stack index `it` to hotbar; returns slot.

`ws.switch_to_item(itname, hslot)` — find item in inventory and wield it; returns `true`/`false`.

`core.switch_to_item(item)` — alias for `ws.switch_to_item`.

`ws.in_inv(itname)` — check if item exists in main inventory.

`ws.inv_full(item_to_add)` — check if inventory has no space (optionally for a specific item type).

`ws.inv_get_space(item_to_add)` — count free slots in units of stack_max.

`ws.switch_inv_or_echest(name, max_count, hslot)` — wield item from inventory or ender chest.

`ws.invparse(location)` — parse location string or position into inventory location string (`"current_player"` or `"nodemeta:x,y,z"`).

`ws.invpos(p)` — format position as `"nodemata:x,y,z"`.

---

### tools.lua — Tool optimization

`ws.find_best_tool(nodename)` — search inventory for fastest-digging tool for the given node; returns `(wield_index, dig_time)`.

`ws.get_digtime(nodename)` — return the best dig time for a node.

`ws.select_best_tool(pos)` — find and wield the best tool for the node at `pos` (or node name as string).

---

### world.lua — World interaction

`ws.buildable_to(pos)` — check if node at `pos` is replaceable (buildable_to).

`ws.tplace(p, n, stay)` — teleport to position, place node, teleport back (unless `stay`).

`ws.ytp(param)` — teleport to Y level (upward only, minimum 50 blocks above).

`ws.isnode(pos, arg)` — check if node at pos matches any of the given names.

`ws.can_place_at(pos)` — check if position can be placed into (air, water, lava, or buildable_to).

`ws.can_place_wielded_at(pos)` — check if wielded item is non-empty and position is placeable.

`ws.find_any_swap(items, hslot)` — find any matching item in inventory and switch to it.

`ws.place(pos, items, hslot, place)` — place a node at `pos` from the given item list, switching as needed.

`ws.place_if_able(pos)` — place wielded item if position is placeable.

`ws.is_diggable(pos)` — check if node at `pos` is diggable.

`ws.dig(pos, condition, autotool)` — dig node at `pos`, with optional condition function and autotool selection.

`ws.chunk_loaded()` — returns `true` if no `ignore` nodes within 10m.

`ws.get_near(nodes, range)` — find specified nodes near player; returns list or `false`.

`ws.is_laggy()` — returns `true` if TPS ping > 1000ms.

`ws.donodes(poss, func, condition)` — iterate positions (shuffled, max 32) calling `func` for each, gated by `condition`.

`ws.allow_dig(pos)` — always returns `true`.

`ws.dignodes(poss, condition)` — dig nodes at positions, respecting diggable check.

`ws.replace(pos, arg)` — dig existing node and place a new one from `arg`.

`ws.in_cube(tpos, wpos1, wpos2)` — check if position is within a cube defined by two corners.

`ws.in_wall(pos)` — check if position is within a hardcoded wall region.

`ws.inside_wall(pos)` — check if position is inside a hardcoded inner wall region.

`ws.find_closest_reachable_airpocket(pos)` — find nearest air node within 5m.

`ws.find_closest_pos(poss)` — return closest position in list to player.

`ws.make_blocks()` — auto-craft blocks from 9 of the wielded item.

`ws.invdump(src, dst)` — dump inventory contents between two locations using quint.

`ws.dumpto()` — dump non-hotbar inventory to pointed container.

`ws.loot()` — dump pointed container into player inventory.

`ws.icebreaker()` — dig all ice blocks within 4m radius.

`ws.invtoec()` — move non-hotbar inventory and armor to ender chest.

`ws.ectoinv()` — move ender chest contents to inventory and auto-equip armor.

---

### combat.lua — Combat helpers

`ws.aim(tpos)` — aim (yaw + pitch) at target position using direct line-of-sight.

`ws.gaim(tpos, v, g)` — gravitational aim (projectile arc) with initial velocity `v` and gravity `g`.

`ws.find_player(name)` — find a player by name within 500m; returns `(pos, object_ref)`.

`ws.playeron(p)` — check if a player name is currently on the server.

---

### waypoints.lua — HUD waypoints

`ws.display_wp(pos, name)` — add a HUD waypoint element; returns index into `ws.displayed_wps`.

`ws.clear_wp(ix)` — remove a HUD waypoint by index.

`ws.clear_wps()` — remove all displayed waypoints.

---

### integrations.lua — Constraint system and merged features

`ws.set_pos1(pos)` / `ws.set_pos2(pos)` — set constraint region corners (displays HUD waypoints).

`ws.reset_constraints()` — clear both constraint positions and their HUD waypoints.

`ws.inside_constraints(pos)` — returns `false` if both constraints are set and `pos` is outside.

`ws.place_if_needed(items, pos, place)` — place `items` at `pos` if not already present, respecting constraints.

`ws.dig_if_able(pos)` — dig node at `pos` if inside constraints.

`ws.get_nodes_per_tick()` — read `ws_nodes_per_tick` setting.

`ws.get_slot(inv, filter)` — find first slot in inventory matching optional filter name.

`ws.get_itemslot_bg_v4(x, y, w, h, margin)` — generate formspec item slot background images.

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| MakeBlocks | (func) | Auto-craft 9x9 blocks from wielded item |
| Loot | (func) | Dump pointed container into player inventory |
| IceBreaker | icebreaker | Dig all ice blocks within 4m radius |
| AutoTool | autotool | Automatically switches to best tool on dig |
| HeadSaver | headsaver | Prevents suffocation in solid blocks |
| LavaAlarm | lavaalarm | Plays alarm bell when lava is detected nearby |
| mcl2-invul | mcl2-invul | Invulnerability via damage spam |
| LockView | lockview | Locks camera pitch/yaw to current angles |
