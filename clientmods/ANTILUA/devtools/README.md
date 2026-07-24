# devtools

Development and debugging tools, including metadata inspection, node definition dumps, void-air pocket finding, and particle/sound leak detection.

## Player usage

**Cheats (DevTools category):**

- `ItemMeta` — Dumps the wielded item name and its metadata (`meta:to_table()`) to chat and log.
- `PointedMeta` — Dumps the metadata table of the node at the pointed position.
- `PosMeta` — Dumps the metadata table of the node at the player's current position.
- `PointedDef` — Dumps the node definition of the node at the pointed position.

**Cheats (other categories):**

- `FindVoidAir` (category: DevTools) — Scans a 60×52 area below the player (y: -180 to -128) for air nodes and marks the first pocket found with a waypoint.

**Additional behavior:** Detects remote particle spawners (>256 nodes away) and far-away sounds, marking them as POI waypoints and logging a message.

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| FindVoidAir | fvair | Scans below player for void-air pockets and marks first with waypoint. |
| ItemMeta | (func) | Dumps wielded item name and metadata to chat and log. |
| PointedMeta | (func) | Dumps metadata table of node at pointed position. |
| PosMeta | (func) | Dumps metadata table of node at player's current position. |
| PointedDef | (func) | Dumps node definition of node at pointed position. |