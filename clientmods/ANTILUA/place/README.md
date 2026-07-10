# place

Block placement and world-building cheats (formerly scaffold). Provides
automated scaffolding, wall building, fluid blocking, lantern placement,
highway construction, moss farming, and bot-driven sponge/water clearing.

## Player usage

### Chat commands

| Command | Description |
|---------|-------------|
| `/sc_pos1 [x,y,z]` | Set constraint position 1 (delegates to `/cpos1`) |
| `/sc_pos2 [x,y,z]` | Set constraint position 2 (delegates to `/cpos2`) |
| `/sc_reset` | Reset constraints (delegates to `/creset`) |

### Cheats

| Cheat | Setting | Category | Description |
|-------|---------|----------|-------------|
| PlaceOnTop | `place_on_top` | Place | Place wielded block under air in radius |
| MultiScaff | `scaffold` | Place | Place blocks in a grid below player (configurable width/depth/above/mod) |
| RandomScaff | `place_rnd` | Place | Replace blocks below with random items from `randomscaffold` nlist |
| BlockWater | `block_water` | Place | Fill water sources in radius |
| BlockLava | `block_lava` | Place | Fill lava sources in radius |
| BlockSources | `block_sources` | Place | Fill water and lava sources with wielded block |
| BlockLavaSources | `block_lava_sources` | Place | Fill lava sources only |
| PlaceOn | `scaffold_placeon` | Place | Place specified block under air in radius from selected nlist |
| SpongeBot | `spongebot` | Bots | Autonomous sponge bot — finds and digs water sources |
| Autosponge | `autosponge` | Place | Place sponge at nearby water source |
| AutoCombatLog | `autoclog` | Player | Disconnect and teleport randomly when other players are detected nearby |

### Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `place.width` | int | 5 | Width for MultiScaff |
| `place.depth` | int | 1 | Depth for MultiScaff |
| `place.above` | int | 0 | Above-ground offset for MultiScaff |
| `placeon.range` | int | 4 | Range for PlaceOn |
| `placeon.node` | string | `mcl_core:dirt_with_grass` | Node to place |
| `autoclog.detect_range` | int | 270 | Player detection range |
| `autosponge.range` | int | 10 | Sponge search range |
| `spongebot.search_range` | int | 50 | Water search range |
| `spongebot.travel_range` | int | 200 | Max travel distance |
| `slow_blocks_per_second` | int | 8 | Blocks placed per second |

## API

### Global

`scaffold` — namespace table (backward compat with legacy scaffold mod name).

### Functions

The `scaffold` namespace delegates to `ws.*` functions:

`scaffold.setting(key)` — read `place.<key>` setting as number.

`scaffold.in_cube(pos, p1, p2)` — delegate to `ws.in_cube`.

`scaffold.can_place_at(pos)` — delegate to `ws.can_place_at`.

`scaffold.can_place_wielded_at(pos)` — delegate to `ws.can_place_wielded_at`.

`scaffold.find_any_swap(items, hslot)` — delegate to `ws.find_any_swap`.

`scaffold.in_list(val, list)` — delegate to `ws.in_list`.

`scaffold.place_if_needed(items, pos, place)` — delegate to `ws.place_if_needed`.

`scaffold.place_if_able(pos)` — delegate to `ws.place_if_able`.

`scaffold.dig(pos)` — delegate to `ws.dig_if_able`.

`scaffold.set_pos1(pos)` — delegate to `ws.set_pos1`.

`scaffold.set_pos2(pos)` — delegate to `ws.set_pos2`.

`scaffold.reset()` — delegate to `ws.reset_constraints`.

`scaffold.template(setting, func, offset, funcstop)` — create a simple place-loop
function that places at a relative offset every tick when the setting is active.

`scaffold.register_template_scaffold(name, setting, func, offset, funcstop)` — register
a cheat via `ws.rg` using the template system with `Place` category.
