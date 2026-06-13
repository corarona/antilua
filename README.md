Antilua
=======

A fork of Luanti (formerly Minetest) — a free
open-source voxel game engine — with client-side enhancements, cheat
features, and quality-of-life improvements.

**For the upstream Luanti README, see [LUANTI_README.md](LUANTI_README.md).**

---

## Build

### Dependencies

- C++17 compiler (GCC >= 7.5, Clang >= 7.0.1, MSVC >= 2017)
- CMake >= 3.16
- LuaJIT >= 2.1
- OpenGL / OpenGL ES
- zlib, zstd, libcurl, libpng, libjpeg, libsqlite3
- Freetype, GMP, JsonCPP

### Quick start (Linux, out-of-tree)

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DRUN_IN_PLACE=TRUE -DBUILD_SERVER=OFF
cmake --build build -j$(nproc)
```

The binary is placed at `bin/luanti`. Use `-j3` on 4-core machines.

> **Note:** Out-of-tree builds in `build/` only. In-tree artifacts break CMake.
> See `util/ci/build.sh` for CI build flags.

### Full build docs

See `doc/compiling/` for platform-specific guides (Linux, Windows, macOS).

---

## What's different from Luanti

Antilua adds features directly in the C++ engine layer — no mods or
games required. All are toggleable via the **Cheat Menu** (default key: `TAB`)
or by setting their corresponding settings.

### Movement

| Feature | Setting | Description |
|---------|---------|-------------|
| Freecam | `freecam` | Detached camera — fly through the world while the player stays |
| Freelook | `freelook` | Mouse-look without holding a button |
| AirJump | `airjump` | Jump in mid-air |
| Spider | `spider` | Climb any walkable wall |
| JetPack | `jetpack` | Fly upward with the jump key |
| Jesus | `jesus` | Walk on water/lava |
| NoSlow | `no_slow` | No speed reduction in cobwebs etc. |
| AntiSlip | `antislip` | Don't slip on ice |

### Combat

| Feature | Setting | Description |
|---------|---------|-------------|
| AntiKnockback | `antiknockback` | No knockback from attacks |
| AttachmentFloat | `float_above_parent` | Float above boats/minecarts |
| AutoHit | `autohit` | Auto-attack nearby entities |
| Killaura | `killaura` | Attack all entities in range (special cheat, see Key Bindings) |
| Scaffold | `scaffold` | Auto-place blocks beneath your feet (special cheat, see Key Bindings) |

### Render

| Feature | Setting | Description |
|---------|---------|-------------|
| X-Ray | `xray` | See through terrain; only specified nodes are visible |
| Fullbright | `fullbright` | Maximum light at all times |
| NoHurtCam | `no_hurt_cam` | Disable damage red flash |
| CheatHUD | `cheat_hud` | Overlay showing which cheats are active |
| HUDBypass | `hud_flags_bypass` | Override server HUD flags |
| Entity Hitboxes | `enable_entity_esp` | Wireframe boxes around entities through walls |
| Entity Tracers | `enable_entity_tracers` | Lines from camera to each entity |
| Entity Wallhack | `enable_entity_wallhack` | Entity meshes rendered through walls |
| Player Hitboxes | `enable_player_esp` | Wireframe boxes around other players through walls |
| Player Tracers | `enable_player_tracers` | Lines from camera to each player |
| Player Wallhack | `enable_player_wallhack` | Player meshes rendered through walls |
| NodeESP | `enable_node_esp` | Highlighted node bounding boxes |
| NodeTracers | `enable_node_tracers` | Lines from camera to specified nodes |

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

### Cheat Layer Panel System

Pressing **TAB** opens the cheat layer — a dark overlay with mouse-accessible
panels. The main panel lists all cheat categories. Click a category to open a
detachable child panel with individual cheat toggles. Panels can be:

- **Dragged** by their title bar
- **Pinned** (toggle via the `[P]` button) — stays visible even after closing the layer
- **Focused for keyboard** (toggle via the `[K]` button) — arrow keys control that panel
- **Closed** via the `[X]` button (child/settings panels only)
- **Reset** to default position via the `[R]` button

Cheats show `[x] Name` when enabled, `[ ] Name` when disabled. Click to toggle.
A `>` suffix indicates the cheat has additional settings (right-arrow or click
to open a settings formspec with sliders, dropdowns, and fields).

### Key Bindings

| Key | Action |
|-----|--------|
| TAB | Cheat Layer (dark overlay with panels) |
| G | Toggle Freecam |
| X | Toggle Killaura |
| Y | Toggle Scaffold |
| H | Open Ender Chest |
| Arrow keys | Navigate keyboard-focused panel |
| F | Confirm/toggle selected cheat |

**Killaura** (`X`) automatically attacks all reachable hostile entities within
range. Configure range via the killaura settings panel (arrow into `killaura`
in the cheat menu). **Scaffold** (`Y`) places a block under your feet each step
— useful for bridging. Both are special cheats with dedicated key toggles.

### Lua API (client-side modding)

Antilua extends the client-side Lua API with callbacks, object
refs, inventory actions, and a virtual mod filesystem. See
`doc/al_csm_api.md` for the full reference.

---

## Debugging and Automation

### Client Lua Pipe

An optional named pipe (FIFO) for sending Lua code to the client
and receiving results. Controlled by the `pipe_lua_enable` setting
(default: `false`).

**Protocol:** Write a single JSON line to the pipe at `pipe_lua_path`
(default `/tmp/antilua_lua`):

```json
{"code":"return core.localplayer:get_pos()", "file":"/tmp/resp"}
```

The response is written to the file specified in `file` (or
`/tmp/antilua_lua_response` if omitted):

```
ok
{x=100, y=20, z=-30}
```

On error, the first line is `error` followed by the error message.

Usage examples:
```sh
# One-off expression
echo '{"code":"return 1+1","file":"/tmp/resp"}' > /tmp/antilua_lua
cat /tmp/resp
# ok
# 2
```

### Session Detach / Reattach

The client can **detach** (hide its window and run headlessly, keeping
the network connection and Lua state alive) and later **reattach** from
the terminal — analogous to `tmux`/`screen` for the game.

- **Detach:** Press the "Detach" button in the pause menu, or call
  `core.detach()` from Lua. The game loop continues (physics, network,
  Lua) but rendering is suspended.
- **Reattach:** Run `antilua --attach` from the terminal. Requires
  `pipe_lua_enable = true` — the reattach command is sent via the
  Lua pipe. The window reappears and rendering resumes.
- **Start fresh:** Run `antilua --forcenew` to bypass the session
  check and start a new instance even if a detached session exists.

---

## Integration Tests

```sh
# Full test suite (requires xvfb-run for headless display)
./util/ci/run_al_tests.sh

# Client Lua Pipe test (named pipe IPC)
./util/ci/test_pipe_lua.sh
```

370+ tests pass (0 failures, 0 skipped).

---

## Version

Antilua is based on Luanti 5.17.0-dev.
See `LUANTI_README.md` for upstream documentation, compiling,
configuration, and Docker instructions.

## License

Same as upstream Luanti — LGPLv2.1+ for the engine,
CC0 / CC BY-SA 3.0 / MIT for assets. See `LICENSE.txt`.
