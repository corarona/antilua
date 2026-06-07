# findbiome

Searches for a suitable biome position using a square spiral search grid. Given a starting position and a list of biome names, returns the closest matching spawn position within the world boundaries.

## Player usage

No chat commands or cheats.

## API

- `find_biome(pos, biomes)` — Searches outwards on a spiral grid (64-node resolution, 16384 checks) from `pos` for any biome named in the `biomes` array. Returns `spawn_pos, success` where `spawn_pos` is a `{x,y,z}` table with the y-coordinate adjusted via `minetest.get_spawn_level`, or `nil, false` if a biome name is invalid.

## Cheats

None. Library mod — no cheats registered.
