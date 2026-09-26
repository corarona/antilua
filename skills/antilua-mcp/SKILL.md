---
name: antilua-mcp
description: Use when controlling a running Antilua client through its MCP server (structured tools over the Lua pipe) — getting player position/look, teleporting, digging/placing nodes, inventory and crafting, running server chat commands, toggling cheats, or taking screenshots. Prefer this over raw `antilua-lua-pipe` bash when the MCP server is available in the host.
---

# Antilua MCP Control

## Overview

The MCP server (`util/mcp/`) exposes a running Antilua client to agents as
structured tools via the Lua pipe. Results are JSON. Requires the client
running with `pipe_lua_enable = true`.

If the MCP host already has the `antilua-mcp` server registered, just call the
tools. Otherwise see AGENTS.md → MCP Server for setup, then:

```sh
uv sync --project util/mcp
# register in your host's MCP config:
#   command: uv run --project util/mcp antilua-mcp
#   env:     ANTILUA_PIPE_PATH=/tmp/antilua_lua, ANTILUA_TIMEOUT=10
```

## Workflow

Start by orienting yourself:

1. `get_player_pos()` — where am I? (`get_client_status()` if tools fail)
2. `screenshot()` — what does the world look like? (scene-only PNG; needs a
   rendering client, not detached/hidden)
3. `get_player_look()` / `get_pointed_thing()` — where am I looking / what am
   I pointing at?
4. `get_inventory()` — what do I have?

## Tools

| Tool | Notes |
|------|-------|
| `run_lua(code)` | Escape hatch: any Lua; `{ok, value}` (value JSON-serialized, `null` when the chunk returns nothing) or `{ok:false, error}` |
| `get_player_pos` / `get_player_look` | yaw/pitch in degrees, roll in radians |
| `teleport(pos)` / `set_look(yaw, pitch)` | `pos` is `{x,y,z}` |
| `get_node` / `dig_node` / `place_node` | `get_node` → `{node}` (`null` if unloaded); place/dig use the *wielded* item |
| `find_nodes_near` / `find_nodes_near_under_air` | `{count, positions}`; the under-air variant finds placement surfaces |
| `get_pointed_thing()` | `{type: node\|object\|nothing, under, above, ...}` (nothing = underwater/sky) |
| `interact(action, pointed)` | Real right-click/use/place/dig — `use` on a node opens its formspec (`pointed` from `get_pointed_thing`) |
| `get_node_meta(pos, keys?)` / `set_node_meta(pos, fields)` | Node meta read / formspec-field submit (server applies only if the formspec was shown) |
| `get_objects_near(pos, radius)` | `{objects: [{id, pos, name, is_player}]}` |
| `get_inventory(location?)` / `move_item` / `move_items` / `craft` / `take_craft_result` | Lists: `main` (36), `craft` (9), `craftresult` (1); `count` 0 = whole stack; location: `current_player`, `nodemeta:x,y,z`, `detached:name` |
| `wield_item(name)` / `give_and_wield(name)` | Substring-match wield / give-if-missing-then-wield |
| `run_server_chatcommand(cmd, args?, wait?)` | Sends /command and returns the server's chat response in `chat` (the result message IS the return value) |
| `get_chat_log(count?)` | Last received chat lines `[{id, ts, text}]` |
| `wait_until(code, timeout?, interval?)` | Poll any Lua expression until truthy — use instead of hand-rolled polling loops |
| `get_client_status()` | `{connected, joined, player_name, chat_buffer}` diagnostics |
| `set_time(value)` / `set_setting` / `toggle_cheat` | e.g. `set_time("noon")`, cheats like `jetpack`, `fullbright`, `fastdig` |
| `screenshot(pos?)` | Scene-only PNG; `pos` aims the camera (look restored after) |

## Common pitfalls

- **`move_item`/`craft` don't chain** — call `apply()` on the InventoryAction
  inside the tool; the tool already does this, so just pass slots/lists.
- **Crafting a 3x3 recipe needs a crafting table** — the player only has a 2x2
  grid by default; place a crafting table and it opens the 3x3 grid.
- **`take_craft_result(target_slot)`** moves craft output to a `main` slot
  (target_slot 1-36). Check `craftresult` in `get_inventory()` first.
- **Chat commands report via `chat`** — `run_server_chatcommand` returns the
  server's reply lines (e.g. "You don't have permission…"); inspect them
  instead of re-polling state. `/giveme` etc. still need the `give` privilege
  (`grantme all` first on fresh worlds).
- **Client inventory lags a beat** — after giving/moving items, poll with
  `wait_until("return find_stack('name') ~= nil", …)` or check the returned
  `inventory` snapshot before assuming.
- **`set_node_meta` needs a shown formspec** — the server silently rejects
  fields for nodes whose formspec it never sent to the player.
- **Screenshot fails if the client is detached/hidden** (no frames rendered);
  reattach first.
- **Anything not covered** — use `run_lua(code)`; it executes in the same
  client scripting state as the pipe, with `core.*` and `ws.*` available.