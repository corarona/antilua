# Antilua — Additional Features vs Vanilla Luanti

Antilua extends Luanti with client-side enhancements, cheat features,
and quality-of-life improvements.

## Legend

| Mark | Meaning |
|------|---------|
| ✅ | Ported and working |
| ❌ | Not yet ported (see `DF_MISSING.md`) |

## Client Cheats

All cheats are toggled via the Cheat Menu (default key: `TAB`) or by direct key
bindings. Cheats that require server privileges (fly, noclip, fast) still check
them unless `priv_bypass` is active.

### Movement
| Feature | Setting | Status |
|---------|---------|--------|
| Freecam | `freecam` | ✅ |
| Freelook | `freelook` | ✅ |
| Camera Roll | `camera_roll_speed`, `camera_roll_max`, `keymap_camera_roll_{left,right}` | ✅ |
| Pitch Wraparound | `pitch_wraparound` | ✅ |
| AirJump | `airjump` | ✅ |
| Spider | `spider` | ✅ |
| JetPack | `jetpack` | ✅ |
| Jesus | `jesus` | ✅ |
| NoSlow | `no_slow` | ✅ |
| AntiSlip | `antislip` | ✅ |
| AutoForward | `continuous_forward` | ✅ |
| PitchMove | `pitch_move` | ✅ |
| AutoJump | `autojump` | ✅ |
| EntitySpeed | `entity_speed` | ✅ |

### Combat
| Feature | Setting | Status |
|---------|---------|--------|
| AntiKnockback | `antiknockback` | ✅ |
| AttachmentFloat | `float_above_parent` | ✅ |
| AutoHit | `autohit` | ✅ |
| Killaura | `killaura` | ✅ |
| PatrolGuard | `patrolguard` | ✅ |
| Scaffold | `scaffold` | ✅ |

### Render / Visual
| Feature | Setting | Status |
|---------|---------|--------|
| Xray | `xray` | ✅ |
| Fullbright | `fullbright` | ✅ |
| NoHurtCam | `no_hurt_cam` | ✅ |
| CheatHUD | `cheat_hud` | ✅ |
| HUDBypass | `hud_flags_bypass` | ✅ |
| Entity ESP | `enable_entity_esp` | ✅ |
| Entity Wallhack | `enable_entity_wallhack` | ✅ |
| Entity Tracers | `enable_entity_tracers` | ✅ |
| Player ESP | `enable_player_esp` | ✅ |
| Player Wallhack | `enable_player_wallhack` | ✅ |
| Player Tracers | `enable_player_tracers` | ✅ |
| NodeESP | `enable_node_esp` | ✅ |
| NodeTracers | `enable_node_tracers` | ✅ |

### Interact
| Feature | Setting | Status |
|---------|---------|--------|
| FastDig | `fastdig` | ✅ |
| FastPlace | `fastplace` | ✅ |
| AutoDig | `autodig` | ✅ |
| AutoPlace | `autoplace` | ✅ |
| InstantBreak | `instant_break` | ✅ |
| FastHit | `spamclick` | ✅ |

### Player
| Feature | Setting | Status |
|---------|---------|--------|
| NoFallDamage | `prevent_natural_damage` | ✅ |
| NoForceRotate | `no_force_rotate` | ✅ |
| Reach | `reach` | ✅ |
| PointAll | `point_all` | ✅ |
| PrivBypass | `priv_bypass` | ✅ |
| AutoRespawn | `autorespawn` | ✅ |
| ThroughWalls | `dont_point_nodes` | ✅ |
| AutoReconnect | `auto_reconnect` | ✅ |

### Utility (Lua API, not cheat toggles)
| Feature | Description | Status |
|---------|-------------|--------|
| Draw3D | `core.draw3d:*` — render spheres/boxes/lines/circles in world space | ✅ |
| Raw Packets | `core.send_raw_packet` + intercept callbacks + `core.TOCLIENT`/`core.TOSERVER` | ✅ |
| PNG Encoding | `core.encode_png(w, h, data)` — encode RGBA to PNG via libpng | ✅ |
| Schematic API | `core.read_schematic` / `core.serialize_schematic` (client-side MTS) | ✅ |
| IPC | `core.ipc_{get,set,cas,poll}` — inter-mod key-value store | ✅ |
| Sound | `core.sound_play()` — OpenAL with `:stop()` / `:fade()` handles | ✅ |
| Sky / Clouds | `core.sky:*` / `core.clouds:*` — sun, moon, stars, fog, cloud parameters | ✅ |
| Minimap Markers | `core.ui.minimap:add/remove/clear_marker` | ✅ |
| Camera Nametags | `core.camera:add/remove_nametag` / `core.camera:clear_nametags` | ✅ |
| Pathfinding | `core.find_path()` — A\* on client-side node map | ✅ |
| Task Markers | `core.{add,clear}_task_node` / `core.{add,clear}_task_tracer` | ✅ |

## Key Bindings (Antilua-specific)

| Key | Action | Status |
|-----|--------|--------|
| TAB | Cheat Menu | ✅ |
| G | Toggle Freecam | ✅ |
| X | Toggle Killaura | ✅ |
| Y | Toggle Scaffold | ✅ |
| H | Open Ender Chest | ✅ |
| Q / E | Roll camera left / right | ✅ |
| Arrow keys | Navigate keyboard-focused panel | ✅ |
| F | Confirm / toggle selected cheat | ✅ |

## C++ Engine Features (Antilua-specific)

| Feature | Description | Status |
|---------|-------------|--------|
| `priv_bypass` | Bypasses all privilege checks (fly, noclip, fast, etc.) | ✅ |
| ModApiClient additions | Extended Lua API for client-side modding | ✅ |
| Client-side mod loading | Loads mods from `clientmods/` and `mods/` | ✅ |
| CheatMenu GUI | In-game cheat toggle menu (TAB) with movable/pinnable panels | ✅ |
| Freecam | Detached camera mode — fly through world while player stays | ✅ |
| Camera Roll | Q/E camera roll around look axis (configurable speed, max, auto-reset) | ✅ |
| Pitch Wraparound | Allow pitch past ±90° for loopings | ✅ |
| Xray | Mesh-level hiding of non-xray nodes | ✅ |
| Fullbright | Maximum light level at all times | ✅ |
| ESP / Tracers | Entity & player bounding boxes, tracer lines, wallhack mode | ✅ |
| Draw3D pipeline | Custom render pipeline for Lua-driven 3D shapes | ✅ |
| Session Detach / Reattach | Detach window, run headlessly, reattach from terminal | ✅ |
| Client Lua Pipe | Named pipe (FIFO) for Lua IPC | ✅ |
| Client-side mod VFS | Virtual filesystem for loading mods from memory | ✅ |
| Key rebinding dialog | In-game GUI for rebinding keys | ✅ |

## ANTILUA Modpack (client-side mods)

All Antilua client mods are consolidated into the `ANTILUA` modpack
at `clientmods/ANTILUA/`. ~40 mods providing automated farming, combat
bots, schematic building, waypoints, formspec editors, and more.

| Mod | Description | Status |
|-----|-------------|--------|
| `wasplib` | Central utility library (`ws.*`) | ✅ |
| `autocraft` | Automated crafting GUI | ✅ |
| `autoeat` | Auto-eat food when hungry | ✅ |
| `autominer` | Mining bot with lava avoidance | ✅ |
| `basic_moves` | Flight automation, axis snapping | ✅ |
| `combat` | Killaura, AutoEvade, AutoCombatLog | ✅ |
| `devtools` | Metadata inspection, node def dumps | ✅ |
| `dig` | Dig timing + bulk excavation | ✅ |
| `dte` | In-game Lua/formspec editor | ✅ |
| `farmtool` | Automated farming + FarmBot | ✅ |
| `fishbot` | Automated fishing state machine | ✅ |
| `help` | Centralized help system | ✅ |
| `invsaver` | Auto-transfer to ender chest | ✅ |
| `lockview` | Lock camera yaw/pitch | ✅ |
| `headsaver` | Auto-dig block at head level | ✅ |
| `nlist` | Named persistent node/item list | ✅ |
| `place` | Scaffold, wall/ceiling/platform builders | ✅ |
| `poi` | Persistent waypoints with HUD | ✅ |
| `rhythmtp` | Burst-teleport movement system | ✅ |
| `sbots` | Simple bot framework | ✅ |
| `schembuilder` | MTS schematic preview + placement | ✅ |
| `tps_client` | Server TPS / ping HUD overlay | ✅ |

See `doc/al_csm_api.md` for the full Antilua-specific CSM API reference,
and `PLAN.md` for the modpack restructuring plan.

## Lua API Additions

New client-side Lua API modules (all in `src/script/lua_api/`):

| Module | Description |
|--------|-------------|
| `l_sky.h/cpp` | `core.sky:*` — sun/moon/star/fog/cloud parameters |
| `l_clouds.h/cpp` | `core.clouds:*` — cloud density, height, speed, color |
| `l_minimap.h/cpp` | `core.ui.minimap:*` — markers, show/hide, mode/shape |
| `l_draw3d.h/cpp` | `core.draw3d:*` — spheres, boxes, lines, circles |
| `l_camera.h/cpp` | `core.camera:*` — nametags, camera mode, FOV |
| `l_localplayer.h/cpp` | Extended localplayer methods (collisionbox, standing_node, gravity, autojump, roll) |
| `l_client_sound.h/cpp` | `core.sound_play()` with handle objects |
| `l_inventoryaction.h/cpp` | `InventoryAction` userdata (move, craft) |
| `l_clientobject.h/cpp` | ClientObjectRef (entity manipulation) |
| `al_client_map.h/cpp` | Client map querying |
| `l_ipc.h/cpp` | Inter-mod communication |
| `l_particles_local.h/cpp` | Client-side particle system |

Full reference: `doc/al_csm_api.md`.

## Test Coverage

Integration tests live in `clientmods/al_test/`. Run with:
```
./util/ci/run_al_tests.sh
```
