# RailBuilder

Builds a straight golden-rail line with periodic light posts and nether
portal stations. Materials are restocked from named shulker kits kept in
the ender chest.

## What it builds

Per column along the build direction:

| Offset | Node |
|--------|------|
| `rail_y` | golden rail (`mcl_minecarts:golden_rail`) |
| `rail_y - 1` | support: block of redstone (`mcl_redstone_torch:redstoneblock`) on sparsity columns, otherwise existing solid ground, otherwise any other carried block — redstone as last resort (rails always need support) |
| `rail_y - 1 + light_above` | light block every `light_every` columns (any inventory node with `light_source >= min_light`) |

Every `station_every` columns a nether portal (4 wide, 5 tall obsidian
frame) is built beside the line and the remaining nodes of the station kit
are placed as decoration on the ground between rail and portal.

## Kits

Two shulkers live in the ender chest, identified by their custom name
(set on an anvil, matched case-insensitively):

- **railkit** — golden rails, blocks of redstone, a light block, a pickaxe
- **stationkit** — obsidian, flint & steel, decorative nodes, a pickaxe

On restock the bot places an ender chest and the kit shulker in air away
from the rail line (digging a pocket if needed) to access their contents,
drains them, and recovers the containers. A pickaxe is kept in the hotbar
at all times.

If the private `kit_util` helper is installed, consumables are topped up
automatically (including a spare ender chest, which drops obsidian when
mined). Without it the bot degrades gracefully: it only uses what the
kits/player actually carry and stops with a notification when materials
run out.

## Requirements to start

- carry (or have in the ender chest): one **ender chest**, one **single
  chest**, both kits, a pickaxe
- stand at the start of the line, facing the build direction

## Settings

| Setting | Default | Meaning |
|---------|---------|---------|
| `movement` | walk | sbots movement strategy (walk, teleport, client_tp, ...) |
| `direction` | +x | build axis (`+x`, `-x`, `+z`, `-z`) |
| `redstone_sparsity` | 1 | redstone every Nth column |
| `light_every` | 8 | light post every Nth column |
| `light_above` | 3 | light block this far above the redstone block |
| `min_light` | 10 | minimum `light_source` for the light block |
| `station_every` | 200 | portal station every Nth column (0 = never) |
| `portal_side` | right | portal side relative to build direction |
| `side_offset` | 3 | lateral distance of the portal from the rail |
| `rail_kit_item` | "" | explicit railkit shulker item name (optional) |
| `station_kit_item` | "" | explicit stationkit shulker item name (optional) |
| `spare_kit` | true | duplicate kits before using them (needs `kit_util`) |
