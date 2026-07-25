Antilua
=======

A fork of Luanti (formerly Minetest) — a free open-source voxel game engine
with client-side enhancements, cheat features, and quality-of-life improvements.

**For the upstream Luanti README, see [LUANTI_README.md](LUANTI_README.md).**

---

## Build

### Dependencies

- C++17 compiler (GCC >= 7.5, Clang >= 7.0.1)
- CMake >= 3.16, LuaJIT >= 2.1, zlib, zstd, libcurl, libpng, libjpeg, libsqlite3
- Freetype, GMP, JsonCpp, OpenGL / OpenGL ES

### Quick start (Linux, out-of-tree)

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Release -DRUN_IN_PLACE=TRUE -DBUILD_SERVER=OFF
cmake --build build -j$(nproc)
```

Binaries are placed at `bin/antilua` (client) and `bin/antiluaserver` (server).
Use `-j3` on 4-core machines.

> **Note:** Out-of-tree builds in `build/` only. See `util/ci/build.sh` for CI flags.

### Full build docs

See `doc/compiling/` for platform-specific guides (Linux, Windows, macOS).

---

## What's different from Luanti

All features are toggleable via the **Cheat Menu** (default key: `TAB`) or by
setting their corresponding settings.

### Movement

| Feature | Setting | Description |
|---------|---------|-------------|
| Freecam | `freecam` | Detached camera — fly through world while player stays |
| Freelook | `freelook` | Mouse-look without holding a button |
| Camera Roll | `keymap_camera_roll_{left,right}` | Roll camera around look axis (Q/E, configurable speed/max/auto-reset) |
| Pitch Wraparound | `pitch_wraparound` | Allow pitch past ±90° for loopings |
| AirJump | `airjump` | Jump in mid-air |
| Spider | `spider` | Climb any walkable wall |
| JetPack | `jetpack` | Fly upward with the jump key |
| Jesus | `jesus` | Walk on water/lava |
| NoSlow | `no_slow` | No speed reduction in cobwebs etc. |
| AntiSlip | `antislip` | Don't slip on ice |
| EntitySpeed | `entity_speed` | Speed up rideable entities |

### Combat

| Feature | Setting | Description |
|---------|---------|-------------|
| AntiKnockback | `antiknockback` | No knockback from attacks |
| AttachmentFloat | `float_above_parent` | Float above boats/minecarts |
| AutoHit | `autohit` | Auto-attack nearby entities |
| Killaura | `killaura` | Attack all entities in range |
| PatrolGuard | `patrolguard` | Bot that patrols and engages targets |
| Scaffold | `scaffold` | Auto-place blocks beneath your feet |

### Render

| Feature | Setting | Description |
|---------|---------|-------------|
| X-Ray | `xray` | See through terrain; only specified nodes visible |
| Fullbright | `fullbright` | Maximum light at all times |
| NoHurtCam | `no_hurt_cam` | Disable damage red flash |
| CheatHUD | `cheat_hud` | Overlay showing which cheats are active |
| HUDBypass | `hud_flags_bypass` | Override server HUD flags |
| Entity ESP | `enable_entity_esp` | Wireframe boxes around entities through walls |
| Entity Wallhack | `enable_entity_wallhack` | Entity meshes rendered through walls |
| Entity Tracers | `enable_entity_tracers` | Lines from camera to each entity |
| Player ESP | `enable_player_esp` | Wireframe boxes around other players |
| Player Wallhack | `enable_player_wallhack` | Player meshes through walls |
| Player Tracers | `enable_player_tracers` | Lines from camera to each player |
| NodeESP | `enable_node_esp` | Highlighted node bounding boxes |
| NodeTracers | `enable_node_tracers` | Lines from camera to specified nodes |
| Task Nodes | `enable_task_nodes` | Persistent colored wireframe boxes for path visualization |
| Task Tracers | `enable_task_tracers` | Persistent colored tracer lines |

### Interact

| Feature | Setting | Description |
|---------|---------|-------------|
| Fast Dig | `fastdig` | Faster node breaking |
| Fast Place | `fastplace` | Faster block placement |
| Auto Dig | `autodig` | Auto-dig the nearest node |
| Auto Place | `autoplace` | Auto-place blocks |
| Instant Break | `instant_break` | One-click node breaking |
| FastHit | `spamclick` | High-speed auto-clicking |

### Player

| Feature | Setting | Description |
|---------|---------|-------------|
| NoFallDamage | `prevent_natural_damage` | Negate fall/fire/lava damage |
| NoForceRotate | `no_force_rotate` | Prevent server-forced rotation |
| Reach | `reach` | Longer interaction range |
| AutoRespawn | `autorespawn` | Auto-respawn on death |
| PointAll | `point_all` | Point any node except air |
| ThroughWalls | `dont_point_nodes` | Don't auto-select any node |
| PrivBypass | `priv_bypass` | Bypass fly/fast/noclip privilege checks |
| AutoReconnect | `auto_reconnect` | Auto-reconnect on disconnect |

### Utility (Lua API)

| API | Description |
|-----|-------------|
| `core.draw3d:*` | Render spheres, boxes, wireboxes, lines, circles in world space |
| `core.encode_png(w, h, data)` | Encode RGBA pixel data to PNG via libpng |
| `core.send_raw_packet` | Send arbitrary MTP packets to the server |
| `core.register_on_{receiving,sending}_raw_packet` | Intercept/modify/drop packets in transit |
| `core.TOCLIENT` / `core.TOSERVER` | Opcode constant tables for raw packet API |
| `core.find_path` | A\* pathfinding on client-side node map |
| `core.{add,clear}_task_node` / `core.{add,clear}_task_tracer` | Persistent path/task markers |
| `core.ipc_{get,set,cas,poll}` | Inter-mod shared key-value store with compare-and-swap |
| `core.read_schematic` / `core.serialize_schematic` | Client-side MTS schematic deserialization/serialization |
| `core.override_item` | Modify item definitions client-side |
| `core.sound_play` | Play sounds via OpenAL (returns handle with `:stop()` / `:fade()`) |
| `core.camera:add_nametag` / `core.camera:remove_nametag` / `core.camera:clear_nametags` | World-space nametags |
| `core.ui.minimap:{add,remove,clear}_marker` | Colored dots on the minimap surface |
| `core.sky:*` | Sun/moon/star/fog/cloud visibility and parameters |
| `core.clouds:*` | Cloud density, height, thickness, speed, color |
| `core.localplayer:get_{collisionbox,eye_offset,standing_node,gravity,autojump}` | Physics extras |

---

## Cheat System

Pressing **TAB** opens a dark overlay with movable, pinnable panels. The main
panel lists all cheat categories. Click a category to open a detachable child
panel with individual cheat toggles. Panels can be dragged, pinned, focused
for keyboard navigation, closed, or reset to default position.

Cheats show `[x]` when enabled, `[ ]` when disabled. A `>` suffix indicates
the cheat has additional settings (click to open a settings formspec).

### Key Bindings

| Key | Action |
|-----|--------|
| TAB | Cheat Layer |
| G | Toggle Freecam |
| X | Toggle Killaura |
| Y | Toggle Scaffold |
| H | Open Ender Chest |
| Q / E | Roll camera left/right |
| Arrow keys | Navigate keyboard-focused panel |
| F | Confirm/toggle selected cheat |

---

## Client Lua API

Antilua extends the client-side Lua API with callbacks, object refs, inventory
actions, and a virtual mod filesystem. See `doc/al_csm_api.md` for the full
reference.

Over 35 callback hooks are available — intercept packets, formspecs, sounds,
particles, HUD elements, inventory actions, physics overrides, and more.

---

## Client Modding

The `clientmods/ANTILUA/` directory contains ~40 mods providing automated
farming, combat bots, schematic building, waypoints, formspec editors, and
more. See `doc/al_csm_api.md` and `FEATURES.md` for details.

---

## Settings

Antilua-specific settings with their type definitions live in
`builtin/settingtypes_al.txt`. Key settings include the cheat toggles listed
above, camera roll parameters (`camera_roll_speed`, `camera_roll_max`, etc.),
theme colors for the cheat menu, and the Lua pipe toggle
(`pipe_lua_enable`).

---

## Debugging and Automation

### Client Lua Pipe

An optional named pipe (FIFO) for sending Lua expressions to the client and
receiving results. Enable `pipe_lua_enable = true` in settings. Write JSON
lines to the pipe at `pipe_lua_path` (default `/tmp/antilua_lua`). See
`src/client/pipe_lua.cpp` and `doc/al_csm_api.md` for protocol details.

### Session Detach / Reattach

The client can detach (hide window, keep connection/Lua state alive) and
reattach from the terminal — analogous to `tmux` for the game. Use the
"Detach" button in the pause menu (or `core.detach()` from Lua), then
reconnect with `antilua --attach`. Pass `--forcenew` to bypass a running
session. Requires `pipe_lua_enable = true` for reattach.

---

## Integration Tests

```sh
# Full test suite (requires xvfb-run for headless display)
./util/ci/run_al_tests.sh

# Client Lua Pipe test
./util/ci/test_pipe_lua.sh
```

---

## Contributing

PRs are accepted but only if they were written entirely by an AI. I have seen
what you call "code." I have read your pull requests. I know what lurks in the
hearts of `git push`. You will not learn anything by writing another `for` loop
at 2 AM. Feed a prompt to something that doesn't need sleep or caffeine, review
its output with the appropriate level of disdain, and let it deal with merge
conflicts. Your carbon-based brain is better suited for staring out a window
wondering if `O(n²)` truly matters when n is never more than 12.

Just kidding — all contributions are welcome. That said, PRs will be judged
according to architecture and isolation from Luanti upstream code, not just
by functionality.

---

## Version

Antilua is based on Luanti 5.17.0-dev.
See `LUANTI_README.md` for upstream documentation, compiling, configuration,
and Docker instructions.

## License

Same as upstream Luanti — LGPLv2.1+ for the engine,
CC0 / CC BY-SA 3.0 / MIT for assets. See `LICENSE.txt`.
