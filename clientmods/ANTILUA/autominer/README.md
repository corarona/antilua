# AutoMiner

Automated mining bot. Finds the nearest target node (selected via `nlist`), teleports to it step-by-step using rhythmic teleport while avoiding lava, and includes a lava panic system. Depends on `nlist` for node-type selection and `rhythmtp` for movement.

## Player usage

- **Cheat:** `AutoMiner` (category Bots, setting `autominer`)
- Automatically enables `autoeat` on start.
- **Settings:**
  - `autominer.search_range` (int, default 50) — node search radius
  - `autominer.tp_step` (float, default 3.8) — teleport step distance
  - `autominer.min_hp` (int, default 15) — minimum HP to continue
  - `autominer.lava_range` (int, default 10) — safe distance from lava
  - `autominer.lava_nodes` (string) — comma-separated lava node names

## Cheats

| Cheat | Category | Setting | Description |
|-------|----------|---------|-------------|
| AutoMiner | Bots | `autominer` | Automated mining bot — finds nearest target node via nlist, teleports step-by-step avoiding lava, includes lava panic |

## API

None.
