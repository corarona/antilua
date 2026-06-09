# Antilua — Additional Features vs Vanilla Luanti

Antilua extends Luanti with client-side enhancements, cheat features,
and quality-of-life improvements. This file documents what has been ported to
the `df-rebased` branch and what is still in progress.

## Legend

| Mark | Meaning |
|------|---------|
| ✅ | Ported and working |
| 🔄 | Setting exists, implementation pending |
| ❌ | Not yet ported (see `DF_MISSING.md`) |

## Client Cheats

All cheats are toggled via the Cheat Menu (default key: `TAB`) or by direct key
bindings. Cheats that require server privileges (fly, noclip, fast) still check
them unless `priv_bypass` is active.

### Combat
| Feature | Setting | Status |
|---------|---------|--------|
| AntiKnockback | `antiknockback` | 🔄 |
| AttachmentFloat | `float_above_parent` | 🔄 |

### Movement
| Feature | Setting | Status |
|---------|---------|--------|
| Freecam | `freecam` | ✅ |
| AutoForward | `continuous_forward` | ✅ |
| PitchMove | `pitch_move` | ✅ |
| AutoJump | `autojump` | ✅ |
| Jesus | `jesus` | 🔄 |
| NoSlow | `no_slow` | ✅ |
| JetPack | `jetpack` | ✅ |
| AntiSlip | `antislip` | ✅ |
| AirJump | `airjump` | ✅ |
| Spider | `spider` | ✅ |

### Render / Visual
| Feature | Setting | Status |
|---------|---------|--------|
| Xray | `xray` | ✅ |
| Fullbright | `fullbright` | ✅ |
| HUDBypass | `hud_flags_bypass` | 🔄 |
| NoHurtCam | `no_hurt_cam` | 🔄 |
| BrightNight | `no_night` | 🔄 |
| Coords | `coords` | 🔄 |
| CheatHUD | `cheat_hud` | ✅ |
| EntityHitboxes | `enable_entity_esp` | ✅ |
| EntityWallhack | `enable_entity_wallhack` | ✅ |
| EntityTracers | `enable_entity_tracers` | ✅ |
| PlayerHitboxes | `enable_player_esp` | ✅ |
| PlayerWallhack | `enable_player_wallhack` | ✅ |
| PlayerTracers | `enable_player_tracers` | ✅ |
| NodeESP | `enable_node_esp` | 🔄 |
| NodeTracers | `enable_node_tracers` | 🔄 |

### Interact
| Feature | Setting | Status |
|---------|---------|--------|
| FastDig | `fastdig` | 🔄 |
| FastPlace | `fastplace` | 🔄 |
| AutoDig | `autodig` | 🔄 |
| AutoPlace | `autoplace` | 🔄 |
| InstantBreak | `instant_break` | 🔄 |
| FastHit | `spamclick` | 🔄 |
| AutoHit | `autohit` | 🔄 |

### Exploit
| Feature | Setting | Status |
|---------|---------|--------|
| EntitySpeed | `entity_speed` | ✅ |

### Player
| Feature | Setting | Status |
|---------|---------|--------|
| NoFallDamage | `prevent_natural_damage` | 🔄 |
| NoForceRotate | `no_force_rotate` | 🔄 |
| Reach | `reach` | 🔄 |
| PointLiquids | `point_liquids` | 🔄 |
| PrivBypass | `priv_bypass` | ✅ |
| AutoRespawn | `autorespawn` | 🔄 |
| ThroughWalls | `dont_point_nodes` | 🔄 |

## Key Bindings (Antilua-specific)

| Key | Action | Status |
|-----|--------|--------|
| TAB | Cheat Menu | ✅ |
| G | Toggle Freecam | ✅ |
| X | Toggle Killaura | ✅ |
| Y | Toggle Scaffold | ✅ |
| H | Open Ender Chest | ✅ |

## C++ Engine Features (Antilua-specific)

| Feature | Description | Status |
|---------|-------------|--------|
| `priv_bypass` | Bypasses all privilege checks (fly, noclip, fast, etc.) | ✅ |
| ModApiClient additions | Extended Lua API for client-side modding | ✅ |
| Client-side mod loading | Loads mods from `clientmods/` and `mods/` | ✅ |
| CheatMenu GUI | In-game cheat toggle menu (TAB) | ✅ |
| Freecam | Detached camera mode — fly through world while player stays | ✅ |
| Xray | Mesh-level hiding of non-xray nodes | ✅ |
| Fullbright | Maximum light level at all times | ✅ |
| ESP/Tracers | Entity & player bounding boxes and tracer lines | ✅ |
| Client-side mod VFS | Virtual filesystem for loading mods from memory | ✅ |
| Key rebinding dialog | In-game GUI for rebinding keys | ✅ |

## DRAGONFIRE Modpack (client-side mods)

All Dragonfire client mods are consolidated into the `DRAGONFIRE` modpack
at `old-clientmods/DRAGONFIRE/`. Core mods:

| Mod | Description | Status |
|-----|-------------|--------|
| `wasplib` | Central utility library (`ws.*`) — settings, coords, inventory, world interaction, combat, waypoints | ✅ |
| `lockview` | Lock camera yaw/pitch for building | ✅ |
| `headsaver` | Auto-dig block at head level | ✅ |
| `invsaver` | Auto-transfer to ender chest on low HP/death | ✅ |
| `antitower` | Tower scaffold building | ✅ |
| `walls` | Wall/ceiling/platform builder | ✅ |
| `autoevade` | Dodge projectiles automatically | ✅ |

See `doc/df_csm_api.md` for the full Antilua-specific CSM API reference,
and `PLAN.md` for the modpack restructuring plan.

## Lua API Additions

See `src/script/lua_api/` and `clientmods/df_test/` for the full list of
client-side Lua API additions ported from Dragonfire. Also see `doc/df_csm_api.md`
for the complete reference.

## Test Coverage

Integration tests live in `clientmods/df_test/`. Run with:
```
./util/ci/run_df_tests.sh
```
