# devtools

Development and debugging tools, including metadata inspection, node definition dumps, void-air pocket finding, auto-build scaffolding, and particle/sound leak detection.

## Player usage

**Cheats (DevTools category):**

- `ItemMeta` — Dumps the wielded item name and its metadata (`meta:to_table()`) to chat and log.
- `PointedMeta` — Dumps the metadata table of the node at the pointed position.
- `PosMeta` — Dumps the metadata table of the node at the player's current position.
- `PointedDef` — Dumps the node definition of the node at the pointed position.

**Cheats (other categories):**

- `FindVoidAir` (category: DevTools) — Scans a 60×52 area below the player (y: -180 to -128) for air nodes and marks the first pocket found with a waypoint.
- `NoWaterStop` (category: Bots) — Disables `continuous_forward` and itself when no water source is found within 50 nodes.
- `Pyramid` (category: Scaffold) — Builds a pyramid structure from red sandstone at a hardcoded position using reachable-position placement.

**Additional behavior:** Detects remote particle spawners (>256 nodes away) and far-away sounds, marking them as POI waypoints and logging a message.

## API

None.

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| FindVoidAir | fvair | Scans below player for void-air pockets and marks first with waypoint. |
| ItemMeta | (func) | Dumps wielded item name and metadata to chat and log. |
| PointedMeta | (func) | Dumps metadata table of node at pointed position. |
| PosMeta | (func) | Dumps metadata table of node at player's current position. |
| PointedDef | (func) | Dumps node definition of node at pointed position. |
| NoWaterStop | nowaterstop | Disables continuous_forward when no water found within range. |
