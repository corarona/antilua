# litematica

Schematic preview and placement tool. Loads WorldEdit-format schematics as colored particle overlays in the world, and allows placing the schematic nodes via the PlaceLiteM cheat. Based on WorldEdit code.

## Player usage

- **Chat commands:**
  - `/liteload <schematic>` — Load and display a WorldEdit schematic (raw string or `$` for `litematica_output` setting). Nodes appear as colored particles.
  - `/litepos1` — Set region corner 1 at player position.
  - `/litepos2` — Set region corner 2 at player position.
  - `/litesave` — Save nodes between pos1 and pos2 to `litematica_output` setting.
- **Cheat:** `PlaceLiteM` (category Place, setting `placelitem`) — Place loaded schematic nodes within a 4-block radius around the player.
- **Settings:**
  - `litematica_file` — (unused) would load from file.
  - `litematica_output` — stores serialized schematic data.
  - `litematica_node_names` — JSON array of node names for particle display.
  - `litematica_texture_names` — JSON array of corresponding texture filenames.

## API

None.
