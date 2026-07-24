# ANTILUA — Antilua Client-Side Modpack

Client-side cheat/utility mods for Antilua.

## Directory structure

All mods are individual directories under this folder, loaded via `clientmods/mods.conf`.

## Mod index

### Core libraries

| Mod | Description |
|-----|-------------|
| **wasplib** | Foundation library (`ws.*` namespace). Provides the global hack template system (`ws.rg`), coordinate math, inventory ops, world interaction (place/dig), tool selection, combat helpers, HUD waypoints, constraint system. Also includes: HeadSaver, LockView, LavaAlarm, AutoTool, mcl2-invul. |
| **al_formspec** | Formspec builder library. String builder with `:add()`, `:get()`, widget helpers, `begin()` template. |
| **nlist** | Persistent named node/item list management. Used by many other mods for target selection. |
| **poi** | Points-of-Interest waypoint system. Persistent per-server, HUD display, transport registration API. |
| **sbots** | Bot framework with 3-stage lifecycle (find -> navigate -> execute). Other mods register bots via `sbots.register_bot()`. |
| **lua_async** | Async/await coroutine framework. Provides `async.yield()`, `async.sleep()`, `async.Async()` factory. |

### Movement

| Mod | Description |
|-----|-------------|
| **basic_moves** | Flight modes (3D, 2D, velocity-based, nether-roof), Flight HUD, AxisSnap, AutoForwardSprint, AutoSneak. |
| **rhythmtp** | Burst-teleport using anticheat pool credits. `.rhythmtp [dist]`, `.rhythmtp_to`. |

### Inventory / Crafting

| Mod | Description |
|-----|-------------|
| **inventory** | Unified inventory mod: AutoRefill, AutoEject, DumpFull, AutoSort, AutoBlock. `.craft`, `.openlist` commands. Punch-to-open-node-inventory. |
| **autocraft** | Automatic crafting system. Custom GUI, recipe memory, auto-craft loop. `.autocraft`, `.autocraft_list`, `.autocraft_clear`. |
| **autoeat** | Auto-eat food when hunger drops. Settings for threshold and cooldown. |
| **inspectors** | Inventory and node metadata change sniffers: InvLogger, InvSnapshot, NodeMetaSniffer. |

### Combat

| Mod | Description |
|-----|-------------|
| **combat** | Killaura (with target mode: players/mobs/all, nlist-based friends), PatrolGuard bot, AutoCombatLog. Retaliation tracking. |

### World building / Digging

| Mod | Description |
|-----|-------------|
| **dig** | Dig timing library + auto-dig + bulk dig operations. DigCustom, Excavator, Nuke, Digcyl (sponge dig), IceBreaker. |
| **place** | Block placement cheats: MultiScaff, PlaceOn, BlockWater/BlockLava, SpongeBot. |

### Farming / Bots

| Mod | Description |
|-----|-------------|
| **farmtool** | Reap, Till, Sow, FarmRepair. FarmBot via sbots. |
| **fishbot** | Automatic fishing bot with state machine (MineClone/ItemAdef only). |
| **autominer** | Automated mining bot. Teleports to target nodes, digs, avoids lava. |

### Developer / World tools

| Mod | Description |
|-----|-------------|
| **devtools** | Item/pointed/node metadata dumpers, particle/sound leak detector. |
| **dte** | In-game Lua IDE with tabbed formspec editor, file management, startup scripts. `.dte` to open, `.dte_load <file>` to run external files. |
| **schembuilder** | Schematic builder: load/preview via particles, place via PlaceLiteM/SchemBuilderBot, auto-loot materials. `.schembuild`, `.spos1`, `.spos2`, `.ssave`. |
| **findbiome** | Spiral-search biome finder. Exports `find_biome(pos, biomes)`. |
| **mapart** | PNG to MTS schematic converter for pixel art. `.mapart <file> [w] [h]`. |
| **blockexchange** | BlockExchange server client for downloading schematics. `.bx_login`, `.bx_search`, `.bx_download`. |

### HUD / Display

| Mod | Description |
|-----|-------------|
| **always_day** | Lock time-of-day to a fixed value. |
| **hud** | HUD control: block server HUD adds and notify on HUD changes. |

| **tps_client** | Server TPS and ping HUD display. Exports `tps_client.tps`, `tps_client.ping`. |

### Logging / Events

| Mod | Description |
|-----|-------------|
| **session_logger** | Chat alerts, name colorizer, join/leave toasts, session stats. `.stats` command. |
| **chat_logger** | Persistent per-server chat file logger. |
| **event_logger** | Entity/node/block event logger. BlockLogger logs digs/places with nlist-based ignore. |
| **particle_hooks** | Particle blocker + saver for filtering server particles. |

### Other

| Mod | Description |
|-----|-------------|
| **help** | README viewer, keybind reference. `.help` command. |

## Cheat categories

The cheat menu (default: TAB) groups cheats into:

| Category | Description |
|----------|-------------|
| Movement | Fly, sprint, teleport |
| Place | Block placement, liquid blocking, scaffold, walls |
| Dig | Excavators, nuke, cylinder dig, auto-dig |
| Combat | Kill aura, patrol guard |
| Bots | Fishing, sponge, mining, farm bots |
| Inventory | Auto-craft, auto-eat, auto-refill, dump, tool switching |
| Player | AutoEat, HeadSaver, LavaAlarm, AutoSneak, etc. |
| Misc | POIs, nList editor |
| DevTools | Item/pointed/node metadata, debug tools |
| Render | Xray, fullbright, ESP, tracers |

## Compatibility

These mods are designed for Antilua. They rely on Antilua-specific CSM APIs. They will **not** load in stock Luanti.
