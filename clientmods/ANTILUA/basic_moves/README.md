# basic_moves

Flight automation, axis snapping, auto-forward-sprint, and POI-based transport methods.
Provides a multi-mode autopilot that navigates toward a selected POI or follows a player.

## Player usage

**Cheats:**

| Cheat | Setting | Description |
|-------|---------|-------------|
| Autopilot | autopilot | Automatic flight with obstacle avoidance (6 modes) |
| AutoFsprint | autoforwardsprint | Holds `special1` key while `continuous_forward` is active |
| AxisSnap | axissnap | Snaps player yaw to nearest 90° cardinal direction |
| FlightHUD | flight_hud | HUD overlay with horizon, compass, target info, altitude/speed bars |

**Autopilot modes** (configured in the cheat settings panel):

| Mode | Description |
|------|-------------|
| `3d_aim` | Direct line toward POI |
| `2d_aim` | Horizontal aim at POI Y-level, vertical movement manual |
| `3d_velocity` | Zero-gravity velocity toward POI |
| `nether` | Nether-ratio target (X/8, Z/8) for portal travel |
| `follow` | Follow the nearest player instead of a POI |
| `hover` | Maintain altitude above terrain while moving toward POI |

**POI transport methods** (appear in the POI context menu):

- `CTP` — Teleports player directly to the POI position.
- `STP` — Sends a `/teleport` chat command to the server.
- `Autopilot` — Starts autopilot toward the POI.

## API

All exported on the global `autofly` table.

- `autofly.tpos` (vector or nil) — Current target position for flight modes.
- `autofly.atpos` (vector or nil) — Actual POI position (may differ from `tpos` in 2d_aim).
- `autofly.follow_name` (string or nil) — Name of the player being followed.
- `autofly.warp(name)` → bool — Warp to a named waypoint. Returns `false` if the waypoint is in the void dimension.
