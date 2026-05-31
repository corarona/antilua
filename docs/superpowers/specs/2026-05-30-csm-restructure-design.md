# DragonfireClient CSM Restructure

**Date:** 2026-05-30
**Status:** Approved

## Goals

- Reduce mod count from 38 to ~29 by merging overlapping functionality
- Remove dead/experimental code
- Rename inconsistently-named mods
- Establish shared APIs in `wasplib`
- Convert all cheats to new-style `ws.rg()` table registration
- Clean up `devtools` grab-bag

## Deletions

| Mod | Reason |
|-----|--------|
| `enderchest` | Replaced by merged `inv_open` (it and open_inv both registered `/craft`) |
| `punchinv` | Replaced by merged `inv_open` |
| `antitower` | `place` (scaffold) MultiScaff already covers this |
| `walls` | Merged into `place` |
| `nametags` | Standalone render mod, nothing depends on it |
| `gregon_litematica` | Renamed to `litematica` (old directory deleted) |
| `scaffold/railscaffold.lua` | 512-line file with RailBot (server-specific) and WorldTP (exploit). Deleted. |

## Merges

### wasplib — gains shared APIs + small mods

**Constraint system** (moved from scaffold):
```lua
ws.constraint_pos1 = false
ws.constraint_pos2 = false
ws.set_pos1(pos)   →  /cpos1 [pos]
ws.set_pos2(pos)   →  /cpos2 [pos]
ws.reset_constraints()  →  /creset
ws.inside_constraints(pos) → bool
```

**Common scaffold helpers** (moved from scaffold, consolidated):
- `ws.place_if_needed(items, pos, place)` — place item if not already present
- `ws.place_if_able(pos)` — place if possible
- `ws.dig_if_able(pos)` — dig if inside constraints
- `ws.get_nodes_per_tick()` — returns `nodes_per_tick` setting with default 8

**UI helpers** (moved from enderchest/openinv/punchinv — was duplicated in all three):
- `ws.get_slot(inv, filter)` — find first matching slot in an inventory list
- `ws.get_itemslot_bg_v4(x, y, w, h, ...)` — styled slot background for formspecs

**Consolidated tool selection** (was duplicated in autotool + wasplib/tools.lua):
- `ws.find_best_tool(nodename)` — single implementation

**Merged small mods:**
- `headsaver` → `ws.enable_headsaving()` / `ws.disable_headsaving()` + `headsaver` setting
- `lavaalarm` → lava detection built into wasplib globalstep + `mcl2-invul` cheat registration stays in wasplib
- `lockview` → `ws.lock_view(pitch, yaw)` / `ws.unlock_view()` + `lockview` setting

### dig — new mod (digging library + auto-dig + digging cheats)

Created from:
- `diglib` → core library, renamed to `dig`
- `digcustom` → thin auto-dig wrapper, merged in
- Dig operations from `place` (scaffold): Excavator, TBM, TExcavator, WallExcavator, Nuke, DigHead, Digcyl, DigFreeSponge

```
dig/
├── mod.conf
├── init.lua          (dig_calculate_dig_time, dig_get_dig_time, dig_dig_node — from diglib)
├── autocustom.lua    (DigCustom cheat — from digcustom)
├── tunnel.lua        (Excavator, TBM, TExcavator, WallExcavator, DigHead)
├── blast.lua         (Nuke)
└── sponge.lua        (DigFreeSponge, Digcyl — from scaffold/spongebot.lua)
```

All dig cheats use the constraint system from wasplib and `ws.get_nodes_per_tick()`.

### inv_open — new mod (merged from open_inv + enderchest + punchinv)

```
inv_open/
├── mod.conf
├── init.lua          (/craft, /openlist, punch-to-open-node-inventory)
```

Unifies the three inventory GUI mods into one. Uses `ws.get_slot()` and `ws.get_itemslot_bg_v4()` from wasplib.

### place — renamed from scaffold, merged with walls

Renamed `scaffold` directory to `place`. Removed `railscaffold.lua`, moved dig operations to `dig`, added `walls/` as subfile.

```
place/
├── mod.conf
├── init.lua          (constraint system — now in wasplib; template system; place/build cheats)
├── blocks.lua        (BlockWater, BlockLava, BlockSources, BlockLavaSources, PlaceOnTop)
├── build.lua         (Highway, HighwayZ, LanternTBM, MultiScaff, MScaffModulo, PlaceOn)
├── walls.lua         (WallIn, SkyPltfrm, PCeiling — from old walls mod)
├── spongebot.lua     (SpongeBot, Autosponge — DigFreeSponge + Digcyl moved to dig)
├── bot_tools.lua     (AutoCombatLog)
└── greenup.lua       (PlaceOn, TorchUp)
```

### litematica — renamed from gregon_litematica

Simple rename of the directory and `mod.conf`.

## Cleanups

### devtools

| Cheat | Action |
|-------|--------|
| FindVoidAir | Keep |
| ItemMeta | Keep |
| PointedMeta | Keep |
| PosMeta | Keep |
| PointedDef | Keep |
| MclProgFood | **Remove** (server-specific exploit) |
| SortToWorld | **Remove** (niche, experimental) |
| EInvTaker | **Remove** (entity inventory theft exploit) |
| NoWaterStop | Keep |
| AutoMoss | **Move to `place`** |
| Pyramid | **Remove** (experimental) |

Also strip commented-out code blocks and dead experiments.

### API Conversion

All cheats using old-style positional `ws.rg()` must be converted to table-based new-style:

```lua
-- OLD (positional)
ws.rg('Name', 'Category', 'setting', func)

-- NEW (table)
ws.rg('Name', {
    category = 'Category',
    setting = 'setting',
    on_step = func,
    on_start = func,
    on_stop = func,
    cheat_settings = { ... },
    daughters = { ... },
    delay = 0.2,
})
```

Affected registrations: ~20 across remaining mods.

## mods.conf Changes

### Remove
```
load_mod_diglib
load_mod_digcustom
load_mod_scaffold
load_mod_walls
load_mod_open_inv
load_mod_enderchest
load_mod_punchinv
load_mod_antitower
load_mod_nametags
load_mod_gregon_litematica
```

### Add
```
load_mod_dig = true
load_mod_place = true
load_mod_inv_open = true
load_mod_litematica = true
```

## Implementation Order

| Step | Description | Files changed |
|------|-------------|---------------|
| 1 | Create `dig` mod: copy diglib → dig, merge digcustom, pull dig cheats from scaffold | ~7 new files |
| 2 | Create `inv_open` mod: merge open_inv + enderchest + punchinv | ~1 new file |
| 3 | Add constraint system + helpers to wasplib; merge headsaver, lavaalarm, lockview | wasplib/ + subfiles |
| 4 | Rename `scaffold` → `place`: remove railscaffold.lua, remove dig cheats, add walls, add automoss | directory rename + file edits |
| 5 | Clean `devtools`: remove experimental cheats, move AutoMoss to place | devtools/init.lua + place/ |
| 6 | Rename `gregon_litematica` → `litematica` | directory rename + mod.conf |
| 7 | Delete removed mod directories | 7 directories |
| 8 | Convert old-style ws.rg() to new-style | ~20 registrations across all mods |
| 9 | Update mods.conf | Remove 10 entries, add 4 |
| 10 | Run integration tests | `./util/ci/run_df_tests.sh` |

## Remaining Questions

1. `dig` chat commands: `/dig_pos1`, `/dig_pos2`, `/dig_reset`? Or use wasplib's generic `/cpos1`, `/cpos2`, `/creset` everywhere?
2. `find_best_tool` — autotool has its own version and wasplib/tools.lua has one. They might differ. Should `ws.find_best_tool()` call autotool's version if available, or vice versa?
3. "nodes_per_tick" is an awfully generic setting name for something that affects block operations across both `dig` and `place`. Rename to `ws_nodes_per_tick` or keep as-is?

## Risk Assessment

- **Test coverage**: 150 integration tests exist. If they pass after the restructure, the core APIs are intact.
- **Old mod compatibility**: Nothing external depends on these mods. They're all internal to the DragonfireClient modpack.
- **Naming conflicts**: No external mods reference `scaffold.*` or `enderchest.*` globals. The `ws` global is the only shared namespace.
- **Rollback**: Each step is independent. If `dig` works but `place` has issues, the old scaffold directory still exists until step 7.
