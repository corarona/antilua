# DragonfireClient — Additional Features vs Vanilla Luanti

DragonfireClient extends Luanti with client-side enhancements, cheat features,
and quality-of-life improvements. This file documents what has been ported to
the `df-rebased` branch and what is still in progress.

## Legend

| Mark | Meaning |
|------|---------|
| ✅ | Ported and working |
| 🔄 | In progress |
| ❌ | Not yet ported (see `DF_MISSING.md`) |

## Client Cheats (builtin/client/cheats.lua)

All cheats are toggled via the Cheat Menu (default key: `F9`) or by direct key
bindings. Cheats that require server privileges (fly, noclip, fast) still check
them unless `priv_bypass` is active.

### Combat
| Feature | Setting | Status |
|---------|---------|--------|
| AntiKnockback | `antiknockback` | ❌ |
| AttachmentFloat | `float_above_parent` | ❌ |

### Movement
| Feature | Setting | Status |
|---------|---------|--------|
| Freecam | `freecam` | 🔄 |
| AutoForward | `continuous_forward` | ✅ (vanilla toggle) |
| PitchMove | `pitch_move` | ✅ (vanilla toggle) |
| AutoJump | `autojump` | ✅ (vanilla toggle) |
| Jesus | `jesus` | ❌ |
| NoSlow | `no_slow` | ❌ |
| JetPack | `jetpack` | ❌ |
| AntiSlip | `antislip` | ❌ |
| AirJump | `airjump` | ❌ |
| Spider | `spider` | ❌ |

### Render / Visual
| Feature | Setting | Status |
|---------|---------|--------|
| Xray | `xray` | ❌ |
| Fullbright | `fullbright` | ❌ |
| HUDBypass | `hud_flags_bypass` | ❌ |
| NoHurtCam | `no_hurt_cam` | ❌ |
| BrightNight | `no_night` | ❌ |
| Coords | `coords` | ❌ |
| CheatHUD | `cheat_hud` | ❌ |
| EntityESP | `enable_entity_esp` | ❌ |
| EntityTracers | `enable_entity_tracers` | ❌ |
| PlayerESP | `enable_player_esp` | ❌ |
| PlayerTracers | `enable_player_tracers` | ❌ |
| NodeESP | `enable_node_esp` | ❌ |
| NodeTracers | `enable_node_tracers` | ❌ |

### Interact
| Feature | Setting | Status |
|---------|---------|--------|
| FastDig | `fastdig` | ❌ |
| FastPlace | `fastplace` | ❌ |
| AutoDig | `autodig` | ❌ |
| AutoPlace | `autoplace` | ❌ |
| InstantBreak | `instant_break` | ❌ |
| FastHit | `spamclick` | ❌ |
| AutoHit | `autohit` | ❌ |

### Exploit
| Feature | Setting | Status |
|---------|---------|--------|
| EntitySpeed | `entity_speed` | ❌ |

### Player
| Feature | Setting | Status |
|---------|---------|--------|
| NoFallDamage | `prevent_natural_damage` | ❌ |
| NoForceRotate | `no_force_rotate` | ❌ |
| Reach | `reach` | ❌ |
| PointLiquids | `point_liquids` | ❌ |
| PrivBypass | `priv_bypass` | ✅ |
| AutoRespawn | `autorespawn` | ❌ |
| ThroughWalls | `dont_point_nodes` | ❌ |

## Key Bindings (DF-specific)

| Key | Action | Status |
|-----|--------|--------|
| G | Toggle Freecam | 🔄 |
| R (double-tap) | Toggle Killaura | ✅ |
| T | Toggle Scaffold | ✅ |
| F9 | Cheat Menu | ✅ |

## C++ Engine Features (DF-specific)

| Feature | Description | Status |
|---------|-------------|--------|
| `priv_bypass` | Bypasses all privilege checks (fly, noclip, fast, etc.) | ✅ |
| `checkPrivilege()` override | Freecam also bypasses priv checks | 🔄 |
| ModApiClient additions | Extended Lua API for client-side modding | ✅ |
| Client-side mod loading | Loads mods from `clientmods/` and `mods/` | ✅ |
| CheatMenu GUI | In-game cheat toggle menu (F9) | ✅ |
| Freecam | Detached camera mode — fly through world while player stays | 🔄 |
| Killaura | Auto-attack nearby entities | ✅ |
| Scaffold | Auto-place blocks beneath player | ✅ |

## Lua API Additions

See `src/script/lua_api/` and `clientmods/df_test/` for the full list of
client-side Lua API additions ported from DF.

## Test Coverage

Integration tests live in `clientmods/df_test/`. Run with:
```
./util/ci/run_df_tests.sh
```
