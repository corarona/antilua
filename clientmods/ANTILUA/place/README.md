# place

Block placement and world-building cheats. Provides
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
| PlaceOn | `placeon` | Place | Place blocks on top of exposed surfaces (use wielded item or configured node) |
| MultiScaff | `scaffold` | Place | Place blocks in a grid below player (configurable width/depth/above) |
| RandomScaff | `place_rnd` | Place | Replace blocks below with random items from `randomscaffold` nlist |
| BlockSources | `block_sources` | Place | Fill water and lava sources in radius |
| SpongeBot | `spongebot` | Bots | Autonomous sponge bot — finds and digs water sources |
| Autosponge | `autosponge` | Place | Place sponge at nearby water source |

### Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `place.width` | int | 5 | Width for MultiScaff |
| `place.depth` | int | 1 | Depth for MultiScaff |
| `place.above` | int | 0 | Above-ground offset for MultiScaff |
| `place.random` | bool | false | Randomly pick placement node from hotbar, weighted by stack count |
| `placeon.use_wielded` | bool | true | Use wielded item instead of configured node |
| `placeon.range` | int | 5 | Range for PlaceOn |
| `placeon.node` | string | `mcl_core:dirt_with_grass` | Node to place (when use_wielded is false) |
| `autosponge.range` | int | 10 | Sponge search range |
| `spongebot.search_range` | int | 50 | Water search range |
| `spongebot.travel_range` | int | 200 | Max travel distance |
| `slow_blocks_per_second` | int | 8 | Blocks placed per second |


