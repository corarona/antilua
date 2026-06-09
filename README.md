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

### Movement Cheats

| Feature | Setting | Description |
|---------|---------|-------------|
| Freecam | `freecam` | Detached camera — fly through the world while the player stays |
| AutoJump | `autojump` | Automatically hop over obstacles |
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

### Visual / Render

| Feature | Setting | Description |
|---------|---------|-------------|
| X-Ray | `xray` | See through terrain; only specified nodes are visible |
| Fullbright | `fullbright` | Maximum light at all times |
| Entity Hitboxes | `enable_entity_esp` | Wireframe boxes around entities through walls |
| Entity Tracers | `enable_entity_tracers` | Lines from camera to each entity |
| Player Hitboxes | `enable_player_esp` | Wireframe boxes around other players through walls |
| Player Tracers | `enable_player_tracers` | Lines from camera to each player |
| Entity Wallhack | `enable_entity_wallhack` | Entity meshes rendered through walls (occluded only) |
| Player Wallhack | `enable_player_wallhack` | Player meshes rendered through walls (occluded only) |
| Cheat HUD | `cheat_hud` | Overlay showing which cheats are active |
| Coordinates | `coords` | In-world position display |
| Bright Night | `no_night` | Always daytime |
| No Hurt Cam | `no_hurt_cam` | Disable damage red flash |

### Interact

| Feature | Setting | Description |
|---------|---------|-------------|
| Fast Dig | `fastdig` | Faster node breaking |
| Fast Place | `fastplace` | Faster block placement |
| Auto Dig | `autodig` | Auto-dig the nearest node |
| Auto Place | `autoplace` | Auto-place blocks |
| Instant Break | `instant_break` | One-click node breaking |
| Fast Hit | `spamclick` | High-speed auto-clicking |
| Auto Hit | `autohit` | Auto-attack nearby entities |

### Exploit

| Feature | Setting | Description |
|---------|---------|-------------|
| Entity Speed | `entity_speed` | Entities move at full player speed |
| Priv Bypass | `priv_bypass` | Bypass fly/fast/noclip privilege checks |

### Player

| Feature | Setting | Description |
|---------|---------|-------------|
| No Fall Damage | `prevent_natural_damage` | Negate fall/fire/lava damage |
| No Force Rotate | `no_force_rotate` | Prevent server-forced rotation |
| Extended Reach | `reach` | Longer interaction range |
| Auto Respawn | `autorespawn` | Auto-respawn on death |
| Point Liquids | `point_liquids` | Target/select liquid nodes |
| Through Walls | `dont_point_nodes` | Don't auto-select any node |

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
A `>` suffix indicates the cheat has additional settings (right-arrow or click to open).

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

### Lua API (client-side modding)

Antilua extends the client-side Lua API with callbacks, object
refs, inventory actions, and a virtual mod filesystem. See
`doc/df_csm_api.md` for the full reference.

---

## Integration Tests

```sh
# Requires xvfb-run (from the xvfb package) for headless display
./util/ci/run_df_tests.sh
```

All 145+ integration tests pass (0 failures, 0 skipped).

---

## Version

Antilua is based on Luanti 5.17.0-dev.
See `LUANTI_README.md` for upstream documentation, compiling,
configuration, and Docker instructions.

## License

Same as upstream Luanti — LGPLv2.1+ for the engine,
CC0 / CC BY-SA 3.0 / MIT for assets. See `LICENSE.txt`.
