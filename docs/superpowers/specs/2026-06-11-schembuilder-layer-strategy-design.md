# SchemBuilderBot Layer Strategy

## Problem

SchemBuilderBot currently only supports a "closest-first" placement strategy
(finds the nearest eligible node by Euclidean distance). For large builds this
leads to chaotic flying — the bot zips between Y levels, never finishing a
layer, making it hard to visually track progress or spot missing blocks.

## Design

### Setting

Add `schembuilderbot.strategy` — a string setting with values `"closest"`
(default, current behavior) and `"layer"` (bottom-to-top layer-by-layer).

Read on bot activation in `on_start` as `self._strategy`.

### Layer strategy behavior

**`find_pos`** — Group remaining `place_nodes` (non-air, items in inventory) by
`entry.pos.y`. Sort Y levels ascending, pick the lowest Y that has any
placeable entries. Within that layer, pick the node closest to the player
(same distance metric as current). Fallback to supply chest if no items.

**`do_pos`** — After placing the primary target, the batch placement loop
(`batch_size` nearby nodes in one tick) is modified for layer mode: skip any
node where `entry.pos.y > pos.y` (never place higher than the player's current
position, keeping head at a free layer). The "closest" strategy's batch loop
is unchanged.

**`update_pos`** — Unchanged (delegates to `find_pos` on re-target).

### sbots framework

No changes needed. The current 3-stage state machine (find → move → arrive/act)
works identically for both strategies. Movement primitives (aim + continuous_forward)
are sufficient.

### Files changed

| File | Change |
|------|--------|
| `clientmods/ANTILUA/schembuilder/settingtypes.txt` | Add `schembuilderbot.strategy` string setting |
| `clientmods/ANTILUA/schembuilder/init.lua` | Branch in `find_pos` and `do_pos` on `self._strategy` |
| `clientmods/al_test/test_schembuilder.lua` | Add tests for layer strategy |

### Tests

1. `schembuilderbot.strategy setting exists` — default is `"closest"`
2. `schembuilderbot.strategy can be set to "layer"` — round-trip
3. `find_pos with layer strategy picks lowest Y` — create test place_nodes at
   Y=10 and Y=20, strategy="layer" should pick Y=10
4. `do_pos with layer strategy skips nodes above player` — batch loop with
   entries above player Y is filtered out
