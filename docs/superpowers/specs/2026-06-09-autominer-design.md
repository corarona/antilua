# AutoMiner — Generalized Ore Bot Design

**Goal:** Refactor `mclminer` → `autominer`: generalize to any game, replace direct teleport with rhythmtp-based movement, implement dig-before-tp pattern, and keep architecture open for future mining strategies.

**Architecture:** `rhythmtp` exposes polling API (`is_moving`, `get_target`). `autominer` is an `sbots.register_bot` that drives movement via rhythmtp polling in `do_step`. Lava detection uses a configurable node-name list with defaults for MCL2, Mineclonia, and Minetest Game.

---

## Components

### Component 1: rhythmtp API exports

**rhythmtp/init.lua** gains a `rhythmtp` namespace table exposing existing internal state:

```lua
rhythmtp = {}
rhythmtp.go_to = go_to
rhythmtp.stop = stop
rhythmtp.is_moving = function() return ACTIVE end
rhythmtp.get_target = function() return MOVING end
rhythmtp.go_forward = go_forward
```

Existing globals (`go_to`, `stop`, `go_forward`) kept for backward compat. No internal logic changes.

### Component 2: rename mclminer → autominer

| From | To |
|------|----|
| `clientmods/DRAGONFIRE/mclminer/` | `clientmods/DRAGONFIRE/autominer/` |
| `mod.conf`: `name = mclminer` | `name = autominer` |
| `mod.conf`: `depends = wasplib, nlist, sbots` | Unchanged |
| `settingtypes.txt`: `mclminer` | `autominer` |
| Bot cheat name `"Mclminer"` | `"AutoMiner"` |
| Setting prefix `mclminer.*` | `autominer.*` |
| Variable `mclminer_tgt` | `autominer_tgt` |
| `clientmods/mods.conf`: `load_mod_mclminer` | `load_mod_autominer` |
| `help/readmes.lua`: `["mclminer"]` entry | `["autominer"]` |
| `PLAN.md` | Update refs |
| `DRAGONFIRE/README.md` | Update refs |

### Component 3: generalized lava detection

Default lava nodes covering the three major game families:

```lua
local LAVA_NODES = {
	"mcl_core:lava_source", "mcl_core:lava_flowing",
	"mcl_nether:nether_lava_source", "mcl_nether:nether_lava_flowing",
	"default:lava_source", "default:lava_flowing",
}
```

Exposed as cheat setting `autominer.lava_nodes` (string, comma-separated) for game-specific overrides.

### Component 4: dig-before-tp mining flow

Core loop in `do_step` each tick:

```
1. lavapanic() — safety check (keep existing)
2. hp / entity proximity checks (keep existing)
3. If target exists:
   dist = distance(player, target_pos)
   if dist <= player reach:
       ws.dig(target_pos)           → break the ore
       core.localplayer:set_pos(target_pos)  → occupy now-empty space (safe from noclip)
       autominer_tgt = nil          → stage 0 finds next
   elseif not rhythmtp.is_moving():
       ws.aim(target_pos)
       rhythmtp.go_to(target_pos)   → start approaching
4. If no target:
   if rhythmtp.is_moving():
       wait (in transit)
   else:
       do nothing (stage 0 will find target)
```

### Component 5: sbots integration

`autominer` stays registered via `sbots.register_bot`. The sbots lifecycle provides:
- Cheat menu registration (`ws.rg` under "Bots" category)
- `on_start`/`on_stop` for setup/teardown
- Stage machine (find → do → loop)

`find_pos` returns nearest nlist node not near lava. `do_pos` always returns `true` (stage loops immediately). All real work in `do_step`.

### Component 6: strategy placeholder

`find_pos` is the extension point for future mining strategies:

```lua
find_pos = function(self, pos)
    return find_nearest_target(pos, LAVA_NODES)
end
```

A new strategy (strip mine, branch mine, vein mine) replaces just this function. No special interface needed — just a function returning a position or nil.

### Component 7: tests

New `clientmods/al_test/test_autominer.lua`:

- `rhythmtp` API exists (is_moving, get_target, stop, go_to, go_forward)
- `core.settings:get("autominer")` returns a value (cheat registered)
- `autominer.*` default settings exist (lava_nodes, tp_step, min_hp, lava_range, search_range)
- `core.TOSERVER` still correct (side-effect sanity check)

### Dependencies

- `wasplib` — ws.dig, ws.aim, ws.notify
- `nlist` — target node type selection
- `sbots` — bot framework lifecycle
- `rhythmtp` — movement via polling API

### Files changed

| File | Change |
|------|--------|
| `rhythmtp/init.lua` | Add `rhythmtp` namespace with state queries |
| `clientmods/DRAGONFIRE/mclminer/` → `autominer/` | Rename directory |
| `autominer/init.lua` | Rewrite: generalized lava, dig-before-tp, rhythmtp polling |
| `autominer/mod.conf` | `name = autominer` |
| `autominer/settingtypes.txt` | Update setting prefix |
| `autominer/README.md` | Full rewrite for new name + features |
| `clientmods/mods.conf` | `load_mod_autominer` |
| `DRAGONFIRE/README.md` | Table entry update |
| `help/readmes.lua` | Regenerate mclminer → autominer entry |
| `PLAN.md` | Update sidebar refs |
| `clientmods/al_test/test_autominer.lua` | New tests |

### Not changed

- `docs/superpowers/specs/` and `docs/superpowers/plans/` historical docs — unchanged
- `sbots/init.lua` — listDigBot flight-based behavior unchanged (different use case)
