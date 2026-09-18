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

1. `get_player_pos()` — where am I?
2. `screenshot()` — what does the world look like? (scene-only PNG; needs a
   rendering client, not detached/hidden)
3. `get_player_look()` / `get_pointed_thing()` — where am I looking / what am
   I pointing at?
4. `get_inventory()` — what do I have?

## Tools

| Tool | Notes |
|------|-------|
| `run_lua(code)` | Escape hatch: any Lua, JSON-serialized result |
| `get_player_pos` / `get_player_look` | yaw/pitch in degrees, roll in radians |
| `teleport(pos)` / `set_look(yaw, pitch)` | `pos` is `{x,y,z}` |
| `get_node` / `dig_node` / `place_node` / `find_nodes_near` / `get_pointed_thing` | Node coords |
| `get_inventory` / `move_item` / `craft` / `take_craft_result` | Lists: `main` (36), `craft` (9), `craftresult` (1); `count` 0 = whole stack |
| `run_server_chatcommand` / `send_chat` / `get_server_info` / `get_player_names` / `get_privilege_list` | Server interaction |
| `set_setting` / `toggle_cheat` | e.g. `jetpack`, `fullbright`, `fastdig`, `autojump` |
| `screenshot()` | Scene-only PNG |

## Common pitfalls

- **`move_item`/`craft` don't chain** — call `apply()` on the InventoryAction
  inside the tool; the tool already does this, so just pass slots/lists.
- **Crafting a 3x3 recipe needs a crafting table** — the player only has a 2x2
  grid by default; place a crafting table and it opens the 3x3 grid.
- **`take_craft_result(target_slot)`** moves craft output to a `main` slot
  (target_slot 1-36). Check `craftresult` in `get_inventory()` first.
- **Server command failures** come back as `{ok:false, error:...}` — inspect
  rather than assuming success.
- **Screenshot fails if the client is detached/hidden** (no frames rendered);
  reattach first.
- **Anything not covered** — use `run_lua(code)`; it executes in the same
  client scripting state as the pipe, with `core.*` and `ws.*` available.