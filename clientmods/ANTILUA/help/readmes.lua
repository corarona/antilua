-- readmes.lua: README content for all mods, embedded as Lua strings
-- Auto-generated. Regenerate after changing README.md files.
return {
	["autocraft"] = [[
# autocraft

Automated crafting GUI that fills the craft grid from inventory and repeatedly crafts items. Recipes are auto-detected when you arrange items on the grid and are persisted via `core.settings`.

## Player usage

**Chat commands:**

- `/autocraft` — Opens the autocraft GUI with a 3×3 craft grid, inventory, and toggle button.
- `/autocraft_list` — Shows all known recipes in a list; click a recipe to select/deselect it.
- `/autocraft_clear` — Clears all stored recipes.

**Cheat:** `Autocraft` (category: Player) — Toggles the `autocraft` setting.

**Recipe persistence:** Recipes survive restarts via `core.settings:get/set("autocraft_recipes")` as JSON.

**Behavior:** While the cheat is on and a recipe is selected, the mod polls the craft grid every 0.3 s: takes the result, refills ingredients from the main inventory, and re-crafts. If ingredients run out, it pauses and reports.

## API

None.

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| Autocraft | autocraft | Automated crafting — fills craft grid and repeatedly crafts selected recipes. |
]],
	["autoeat"] = [[
# autoeat

Automatically eats food when the player's hunger drops below a configurable threshold. Integrates with the `autodupe` mod when only one food type is available.

## Player usage

**Cheat:** `AutoEat` (category: Player) — Toggles auto-eating via the `autoeat` setting.

**Settings:**

- `autoeat` (bool) — Master toggle.
- `autoeat_cooldown` (number, default 0.5) — Minimum seconds between eats.
- `autoeat_hunger` (number, default 9) — Hunger threshold; eat when below this value. The mod reads the `hbhunger_icon.png` HUD element to determine current hunger (falls back to 20 if not found).

## API

All exported on the global `autoeat` table.

- `autoeat.lock` (bool) — Lock flag; when `true` the globalstep skips eating. Set by the autodupe integration.
- `autoeat.eat()` — Finds the first food item in the main inventory, wields it, and activates it. If only one food type is present and `autodupe` exists, delegates to `autodupe.needed()` instead.
- `autoeat.get_hunger()` → number — Returns the player's current hunger level by reading the hunger HUD element (or 20 as fallback).

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| AutoEat | autoeat | Automatically eats food when hunger drops below configurable threshold. |
]],
	["autoevade"] = [[
# autoevade

Teleports the player a random horizontal distance when a projectile (arrow, splash potion, or shulker bullet) comes within trigger range.

## Player usage

**Cheat:** `AutoEvade` (category: Combat) — Registered via `ws.rg()` with the `autoevade` setting.

**Settings:**

- `autoevade.scan_range` (number, default 4, min 1, max 20) — Radius for scanning nearby objects for projectiles.
- `autoevade.trigger_distance` (number, default 4, min 1, max 10) — Distance at which a detected projectile triggers evasive teleport.
- `autoevade.evade_distance` (number, default 2, min 1, max 10) — Maximum random horizontal offset (X/Z) for the teleport.

**Behavior:** On each global step, scans nearby objects for projectile textures (`arrow_box`, `_splash`, `shulkerbullet.png`). If a projectile with non-zero velocity is within trigger distance, the player is teleported to a random offset position (Y=2, X/Z in ±evade_distance).

## API

None.

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| AutoEvade | autoevade | Teleports player away from incoming projectiles within trigger range. |
]],
	["autokey"] = [[
# autokey

Continuously holds a key (e.g. sneak, sprint) while a cheat setting is enabled, releasing it when the cheat is toggled off.

## Player usage

**Cheats:**

- `AutoSneak` (category: Movement, setting `autosneak`) — Holds the sneak key while touching the ground.
- `AutoSprint` (category: Movement, setting `autosprint`) — Holds the aux1 key at all times.

## API

All exported on the global `autokey` table.

- `autokey.register_keypress_cheat(setting, desc, category, keyname, condition)` — Registers a new keypress cheat.
	- `setting` (string) — `core.settings` bool key that controls the cheat.
	- `desc` (string) — Display name for the cheat menu.
	- `category` (string) — Cheat menu category.
	- `keyname` (string) — Key to hold (e.g. `"sneak"`, `"aux1"`).
	- `condition` (function or nil) — Optional function returning a bool; the key is only held when this returns true.
	- Returns nothing. Internally registers a `core.register_cheat` and a globalstep that calls `core.set_keypress`.

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| AutoSneak | autosneak | Continuously holds the sneak key while touching the ground. |
| AutoSprint | autosprint | Continuously holds the aux1 key. |
]],
	["basic_moves"] = [[
# basic_moves

Flight automation, axis snapping, auto-forward-sprint, and POI-based transport methods.
Provides a multi-mode autopilot that navigates toward a selected POI or follows a player.

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| Autopilot | autopilot | Automatic flight with obstacle avoidance (6 modes) |
| AutoFsprint | autoforwardsprint | Holds `special1` key while `continuous_forward` is active |
| AxisSnap | axissnap | Snaps player yaw to nearest 90° cardinal direction |
| FlightHUD | flight_hud | HUD overlay with horizon, compass, target info, altitude/speed bars |

Autopilot settings (`autopilot.<key>` in the cheat settings panel):

- `autoengage` (bool, default true) — Automatically start autopilot when `continuous_forward` is enabled while a POI is selected. Set to false so other mods toggling forward movement never start a flight.
- `avoid_obstacles` (bool, default true) — Probe ahead along the actual flight path (not the quantized cardinal heading) and climb, descend, or sidestep around solid nodes.

**Autopilot modes** (configured in the cheat settings panel):

| Mode | Description |
|------|-------------|
| `3d_aim` | Direct line toward POI |
| `2d_aim` | Horizontal aim at POI Y-level, vertical movement manual |
| `3d_velocity` | Zero-gravity velocity toward POI |
| `nether` | Nether-ratio target (X/8, Z/8) for portal travel |
| `follow` | Follow the nearest player instead of a POI |
| `hover` | Maintain altitude above terrain while moving toward POI |

**POI transport methods** (appear in the POI context menu):

- `CTP` — Teleports player directly to the POI position.
- `STP` — Sends a `/teleport` chat command to the server.
- `Autopilot` — Starts autopilot toward the POI.

**FlightHUD target line**: when a POI is selected, the target HUD shows the
target's bearing relative to your nose (`⟵`/`⟶`/`↑` + degrees) and vertical
distance (`▲`/`▼` + meters). The speed readout additionally shows the
climb/descent rate. Autopilot notifies on arrival.

## API

All exported on the global `autofly` table.

- `autofly.tpos` (vector or nil) — Current target position for flight modes.
- `autofly.atpos` (vector or nil) — Actual POI position (may differ from `tpos` in 2d_aim).
- `autofly.follow_name` (string or nil) — Name of the player being followed.
- `autofly.warp(name)` → bool — Warp to a named waypoint. Returns `false` if the waypoint is in the void dimension.
]],
	["cchat"] = [[
# cchat

Logs received chat messages to the engine log at the `action` level. Each log line includes the server address, port, and the stripped message text.

## Player usage

No player-facing features. Operates entirely in the background.

## API

None.

## Cheats

None. Passive logging mod — no cheats registered.
]],
	["devtools"] = [[
# devtools

Development and debugging tools, including metadata inspection, node definition dumps, void-air pocket finding, auto-build scaffolding, and particle/sound leak detection.

## Player usage

**Cheats (DevTools category):**

- `ItemMeta` — Dumps the wielded item name and its metadata (`meta:to_table()`) to chat and log.
- `PointedMeta` — Dumps the metadata table of the node at the pointed position.
- `PosMeta` — Dumps the metadata table of the node at the player's current position.
- `PointedDef` — Dumps the node definition of the node at the pointed position.

**Cheats (other categories):**

- `FindVoidAir` (category: DevTools) — Scans a 60×52 area below the player (y: -180 to -128) for air nodes and marks the first pocket found with a waypoint.
- `NoWaterStop` (category: Bots) — Disables `continuous_forward` and itself when no water source is found within 50 nodes.
- `Pyramid` (category: Scaffold) — Builds a pyramid structure from red sandstone at a hardcoded position using reachable-position placement.

**Additional behavior:** Detects remote particle spawners (>256 nodes away) and far-away sounds, marking them as POI waypoints and logging a message.

## API

None.

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| FindVoidAir | fvair | Scans below player for void-air pockets and marks first with waypoint. |
| ItemMeta | (func) | Dumps wielded item name and metadata to chat and log. |
| PointedMeta | (func) | Dumps metadata table of node at pointed position. |
| PosMeta | (func) | Dumps metadata table of node at player's current position. |
| PointedDef | (func) | Dumps node definition of node at pointed position. |
| NoWaterStop | nowaterstop | Disables continuous_forward when no water found within range. |
]],
	["dig"] = [[
# dig

Dig timing library (merged from diglib + digcustom) and bulk digging operations (ported from scaffold). Provides accurate dig-time calculation, node-by-node digging, and a suite of automated excavation tools.

## Player usage

### Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| DigList | `diglist` | Dig all nodes from the selected nlist within range. Configure target nodes via nlist commands (`/nla`, `/nlapn`). |
| DigHead | `dighead` | Dig the node directly above the player's head. |
| Excavator | `excavator` | Tunnel excavation — digs a width×depth area in front of the player (horizontal slice at player eye level). Enables continuous forward movement. |
| TBM | `excavator` | Tunnel Boring Machine — same as Excavator, but also places tunnel-lining walls using the selected nodelist item (set via `/list select`). |
| TExcavator | `texcavator` | Full tunnel excavation (digs all nodes in the width×depth area including floor and ceiling). |
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
]],
	["dte"] = [[
# dte

Client-Side Mod Development & Testing Environment. An in-game Lua and formspec
editor. Write, save, and run Lua scripts without reloading the game. Scripts
run in a sandboxed environment where errors are caught and displayed in the UI
instead of crashing the game.

## Player usage

### Chat commands

| Command | Description |
|---------|-------------|
| `/dte` | Open the Lua IDE formspec |

### Cheats

| Cheat | Category | Description |
|-------|----------|-------------|
| Run DTE | DevTools | Run the currently loaded script in the editor |

### UI Tabs

- **LUA EDITOR** — code editor with Run, Clear, Save buttons. Output is
	displayed in a colored textlist below. Multiple named files can be switched
	via dropdown.
- **LUA CONSOLE** — placeholder (coming soon).
- **FILES** — manage Lua files: create, delete, open by double-click.
- **STARTUP** — choose files to run automatically when joining a world.
- **FUNCTIONS** — placeholder (coming soon).
- **HELP** — placeholder (coming soon).

## API

### Global

`dte` — namespace table.

`dte.modstorage` — mod storage object for persisting files and scripts.

`dte.modpath` — absolute path to the dte mod directory.

### Functions

`print(...)` — overrides the global `print`. Output is captured to the UI
output buffer instead of the console. Supports multi-line strings and multiple
arguments.

`safe(func)` — wraps a function in `pcall`. Errors are displayed in the UI
output buffer and logged. Returns the wrapped function. Use this when
registering minetest callbacks within an editor script to prevent crashes.

### Storage

Scripts and files are persisted in mod storage using key prefixes:

| Key | Description |
|-----|-------------|
| `_lua_temp` | Current unsalted file content |
| `_lua_file_<name>` | Named file content |
| `_lua_saved` | Currently selected file name |
| `_lua_startup` | Comma-separated startup file list |
| `_lua_files_list` | Comma-separated file name list |
| `_UI_files_list` | UI file list (formspec editor) |

### 3rd-party

The `3rdparty/Highlighter/` directory contains a syntax highlighter bundled
with the mod (used by the formspec editor).

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| Run DTE | (func) | Run the currently loaded script in the editor |
]],
	["farmtool"] = [[
# farmtool

Automated farming tools: harvest, till, sow, and repair farmland. Also provides a FarmBot that autonomously plants seeds on nearby soil.

## Player usage

### Cheats

| Cheat | Category | Setting | Description |
|-------|----------|---------|-------------|
| Reap | Place | `farmtool_reap` | Harvest mature crops and replant seeds in a radius around the player |
| Till | Place | `farmtool_till` | Till dirt blocks into soil within range using the configured hoe |
| Sow | Place | `farmtool_sow` | Plant the wielded seed on nearby soil blocks |
| FarmRepair | Place | `farmrepair` | Repair water channels and fill holes around water sources |

### Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `farmtool_reap.range` | 5 (or `ws.range`) | Crop search radius for Reap |
| `farmtool_till.range` | 5 | Till range |
| `farmtool_till.hoe_item` | `mcl_tools:hoe_diamond` | Hoe item to use for tilling |
| `farmtool_sow.range` | 5 (or `ws.range`) | Soil search radius for Sow |
| `farmrepair.range` | 5 | Water source search radius |
| `farmrepair.channel_range` | 5 | Channel repair radius around water |

### FarmBot

Registered via `sbots.register_bot("FarmBot", ...)`. When activated, it autonomously navigates to nearby soil and plants seeds.

## API

None.

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| Reap | `farmtool_reap` | Harvest mature crops and replant seeds in a radius around the player |
| Till | `farmtool_till` | Till dirt blocks into soil within range using the configured hoe |
| Sow | `farmtool_sow` | Plant the wielded seed on nearby soil blocks |
| FarmRepair | `farmrepair` | Repair water channels and fill holes around water sources |
| FarmBot | — | Autonomous bot that navigates to soil and plants seeds (registered via sbots) |
]],
	["findbiome"] = [[
# findbiome

Searches for a suitable biome position using a square spiral search grid. Given a starting position and a list of biome names, returns the closest matching spawn position within the world boundaries.

## Player usage

No chat commands or cheats.

## API

- `find_biome(pos, biomes)` — Searches outwards on a spiral grid (64-node resolution, 16384 checks) from `pos` for any biome named in the `biomes` array. Returns `spawn_pos, success` where `spawn_pos` is a `{x,y,z}` table with the y-coordinate adjusted via `core.get_spawn_level`, or `nil, false` if a biome name is invalid.

## Cheats

None. Library mod — no cheats registered.
]],
	["fishbot"] = [[
# fishbot

Automated fishing bot for MineClone (and similar). Uses a state machine to cast, wait for a bite, and reel in.

## Player usage

### Cheats

| Cheat | Category | Setting | Description |
|-------|----------|---------|-------------|
| FishBot | Bots | `fishbot` | Automated fishing — casts rod, waits for bobber movement, reels in |

### Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `fishbot.bobber_range` | 10 | Range to detect bobber entity |

### State machine

| State | Description |
|-------|-------------|
| 0 | Cast the fishing rod |
| 1 | Wait — monitor bobber position; if it stops moving, advance to state 2 |
| 2 | Bobber stationary — wait for movement (bite); reel in if bobber moves or if water beneath it disappears |
| 3 | Cooldown — wait until bobber is gone, then reset to state 0 |

FishBot auto-equips an enchanted fishing rod (falls back to normal) from the hotbar. Requires MineClone/IA game.

### Daughter mods

FishBot enables `autodump`, `autoeject`, and `lockview` when active.

## API

None.

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| FishBot | `fishbot` | Automated fishing — casts rod, waits for bobber movement, reels in |
]],
	["inv_open"] = [[
# inv_open

Inventory and crafting GUI tools (merged from open_inv + enderchest + punchinv). Provides a crafting grid formspec, an inventory list viewer for arbitrary player lists and nearby node inventories, and punch-to-open node inventories.

## Player usage

### Cheats

| Cheat | Category | Setting | Description |
|-------|----------|---------|-------------|
| OpenInvLists | Inventory | — | Open the inventory list browser formspec |
| OpenCraftGrid | Inventory | — | Open the portable crafting grid formspec |
| PunchInv | Inventory | `punchinv` | Open a node's inventory when punching it |

### Chat commands

| Command | Description |
|---------|-------------|
| `/craft` | Open a full 3×3 crafting grid formspec |
| `/openlist [listname]` | Open an inventory list browser for the named list (e.g. `main`, `craft`) |

### Settings

- `punchinv` — boolean, enable opening node inventories on punch (default: false)

## API

None.

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| OpenInvLists | — | Open the inventory list browser formspec |
| OpenCraftGrid | — | Open the portable crafting grid formspec |
| PunchInv | `punchinv` | Open a node's inventory when punching it |
]],
	["invutil"] = [[
# invutil

Inventory utility tools: auto-refill wielded item stacks, auto-eject unwanted items, dump a pointed container's inventory, and auto-craft blocks from full stacks.

## Player usage

### Cheats

| Cheat | Category | Setting | Description |
|-------|----------|---------|-------------|
| AutoRefill | Inventory | `autorefill` | Automatically refill the wielded item from other inventory stacks when it runs low |
| AutoEject | Inventory | `autoeject` | Automatically drop items whose names match the eject list |
| DumpFull | Inventory | — | Dump entire player inventory into the pointed container |
| AutoBlock | Inventory | `autoblock` | Auto-craft block items from full stacks of their constituent materials (e.g. diamond → diamond block) |

### Chat commands

| Command | Description |
|---------|-------------|
| `/list eject [items]` | Configure AutoEject item list (comma-separated item names) |

### Settings

- `autorefill` — boolean, enable auto-refill
- `autoeject` — boolean, enable auto-eject
- `eject_items` — comma-separated list of item names to auto-drop

## API

None.

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| AutoRefill | `autorefill` | Automatically refill the wielded item from other inventory stacks when it runs low |
| AutoEject | `autoeject` | Automatically drop items whose names match the eject list |
| DumpFull | — | Dump entire player inventory into the pointed container |
| AutoBlock | `autoblock` | Auto-craft block items from full stacks of their constituent materials |
]],
	["killaura"] = [[
# killaura

Auto-attack nearby entities with configurable targeting. Supports player enemies, all players (except friends), mobs, and combined modes. Includes friend/enemy list management via settings formspec.

## Player usage

### Cheats

| Cheat | Category | Setting | Description |
|-------|----------|---------|-------------|
| Killaura | Combat | `killaura` | Auto-punch nearby targets (configurable mode) |

### Targeting modes

| Mode | Description |
|------|-------------|
| `players_enemies` | Attack only players in enemy list (default) |
| `players_all` | Attack all players except friends |
| `mobs` | Attack hostile mobs (mesh-based detection) |
| `all` | Attack enemies + mobs |

### Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `killaura.hph` | 1 | Hits per hit (1–10) |
| `killaura.hit_y` | -0.1 | Vertical velocity offset on each hit |
| `killaura.range` | 10 | Attack range |
| `killaura.target_mode` | `players_enemies` | Targeting mode |

### Friend/enemy list

Open the Killaura cheat settings in the cheat menu to manage friend and enemy lists via formspec. Friends are never attacked in any mode. Enemies are always attacked in `players_enemies` and `all` modes.

## API

```lua
killaura = {
	hph = 1,
	hit_y = -0.1,
}
```

### `killaura.get(key)`

Get a killaura setting value by key, falling back to the default.

### `killaura.punch_object(obj)`

Punch an object multiple times (`hph` times) while preserving the player's original velocity and position.

**Parameters:**
- `obj` — `ObjectRef` to punch
]],
	["schembuilder"] = [[
# SchemBuilder

Schematic preview and placement tool. Loads MTS schematics as colored particle overlays in the world, and provides multiple ways to place the schematic nodes. Based on Gregon's Litematica (see README for credits).

## Player usage

- **Chat commands:**
	- `/schembuild <schematic>` — Load and display a schematic (`$` for schembuilder_output setting, or `file:<path>` for MTS files).
	- `/spos1` — Set region corner 1 at player position.
	- `/spos2` — Set region corner 2 at player position.
	- `/ssave` — Save nodes between pos1 and pos2 to `schembuilder_output` setting.
	- `/schemstop` — Stop the current build: clears the preview and disables AutoSchemPlace, SchemBuilderBot, RhythmBuildBot and SchematicLooter. The saved build stays in the Saved Builds tab.
	- `Stop Schematic Build` (in the `~` quick access palette, while a build is active) — same as `/schemstop`.
	- `Stop Build` / `Stop` buttons in the schematic browser (Browse / Saved Builds tabs) — same as `/schemstop`.
- **Cheats:**
	- `AutoSchemPlace` (Place category) — Place loaded schematic nodes within range using the strategy system.
	- `SchemBuilderBot` (Bots category) — Walks to the nearest unplaced schematic node and places it.
	- `RhythmBuildBot` (Bots category) — Builds schematics via rhythmtp teleportation.
	- `SchematicLooter` (Inventory category) — Loots building materials from nearby containers.
- **Settings:**
	- `schembuilder_output` — stores serialized schematic data.
	- `autoschemplace.*` — AutoSchemPlace settings (range, batch size, strategy).
	- `schembuilderbot.*` — SchemBuilderBot settings (cooldown, batch size).
	- `schematic_looter.*` — Looter settings (range, max per scan).

## Cheats

| Cheat | Category | Setting | Description |
|-------|----------|---------|-------------|
| AutoSchemPlace | Place | `autoschemplace` | Auto-place nodes within range via strategy |
| RhythmBuildBot | Bots | `schembuilderbot` | Build schematics via rhythmtp teleportation |
| SchemBuilderBot | Bots | `schembuilderbot` | Walk-to-and-place bot |
| SchematicLooter | Inventory | `schematic_looter` | Loot materials from nearby containers |
]],
	["lua_async"] = [[
# lua_async

Coroutine-based async library for client-side mods. Provides cooperative multithreading with yield-based scheduling, task queues, and time-sliced iteration to avoid blocking the game loop.

Also exposed as `async` (same table).

## Player usage

No chat commands or cheats.

## API

- `async` / `lua_async` — Global table exposing all functions below.
- `async.Async()` — Factory returning a new async instance. Instance fields:
	- `maxtime` (default 200 ms) — max wall-clock per slice before yielding.
	- `queue_threads` (default 8) — max concurrent queue workers.
	- `iterate(from, to, func, callback)` — Iterate `from..to`, calling `func(i)` per step. Yields after `maxtime`.
	- `foreach(_pairs, func, callback)` — Iterate a table via `_pairs`, calling `func(k, v)`.
	- `do_while(condition_func, func, callback)` — Loop while `condition_func()` is truthy.
	- `register_globalstep(func)` — Register a persistent globalstep callback running in a coroutine.
	- `chain_task(tasks, callback)` — Run an array of functions sequentially, passing the return of each to the next.
	- `queue_task(func, callback)` — Enqueue a function for worker-thread execution.
	- `single_task(func, callback)` — Run a function once (no queue).
- `async.yield()` — Yield the current coroutine, resuming next globalstep.
- `async.sleep(ms)` — Suspend the current coroutine for `ms` milliseconds.

## Cheats

None. Library mod — no cheats registered.
]],
	["mineclone"] = [[

None.
]],
	["autominer"] = [[
# AutoMiner

Automated mining bot. Finds the nearest target node (from `nlist.selected`), jump-teleports toward it using rhythmic teleport, digs the node before teleporting to its position (avoids noclip damage), and includes a lava panic system. Depends on `nlist` for node-type selection.

## Player usage

- **Cheat:** `AutoMiner` (category Bots, setting `autominer`)
- Automatically enables `autoeat` and `dighead` on start.
- **Settings:**
	- `autominer.lava_nodes` (string) — comma-separated lava/ hazard node names
	- `autominer.search_range` (int, default 50) — node search radius
	- `autominer.min_hp` (int, default 15) — minimum HP to operate
	- `autominer.lava_range` (int, default 10) — safe distance from lava

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| AutoMiner | `autominer` | Automated mining bot — finds nearest target node, jump-teleports avoiding lava, digs before teleporting, includes lava panic |

## API

None.
]],
	["nlist"] = [[
# nlist

Named, persistent node/item list manager. Provides a UI and chat commands to
create, edit, select, and persist named lists of itemstrings. Integrates with
other mods: lists can be imported into chat commands that expose a
`list_setting` field.

## Player usage

### Chat commands

| Command | Description |
|---------|-------------|
| `/nls <list>` | Select a list by name |
| `/nlshow` | Show current list content as HUD |
| `/nlhide` | Hide the list HUD |
| `/nla [item]` | Add item to selected list (or switch to add mode) |
| `/nlr [item]` | Remove item from selected list (or switch to remove mode) |
| `/nlc` | Clear all items from selected list |
| `/nlawi` | Add wielded itemstring to selected list |
| `/nlrwi` | Remove wielded itemstring from selected list |
| `/nlapn` | Add pointed node's itemstring to selected list |
| `/nlrpn` | Remove pointed node's itemstring from selected list |

### Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| NlEdMode | `nlist_edmode` | Shows list HUD; punching a node adds/removes it from the selected list |

NlEdMode provides a custom settings formspec with a textlist showing all
entries, dropdown to select lists, and buttons to create/delete lists or
add/remove entries.

### Integration with other mods

Chat commands that define `list_setting` on their registration are extended
with an `nls` argument. Running `.<command> nls` copies the currently selected
nlist into that command's setting. For example:

```
/xray nls   -- imports current nlist entries into xray's node list
```

## API

### Global

`nlist` — main namespace table.

`nlist.selected` — string, name of the currently selected list.

### Functions

`nlist.add(list, node)` — insert `node` into the named list (if not already present).

`nlist.remove(list, node)` — remove `node` from the named list.

`nlist.set(list, tb)` — replace list contents with `tb` (array of strings). If the list
name matches a `list_setting` on a registered chat command, the value is stored
as a minetest setting; otherwise it uses mod storage.

`nlist.get(list)` — return array of itemstrings for the named list, or `{}`.

`nlist.clear(list)` — empty the named list.

`nlist.delete(list)` — empty the named list (same as clear).

`nlist.select(list)` — set `nlist.selected` (and internal cursor).

`nlist.get_lists()` — return sorted array of all stored list names (from mod storage only).

`nlist.rename(oldname, newname)` — rename a list; returns `true` on success.

`nlist.copy(oldname, newname)` — copy list contents; backs up target if non-empty.

`nlist.random(list)` — return a random item from the list.

`nlist.show_list(list, hlp)` — display list content as HUD text (with optional help header).

`nlist.hide()` — remove the list HUD element.

`nlist.set_nled_hud(ttext)` — create or update the HUD text element displaying list info; returns `true`.
]],
	["place"] = [[
# place

Block placement and world-building cheats. Provides
automated scaffolding, wall building, fluid blocking, lantern placement,
highway construction, moss farming, and bot-driven sponge/water clearing.

## Player usage

### Chat commands

| Command | Description |
|---------|-------------|
| `/sc_pos1 [x,y,z]` | Set constraint position 1 (delegates to `/cpos1`) |
| `/sc_pos2 [x,y,z]` | Set constraint position 2 (delegates to `/cpos2`) |
| `/sc_reset` | Reset constraints (delegates to `/creset`) |

### Cheats

| Cheat | Setting | Category | Description |
|-------|---------|----------|-------------|
| PlaceOn | `placeon` | Place | Place blocks on top of exposed surfaces (use wielded item or configured node) |
| MultiScaff | `scaffold` | Place | Place blocks in a grid below player (configurable width/depth/above) |
| RandomScaff | `place_rnd` | Place | Replace blocks below with random items from `randomscaffold` nlist |
| BlockSources | `block_sources` | Place | Fill water and lava sources in radius |
| SpongeBot | `spongebot` | Bots | Autonomous sponge bot — finds and digs water sources |
| Autosponge | `autosponge` | Place | Place sponge at nearby water source |

### Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `place.width` | int | 5 | Width for MultiScaff |
| `place.depth` | int | 1 | Depth for MultiScaff |
| `place.above` | int | 0 | Above-ground offset for MultiScaff |
| `placeon.use_wielded` | bool | true | Use wielded item instead of configured node |
| `placeon.range` | int | 5 | Range for PlaceOn |
| `placeon.node` | string | `mcl_core:dirt_with_grass` | Node to place (when use_wielded is false) |
| `torchup.light_threshold` | int | 8 | Light level threshold |
| `torchup.node` | string | `mcl_torches:torch` | Node to place |

| `autosponge.range` | int | 10 | Sponge search range |
| `spongebot.search_range` | int | 50 | Water search range |
| `spongebot.travel_range` | int | 200 | Max travel distance |
| `slow_blocks_per_second` | int | 8 | Blocks placed per second |

]],
	["poi"] = [[
# poi

Persistent waypoint (POI) system. Stores named positions per-server, displays
HUD waypoints with distance/speed/ETA info, provides a formspec GUI for
management, and supports a transport callback system for teleportation mods.

## Player usage

### Chat commands

| Command | Aliases | Description |
|---------|---------|-------------|
| `/waypoints` | `/wp`, `/wps`, `/waypoint` | Open the waypoint GUI |
| `/add_waypoint <pos> <name>` | `/wa`, `/add_wp` | Add a waypoint at coordinates (e.g. `0,0,0 home`) |
| `/add_waypoint_here [name]` | `/wah`, `/add_wph` | Mark current position as waypoint (default: timestamp) |
| `/clear_waypoint` | `/cwp`, `/cls` | Hide the displayed waypoint HUD |
| `/wpdisplay <pos> <name>` | `/wpd` | Display a waypoint at arbitrary position |
| `/dump_pois` | — | Log all stored POI positions to debug |

### Quick menu

Every waypoint is exposed as an entry in the Quick Access Palette (`~`).
Activating one selects it in the waypoint GUI and shows its HUD marker.
With `Show All Waypoints` (or the `poi_show_all_waypoints` setting) enabled,
waypoints from all servers are listed, with the `server:port:` prefix shown
in the entry label.

### Displayed waypoints

- Displayed waypoints appear both as world-space HUD markers and as dots on
  the minimap (in the waypoint's group color), when the minimap is enabled.
- The waypoint list always shows the distance to each waypoint; the A-Z/Dist
  button still controls the sort order.
- The "Add Here" button adds a waypoint at your current position, with a
  suggested name from the node you're standing on.

### Cheats

| Cheat | Setting | Category | Description |
|-------|---------|----------|-------------|
| DeathTP | `death_tp` | Player | Auto-teleport to death location and collect bones |
| ShowNames | `poi_shownames` | Render | Show local player name and nearby player names on HUD |
| POIs | — | Misc | Open the waypoint formspec GUI |

### Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `death_tp` | bool | false | Auto-teleport to death location |
| `poi_screenshots` | bool | false | Capture a screenshot and store it with each new waypoint |

## API

### Global

`poi` — main namespace table.

`poi.registered_transports` — array of `{name, func}` transport registrations.

`poi.speed` — current player speed in nodes/second (updated once per second).

`poi.last_name` — name of last displayed waypoint.

`poi.last_pos` — position of last displayed waypoint.

`poi.etatime` — estimated time of arrival in minutes.

### Functions

`poi.check_vector(v)` — validate that `v` is a table with numeric x, y, z fields (no NaN). Returns `bool`.

`poi.getwps()` — return sorted array of waypoint names for the current server.

`poi.set_waypoint(pos, name)` — store a waypoint. `pos` can be a vector or string; returns `true`.

`poi.get_waypoint(name)` — return the position vector for a named waypoint, or `nil`.

`poi.delete_waypoint(name)` — remove a waypoint by name.

`poi.rename_waypoint(oldname, newname)` — rename a waypoint; returns `true` on success.

`poi.has_wp_near(pos)` — check if any waypoint exists within 256 nodes of `pos`.

`poi.get_quad()` — return cardinal quadrant string (e.g. `"North-east"`).

`poi.set_hud_wp(pos, title)` — display a HUD waypoint element pointing to `pos` with `title`.

`poi.set_hud_info(text)` — *removed, moved to FlightHUD*

`poi.display(pos, name)` — show a HUD waypoint at `pos` with label `name`.

`poi.display_waypoint(name)` — look up waypoint by name, aim at it, display HUD, show info panel.

`poi.select_waypoint(name)` — select the waypoint in the GUI and display it (aim + HUD marker). Returns `true` on success.

`poi.get_nearest_name()` — return the name of the closest waypoint within 500m, or the quadrant name.

`poi.register_transport(name, func)` — register a transport method for the formspec GUI. `func(pos, name)` is called when the button is pressed; return truthy to signal an error.

`poi.display_formspec()` — open the waypoint management formspec with textlist, display/rename/delete buttons, and registered transport buttons.
]],
	["rhythmtp"] = [[
# rhythmtp

Burst-teleport movement system. Teleports the player forward (or to a target position) in steps, respecting an anticheat pool budget. Toggle on for continuous auto-forward movement.

## Player usage

- **Cheat:** `RhythmTP` (category Movement, setting `rhythmtp`)
	- When toggled on, continuously teleports forward at the configured distance.
- **Chat commands:**
	- `/rhythmtp [dist]` — One-shot burst forward by `dist` meters (default 100). Use `stop` as argument to cancel active movement.
	- `/rhythmtp_to <x,y,z>` — Burst-teleport to specific coordinates.
- **Settings:**
	- `rhythmtp.budget` (number, 1–14, default 10) — pool budget in seconds
	- `rhythmtp.dist` (number, default 100) — forward teleport distance
	- `rhythmtp.h_speed` (number, default 4.0) — horizontal speed factor
	- `rhythmtp.vup_speed` (number, default 26.0) — vertical ascent speed
	- `rhythmtp.drain_factor` (number, 0.5–1, default 0.98) — cooldown drain per step

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| RhythmTP | `rhythmtp` | Burst-teleport movement — toggle on for continuous auto-forward teleportation in steps |

## API

None.
]],
	["sbots"] = [[
# sbots

Simple bot library. Provides a framework for creating autonomous bots that fly
to positions and perform actions. Includes one built-in bot (`listDigBot`) when
the `nlist` mod is present. Bots are activated/deactivated via the cheat menu.

No direct player-facing chat commands — bots are registered by other mods and
toggled through the cheat system.

## Player usage

### Cheats

| Cheat | Setting | Category | Description |
|-------|---------|----------|-------------|
| listDigBot | `listDigBot` | Bots | Finds and digs nodes from the currently selected nlist |

Additional bots registered by other mods (e.g. SpongeBot in the `place` mod)
appear under the Bots category.

### Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `listDigBot.allow_cobot` | bool | false | Allow running alongside other bots |

## API

### Global

`sbots` — main namespace table.

### Functions

`sbots.register_bot(name, def)` — register a new bot. The bot appears as a
cheat under the Bots category with setting name equal to `name`. If another bot
is already active and `allow_cobot` is false, activation is rejected.

### Bot definition

```lua
{
	-- Callbacks (all optional, defaults provided for each):

	find_pos = function(self, pos) end,
	-- Called in stage 0 to find a target position. Return a position vector
	-- or nil/false. pos is the player's current position. When nil is returned
	-- and stand_waiting is false, the bot deactivates itself.

	do_pos = function(self, pos) end,
	-- Called when the bot reaches its target (stage 2). Return true to signal
	-- completion and move to stage 0 (find next target).

	do_step = function(self, dtime) end,
	-- Called every globalstep while the bot is active, regardless of stage.

	update_pos = function(self, pos) return self:find_pos(self, pos) end,
	-- Called every globalstep when moving_target is true to update the
	-- target position mid-flight. Defaults to re-running find_pos.

	on_activate = function(self) end,
	-- Called when the bot is activated. Return true to abort activation.

	on_deactivate = function(self) end,
	-- Called when the bot is deactivated.

	-- Properties:

	landing_distance = 1,
	-- Distance from target at which the bot stops flying and enters stage 2.

	moving_target = false,
	-- Whether the target can move; enables update_pos every tick.

	stand_waiting = false,
	-- If true, the bot stays active even when find_pos returns nil.

	daughters = {},
	-- Sub-settings to toggle with this bot.

	delay = nil,
	-- Override the default hack delay.

	allow_cobot = false,
	-- Set to true in the def to allow concurrent bot operation.

	-- Internal (set at runtime):

	active = false,
	orig_pos = nil,
	target_pos = nil,
	stage = 0,
}
```

### Bot lifecycle

1. **Stage 0**: Calls `find_pos`. If a position is returned, sets `target_pos`
	and transitions to stage 1. If nil and `stand_waiting` is false, deactivates.
2. **Stage 1**: Aims at `target_pos` and enables forward movement. When within
	`landing_distance`, transitions to stage 2.
3. **Stage 2**: Disables forward movement, calls `do_pos`. If `do_pos` returns
	true, transitions back to stage 0.
4. Every tick: calls `do_step`. If `moving_target`, calls `update_pos`.

### Built-in: listDigBot

Registered if `nlist` is available. Finds the closest node from nlist's
selected list within 60m, flies to it, and digs all matching nodes within 1m.

## Cheats

None directly. Bot framework — bots are registered by other mods via sbots.register_bot().
]],
	["tps_client"] = [[
# tps_client

Displays server TPS and client ping in a HUD overlay. Communicates with the server-side `tps` mod via mod channels. Requires the server to have the companion mod installed (https://github.com/ClamityAnarchy/tps).

## Player usage

None — purely passive HUD display.

## API

- `tps_client` — Global table with fields:
	- `tps` — current server TPS (populated via mod channel)
	- `ping` — seconds since last TPS update (accumulated in globalstep, displayed as ms)

## Cheats

None. HUD utility — no cheats registered.
]],
	["wasplib"] = [[
# wasplib

Core utility library for Antilua client-side mods. Provides the `ws`
namespace with coordinate math, inventory manipulation, combat helpers, tool
optimization, world interaction (placement/digging), waypoint HUD, and a
global hack registration system (`ws.rg`). All other ANTILUA mods depend
on wasplib.

## Player usage

### Chat commands

| Command | Description |
|---------|-------------|
| `/giveme` | Give items from the currently selected nlist |
| `/givegear` | Give diamond armor/tools with enchants |
| `/tplace <pos>` | Teleport to position, place a node, teleport back |
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

`ws.dcm(msg)` — display chat message (`core.display_chat_message`).

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

`ws.ordercoord(c)` — normalize `{x,y,z}` or `{1,2,3}` to `{x=,y=,z=}`.

`ws.optcoord(x, y, z)` — flexible coord constructor (raw numbers or table).

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

`ws.icebreaker()` — dig all ice blocks within 4m radius.

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
| IceBreaker | icebreaker | Dig all ice blocks within 4m radius |
| AutoTool | autotool | Automatically switches to best tool on dig |
| HeadSaver | headsaver | Prevents suffocation in solid blocks |
| LavaAlarm | lavaalarm | Plays alarm bell when lava is detected nearby |
| mcl2-invul | mcl2-invul | Invulnerability via damage spam |
| LockView | lockview | Locks camera pitch/yaw to current angles |
]],
	["witherbot"] = [[
# witherbot

Combat automation for mcl worlds. Provides aura-style cheats for player evasion, selective kill-aura against mobs, and wither-skull dodge. Also registers bot definitions via `sbots` for automated mob/player/crystal/item farming.

## Player usage

- **Cheats:**
	- `SafeAura` (category Combat, setting `safeaura`) — Teleports away from nearby non-local players to a safe spot.
	- `SelKillaura` (category Combat, setting `selkillaura`) — Punches nearby objects matching the `obsbot` nlist within range.
	- `EvadeWither` (category Combat, setting `evade_wither`) — Dodges wither projectiles by teleporting to the farthest air node.
- **Registered bots** (via `sbots.register_bot`):
	- `ObsBot`, `PlBot` (player killer), `CrystalBot` (end crystal breaker), `MobsBot`, `HostileMobs`, `ItemBot` (item collector).

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| SafeAura | safeaura | Teleports away from nearby non-local players to a safe spot |
| SelKillaura | selkillaura | Punches nearby objects matching the obsbot nlist within range |
| EvadeWither | evade_wither | Dodges wither projectiles by teleporting to the farthest air node |
| ObsBot | (func) | Automated obsidian-breaking bot |
| PlBot | (func) | Automated player-killer bot |
| CrystalBot | (func) | Automated end crystal-breaking bot |
| MobsBot | (func) | Automated mob-farming bot |
| HostileMobs | (func) | Automated hostile mob-farming bot |
| ItemBot | (func) | Automated item-collecting bot |

## API

None (no direct global exports; all functionality is through the cheat menu and bot system).
]],
}
