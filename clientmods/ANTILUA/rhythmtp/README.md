# rhythmtp

Burst-teleport movement system. Teleports the player forward (or to a target position) in steps, respecting an anticheat pool budget. Toggle on for continuous auto-forward movement.

## Player usage

- **Cheat:** `RhythmTP` (category Movement, setting `rhythmtp`)
  - When toggled on, continuously teleports forward at the configured distance.
- **Chat commands:**
  - `/rhythmtp [dist]` — One-shot burst forward by `dist` meters (default 100). Use `stop` as argument to cancel active movement.
  - `/rhythmtp_to <x,y,z>` — Burst-teleport to specific coordinates.
- **Settings:**
  - `rhythmtp.budget` (number, 1–14, default 10) — pool budget in seconds
  - `rhythmtp.dist` (number, default 100) — forward teleport distance
  - `rhythmtp.h_speed` (number, default 4.0) — horizontal speed factor
  - `rhythmtp.vup_speed` (number, default 26.0) — vertical ascent speed
  - `rhythmtp.drain_factor` (number, 0.5–1, default 0.98) — cooldown drain per step

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| RhythmTP | `rhythmtp` | Burst-teleport movement — toggle on for continuous auto-forward teleportation in steps |

## API

None.
