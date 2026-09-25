---
name: playing-the-game
description: Guide for playing MineClonia/MineClone2 through a running Antilua client — gathering resources, crafting tools, mining, and surviving. Prefers the antilua MCP server's structured tools (position, teleport, dig/place, inventory, crafting, chat, screenshots); falls back to the raw Lua pipe. Use when you need to automate gameplay tasks, craft items, or interact with the world programmatically.
---

# Playing The Game via the Antilua MCP Server

## Overview

Control a running Antilua client through its MCP server (`util/mcp/`), which
exposes structured tools over the client's Lua pipe. Requires the client
running with `pipe_lua_enable = true` (the `antilua-mcp` server connects via
`ANTILUA_PIPE_PATH`, default `/tmp/antilua_lua`).

Prefer MCP tools over raw pipe writes — they handle JSON serialization,
response files, and pacing for you, and `screenshot()` gives you eyes on the
world. Use the raw Lua pipe (`skills/antilua-lua-pipe/SKILL.md`, or the
`run_lua` escape hatch) only for things the curated tools don't cover.

### Quick Start

1. Orient: `get_player_pos()` → `screenshot()` → `get_player_look()`.
2. Act: `teleport` / `dig_node` / `place_node` / `move_item` / `craft`.
3. Verify: `get_node` / `get_inventory` / `screenshot()`.

## Player Info

| MCP tool | Notes |
|----------|-------|
| `get_player_pos()` | `{x, y, z}` node coords |
| `get_player_look()` | `{yaw, pitch}` (deg), `roll` (rad) |
| `teleport({x, y, z})` | Move the player; returns new pos |
| `set_look(yaw, pitch)` | Aim the camera (deg) |
| `run_lua("return core.localplayer:get_hp()")` | HP (0-20); also `get_name()`, `get_wielded_item()`, `get_wield_index()` |

## World Interaction

| MCP tool | Notes |
|----------|-------|
| `get_node({x,y,z})` | `{name, param1, param2}` or null (client map — can lag; cross-check with `screenshot()`) |
| `dig_node({x,y,z})` | Punch/dig a block `{digged: true/false}` |
| `place_node({x,y,z})` | Places the *wielded* item |
| `find_nodes_near(pos, radius, [names])` | Positions list |
| `get_pointed_thing()` | What the camera is looking at |

Note: `place_node` places whatever is wielded. Put the item in the hotbar
(`move_item` within `main`) and select it first (via `run_lua`:
`core.localplayer:set_wield_index(n)`, slots 1-9).

## Inventory

`get_inventory()` returns `{list: [{slot, name, count}, ...]}` for `main` (36;
1-9 hotbar), `craft` (9), `craftresult` (1), `craftpreview` (1), `armor`,
`hand`. Use `move_item(from_list, from_slot, to_list, to_slot, count)` —
`count` 0 = whole stack. Check `get_inventory()` after moves (server sync).

## Crafting System

Crafting uses inventory moves + the `craft` action. Without a crafting table
only 2x2 recipes work (`craft` list indices **1,2,4,5** — it has width 3
internally); place a crafting table for 3x3.

| Step | MCP tools |
|------|-----------|
| Move items into grid | `move_item("main", slot, "craft", grid, 1)` |
| Trigger craft | `craft(1)` |
| Take result | `take_craft_result(main_slot)` (moves `craftresult` → `main`) |

## Complete: Get a Stone Pickaxe

Orient first (`get_player_pos()`, `screenshot()`), then:

1. **Wood**: `find_nodes_near(pos, 20, ["mcl_trees:tree_pale_oak"])` → `teleport`
   next to the log → `dig_node(log)` → `teleport` onto the spot to pick up drops.
2. **Planks**: `move_item("main", log_slot, "craft", 1, 1)` → `craft()` →
   `take_craft_result(slot)` — `mcl_trees:wood_pale_oak` x4.
3. **Crafting table**: planks into `craft` 1,2,4,5 → `craft()` → take —
   `mcl_crafting_table:crafting_table`; move to hotbar, wield, `place_node`
   adjacent (3x3 grid needs the table nearby).
4. **Sticks**: planks vertical at `craft` 1,4 → `craft()` → take —
   `mcl_core:stick` x4.
5. **Wooden pickaxe**: planks across `craft` 1,2,3 + sticks at 5,8 → `craft()` →
   take — `mcl_tools:pick_wood`.
6. **Stone**: wield the wooden pickaxe (`run_lua` `set_wield_index`),
   `find_nodes_near(pos, 20, ["mcl_core:stone"])`, dig, collect.
7. **Stone pickaxe**: 3 cobble across 1,2,3 + 2 sticks at 5,8 → `mcl_tools:pick_stone`.

Verify each step with `get_inventory()` (and `screenshot()` for placement).

## Respawning

If dead (HP 0), interacts silently do nothing. Respawn via the death screen:

```lua
-- run_lua:
core.send_inventory_fields("__builtin:death", {quit = "true"})
```

Or prevent death during automated play: `set_setting("enable_damage", "false")`
or keep to a safe area. (`core.send_respawn()` is a dead legacy packet.)

## Cheats & Settings

`toggle_cheat(name, enabled)` / `set_setting(name, value)`:
`jetpack`, `fullbright`, `fastdig`, `autojump`, `fly`, `noclip`, …

See `doc/al_csm_api.md` for the full cheat list.

## Screenshots

`screenshot()` returns a scene-only PNG (no HUD). Needs a client that is
rendering — fails if detached/hidden (reattach first). Invaluable for
verifying placements the client map misreports.

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
| `place_node` puts the wrong block | It places the *wielded* item — move to hotbar + `set_wield_index`, verify via `run_lua`, and confirm `digged/placed` in the tool result (server wield lags headless) |
| `get_node` disagrees with reality | Client map lags/predicts; confirm placements with `screenshot()` or re-sync |
| Craft grid indices wrong for 2x2 | Use 1,2,4,5 (not 1,2,3,4) — craft list has width=3 internally |
| Crafting a 3x3 recipe fails | Needs a placed crafting table nearby |
| Items missing after digging | Teleport onto the drop spot; check `get_inventory()` (server sync) |
| Server command fails | `{ok:false, error:...}` — inspect the error, don't assume success |
| Screenshot fails | Client detached/hidden — reattach; needs a rendering frame |
| Need raw Lua | `run_lua(code)` — same client state, JSON results; see `skills/antilua-lua-pipe/SKILL.md` for the pipe itself |
| Pipe stops responding | Don't delete/recreate the FIFO — the client keeps the old inode; restart the client |

## Helper Scripts

Gameplay Lua snippets live in `skills/playing-the-game/scripts/` (kept for
`run_lua` / raw-pipe use):

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
