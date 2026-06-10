# mclminer

Automated mining bot for mcl worlds. Finds the nearest target node (from `nlist.selected`), teleports to it step-by-step avoiding lava, and includes a lava panic system. Depends on `nlist` for node-type selection.

## Player usage

- **Cheat:** `Mclminer` (category Bots, setting `mclminer`)
- Automatically enables `autoeat` and `dighead` on start.
- **Settings:**
  - `mclminer.tp_step` (number, default 3.8) — teleport step distance
  - `mclminer.min_hp` (number, default 15) — minimum HP to operate
  - `mclminer.lava_range` (number, default 10) — safe distance from lava
  - `mclminer.search_range` (number, default 50) — node search radius

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| Mclminer | `mclminer` | Automated mining bot — finds nearest target node, teleports step-by-step avoiding lava, includes lava panic |

## API

None.
