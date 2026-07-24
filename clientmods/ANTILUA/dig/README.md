# dig

Dig timing library (merged from diglib + digcustom) and bulk digging operations (ported from scaffold). Provides accurate dig-time calculation, node-by-node digging, and a suite of automated excavation tools.

## Player usage

### Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| DigList | `diglist` | Dig all nodes from the selected nlist within range. Configure target nodes via nlist commands (`/nla`, `/nlapn`). |
| DigHead | `dighead` | Dig the node directly above the player's head. |
| Excavator | `excavator` | Tunnel excavation — digs a width×depth area. Modes: `walls` (TBM, places lining) and `full` (full slice including floor/ceiling). |
| WallExcavator | `wallexcavator` | Wall-facing excavator — digs nodes that are part of a wall structure in front of the player. |
| Nuke | `nuke` | Radial blast dig — digs all diggable nodes within a configurable radius around the player. |
| Digcyl | `digcyl` | Cylinder dig — digs nodes within a cylindrical volume (center set via `/digcyl`, radius via `/digcyl_rad`). Stops at configurable floor Y. |
| DigFreeSponge | `autospongedig` | Auto-dig sponges that are no longer in contact with water sources. |

### Settings

- `diglist.range` — search range for DigList (default: 4)
- `diglist.delay` — delay between digs in seconds (default: 0.5)
- `dig.width` — excavation width (default: 5)
- `dig.depth` — excavation depth (default: 1)
- `nuke.radius` — blast radius for Nuke (default: 4, max: 20)
- `digcyl.floor_y` — minimum Y level for Digcyl (default: -125)
- `autospongedig.range` — sponge search range (default: 4)
- `autospongedig.water_distance` — max distance to water for sponge to be considered wet (default: 6)

### Chat commands

| Command | Description |
|---------|-------------|
| `/digcyl [x,y,z]` | Set dig cylinder center (defaults to player pos if no coords given) |
| `/digcyl_rad <radius>` | Set dig cylinder radius |
| `/nls <listname>` | Select the nlist to use as DigList target |

## API

```lua
dig = {}
```

### `dig.calculate_dig_time(toolcaps, groups)`

Calculate the best (lowest) dig time from a tool's capabilities against a node's group levels.

**Parameters:**
- `toolcaps` — tool capability table (from `ItemStack:get_tool_capabilities()`)
- `groups` — node groups table (from `NodeDef.groups`)

**Returns:** `number|nil` — best dig time in seconds, or `nil` if no matching cap.

### `dig.get_dig_time(pos)`

Get the effective dig time for the currently wielded tool against the node at `pos`.

**Parameters:**
- `pos` — `Vector` position of the node

**Returns:** `number|nil` — dig time in seconds, or `nil` if node is undiggable.

### `dig.dig_node(pos, max_time)`

Dig a single node at `pos`, respecting dig time with async sleep. Only digs if the calculated time is under `max_time`.

**Parameters:**
- `pos` — `Vector` position of the node to dig
- `max_time` — `number|nil` — skip digging if the node takes longer than this (optional)
