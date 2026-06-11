# DRAGONFIRE Modpack: Clean & Polish Plan

## Goal
Restructure all old-clientmods into a single `DRAGONFIRE` modpack, split wasplib
into subfiles, extract useful features from emicor into focused mods, and add
integration tests.

## Modpack Structure

```
old-clientmods/DRAGONFIRE/
├── modpack.conf
├── wasplib/              # Restructured: init.lua + subfiles
├── nlist/                # Kept as-is (minor polish)
├── sbots/                # Kept as-is (minor polish)
├── lua_async/            # Kept as-is
├── poi/                  # Kept as-is (minor polish)
├── tps_client/           # Kept as-is
├── cchat/                # Kept as-is (minor polish)
├── killaura/             # Kept as-is (minor polish)
├── autoeat/              # Kept as-is (minor polish)
├── autotool/             # Kept as-is
├── autokey/              # Kept as-is
├── enderchest/           # Kept as-is (minor polish)
├── open_inv/             # Kept as-is (minor polish)
├── nametags/             # Kept as-is (minor polish)
├── invutil/              # Kept as-is (minor polish)
├── incrementaltp/        # Kept as-is (minor polish)
├── farmtool/             # Kept as-is (minor polish)
├── findbiome/            # Kept as-is
├── basic_moves/          # Kept as-is (minor polish)
├── lavaalarm/            # Kept as-is
├── punchinv/             # Kept as-is
├── diglib/               # digtool merged into this
├── devtools/             # Kept as-is (minor polish)
├── digcustom/            # Kept as-is
├── fishbot/              # Kept as-is
├── witherbot/            # Kept as-is
├── autominer/            # Kept as-is
├── mcl_find_stronholds/  # Kept as-is (fix typo in name)
├── gregon_litematica/    # Kept as-is (compatibility review)
├── scaffold/             # API compatibility review
├── dte/                  # API compatibility review
├── lockview/             # NEW: extracted from emicor
├── headsaver/            # NEW: extracted from emicor
├── invsaver/             # NEW: extracted from emicor
├── antitower/            # NEW: extracted from emicor
├── walls/                # NEW: extracted from emicor (wallin+skypltfrm+pceiling)
├── autoevade/            # NEW: extracted from emicor
```

## Dropped Mods

| Mod | Reason |
|-----|--------|
| blockmaker | Syntax error, broken |
| teamchat | Niche, few users |
| autodupe | Potentially abusive exploit |
| digtool | Stub — merge into diglib |
| nodebot | Minimal (~80 lines), better as sbots example |
| emicor | After extraction of useful features |

## Phases

### Phase 0: Modpack setup
- Create `DRAGONFIRE/` directory and `modpack.conf`
- Move all kept mods into it
- Remove dropped mods

### Phase 1: wasplib restructure
Split into subfiles loaded via `dofile` from `init.lua`:

| File | Contents |
|------|----------|
| `init.lua` | Namespace setup, `mod.conf`, `dofile` calls, `on_connect` |
| `settings.lua` | `ws.s`, `ws.sb`, `ws.dcm`, `ws.set_bool_bulk`, table utils |
| `coord.lua` | `ws.coord`, `ws.dircoord`, `ws.relcoord`, `ws.getdir/setdir`, etc. |
| `inventory.lua` | `ws.find_item_in_table`, `ws.to_hotbar`, `ws.switch_to_item`, `ws.inv_full`, etc. |
| `world.lua` | `ws.dig`, `ws.place`, `ws.replace`, `ws.donodes`, `ws.dignodes`, etc. |
| `tools.lua` | `ws.get_digtime`, `ws.select_best_tool`, `ws.is_diggable` |
| `combat.lua` | `ws.aim`, `ws.gaim`, `ws.find_player`, `ws.playeron` |
| `waypoints.lua` | `ws.display_wp`, `ws.clear_wp`, `ws.clear_wps` |

Add extracted features into wasplib:
- `ws.make_blocks()` — auto-craft from wielded item
- `ws.loot()` / `ws.dumpto()` / `ws.invdump()` — inventory dump
- `ws.icebreaker()` — break ice in range

Drop dead code (`coorddir` with undefined vars, duplicate functions).

### Phase 2: New mods from emicor
Create separate mods (UI/bot features):

| Mod | Description | Origin Line |
|-----|-------------|-------------|
| lockview | Lock camera yaw/pitch for building | emicor:1271 |
| headsaver | Auto-dig block at head level | emicor:1287 |
| invsaver | Auto-transfer to ender chest on low HP/death | emicor:1561 |
| antitower | Tower scaffold building | emicor:585,596 |
| walls | Wall/ceiling/platform builder | emicor:779,788,1493 |
| autoevade | Dodge projectiles automatically | emicor:1429 |

Each gets `mod.conf`, `init.lua`, and depends on `wasplib`.

### Phase 3: Polish kept mods
- One pass each: fix formatting, add `mod.conf` where missing
- Merge `digtool` into `diglib`
- Fix `mcl_find_stronholds` typo → `mcl_find_strongholds`

### Phase 4: scaffold + dte compatibility
- Audit for API changes, fix broken calls
- These are the largest mods (2545 and 5434 LoC), highest risk

### Phase 5: Drop discarded mods
- Remove blockmaker, teamchat, autodupe, digtool, nodebot, emicor

### Tests
- Integration tests in `clientmods/al_test/` for each new mod
- Run `./util/ci/run_al_tests.sh` after each phase
