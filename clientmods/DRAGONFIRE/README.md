# DRAGONFIRE — Antilua Client-Side Modpack

Client-side cheat/utility mods for Antilua.

## Directory structure

All mods are individual directories under this folder, loaded via `clientmods/mods.conf`.

## Mod index

### Core libraries

| Mod | Description |
|-----|-------------|
| **wasplib** | Foundation library (`ws.*` namespace). Provides the global hack template system (`ws.rg`), coordinate math, inventory ops, world interaction (place/dig), tool selection, combat helpers, HUD waypoints, constraint system. Also includes: HeadSaver, LockView, LavaAlarm, AutoTool, mcl2-invul. |
| **nlist** | Persistent named node/item list management. Used by many other mods for target selection. |
| **poi** | Points-of-Interest waypoint system. Persistent per-server, HUD display, transport registration API. |
| **sbots** | Bot framework with 3-stage lifecycle (find → navigate → execute). Other mods register bots via `sbots.register_bot()`. |
| **lua_async** | Async/await coroutine framework. Provides `async.yield()`, `async.sleep()`, `async.Async()` factory. |

### Movement

| Mod | Description |
|-----|-------------|
| **autokey** | Auto-hold keys: AutoSneak, AutoSprint. Also exports `autokey.register_keypress_cheat()`. |
| **basic_moves** | Flight modes (3D, 2D, velocity-based, nether-roof), Flight HUD, AxisSnap. |
| **rhythmtp** | Burst-teleport using anticheat pool credits. `/rhythmtp [dist]`, `/rhythmtp_to`. |

### Inventory / Crafting

| Mod | Description |
|-----|-------------|
| **autocraft** | Automatic crafting system. Custom GUI, recipe memory, auto-craft loop. |
| **autoeat** | Auto-eat food when hunger drops. Settings for threshold and cooldown. |
| **inv_open** | Inventory GUI: `/craft` for crafting grid, `/openlist` for inventory lists, punch-to-open-node-inventory. |
| **invutil** | AutoRefill, AutoEject, DumpFull, AutoBlock. |
| **invsaver** | Save inventory to ender chest on low HP, restore on respawn. |

### Combat

| Mod | Description |
|-----|-------------|
| **autoevade** | Auto-teleport away from projectiles (arrows, potions, shulker bullets). |
| **killaura** | Killaura, Mobaura, ForceField, AirHead. Nlist-based targeting. |
| **witherbot** | Boss combat bots (ObsBot, PlBot, CrystalBot, etc.), SafeAura, SelKillaura, EvadeWither. |

### World building / Digging

| Mod | Description |
|-----|-------------|
| **dig** | Dig timing library + auto-dig + bulk dig operations. Excavator, TBM, Nuke, Digcyl, DigFreeSponge. |
| **place** | Block placement cheats: MultiScaff, PlaceOn, Highway, BlockWater/BlockLava, WallIn, SkyPltfrm, PCeiling, SpongeBot, AutoCombatLog. |

### Farming / Bots

| Mod | Description |
|-----|-------------|
| **farmtool** | Reap, Till, Sow, FarmRepair. FarmBot via sbots. |
| **fishbot** | Automatic fishing bot with state machine. |
| **autominer** | Automated mining bot. Teleports to target nodes, digs, avoids lava. |

### Developer / World tools

| Mod | Description |
|-----|-------------|
| **devtools** | Item/pointed/node metadata dumpers, void air finder, no-water-stop, particle/sound leak detector. |
| **dte** | In-game Lua IDE with tabbed formspec editor, file management, startup scripts. |
| **schembuilder** | Schematic builder: load/preview via particles, place via PlaceLiteM/SchemBuilderBot, auto-loot materials. `/schembuild`, `/spos1`, `/spos2`, `/ssave`. |
| **findbiome** | Spiral-search biome finder. Exports `find_biome(pos, biomes)`. |
| **mcl_find_strongholds** | Stronghold position predictor using seed-based ring algorithm. `/find_strongholds [seed]`. |

### Other

| Mod | Description |
|-----|-------------|
| **cchat** | Chat message logger to engine log. |
| **tps_client** | Server TPS and ping HUD display. Exports `tps_client.tps`, `tps_client.ping`. |

## Cheat categories

The cheat menu (default: TAB) groups cheats into:

| Category | Description |
|----------|-------------|
| Movement | Fly, sprint, teleport |
| Place | Block placement, liquid blocking, scaffold, walls |
| Dig | Excavators, nuke, cylinder dig, auto-dig |
| Combat | Kill aura, evade, force field |
| Bots | Fishing, sponge, wither, mining bots |
| Inventory | Auto-craft, auto-eat, auto-refill, dump, tool switching |
| Player | AutoEat, HeadSaver, LavaAlarm, AutoSneak, etc. |
| Misc | POIs, nList editor |
| DevTools | Item/pointed/node metadata, debug tools |
| Render | Xray, fullbright, ESP, tracers |

## Compatibility

These mods are designed for Antilua. They rely on Antilua-specific CSM APIs. They will **not** load in stock Luanti.
