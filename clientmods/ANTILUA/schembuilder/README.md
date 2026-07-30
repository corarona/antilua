# SchemBuilder

Schematic preview and placement tool. Loads MTS schematics as semi-transparent particle overlays in the world, and provides multiple ways to place the schematic nodes.

## Credits

- **Gregon** — Created the original Litematica mod for Minetest.
  Content DB: https://content.luanti.org/users/Gregon/
  GitHub: https://github.com/Montandalar/gregon_litematica
- **Montandalar** — Maintained and improved the original Litematica.
- **cora** — Adapted and extended into SchemBuilder for Antilua, adding
  the SchemBuilderBot, SchematicLooter, batch placement, and integrating
  with the sbots framework.

## Player usage

- **Chat commands:**
  - `/schembuild <schematic>` — Load and display a schematic. Use `$` for
    `schembuilder_output` setting, or `file:<path>` for MTS files from disk.
  - `/spos1` — Set region corner 1 at player position.
  - `/spos2` — Set region corner 2 at player position.
  - `/ssave` — Save nodes between pos1 and pos2 to `schembuilder_output` setting.
- **Cheats:**
  - `AutoSchemPlace` (Place category) — Place loaded schematic nodes within
    range using the strategy system.
  - `SchemBuilderBot` (Bots category) — Walks to the nearest unplaced
    schematic node and places it. Supports batch placement and cooldown.
  - `RhythmBuildBot` (Bots category) — Builds schematics via rhythmtp
    teleportation.
  - `SchematicLooter` (Inventory category) — Scans nearby containers for
    items matching the current schematic and moves them to your inventory.
- **Settings:**
  - `schembuilder_output` — stores serialized schematic data (base64 MTS).
  - `autoschemplace.*` — AutoSchemPlace settings (range, batch size, strategy).
  - `schembuilderbot.*` — SchemBuilderBot settings (cooldown, batch size).
  - `schematic_looter.range` — Container scan range (default 5).
  - `schematic_looter.max_per_scan` — Max items to loot per scan (default 16).

## Cheats

| Cheat | Category | Setting | Description |
|-------|----------|---------|-------------|
| AutoSchemPlace | Place | `autoschemplace` | Auto-place nodes within range via strategy |
| RhythmBuildBot | Bots | `schembuilderbot` | Build schematics via rhythmtp teleportation |
| SchemBuilderBot | Bots | `schembuilderbot` | Walk-to-and-place bot |
| SchematicLooter | Inventory | `schematic_looter` | Loot materials from nearby containers |
