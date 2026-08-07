# basic_moves

Flight automation, axis snapping, auto-forward-sprint, and POI-based transport methods.
Provides a multi-mode autopilot that navigates toward a selected POI or follows a player.

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| Autopilot | autopilot | Automatic flight with obstacle avoidance (6 modes) |
| AutoFsprint | autoforwardsprint | Holds `special1` key while `continuous_forward` is active |
| AxisSnap | axissnap | Snaps player yaw to nearest 90° cardinal direction |
| FlightHUD | flight_hud | HUD overlay with horizon, compass, target info, altitude/speed bars |

Autopilot settings (`autopilot.<key>` in the cheat settings panel):

- `autoengage` (bool, default true) — Automatically start autopilot when
  `continuous_forward` is enabled while a POI is selected. Set to false so
  other mods toggling forward movement never start a flight.
- `avoid_obstacles` (bool, default true) — Probe ahead along the actual
  flight path (not the quantized cardinal heading) and climb, descend, or
  sidestep around solid nodes.

**Autopilot modes** (configured in the cheat settings panel; the parenthetical
is the label shown in the dropdown):

| Mode | Label | Description |
|------|-------|-------------|
| `3d_aim` | Direct line | Direct line toward POI |
| `2d_aim` | Horizontal aim | Horizontal aim at POI Y-level, vertical movement manual |
| `3d_velocity` | Zero-gravity | Zero-gravity velocity toward POI |
| `nether` | Nether portal | Nether-ratio target (X/8, Z/8) for portal travel |
| `follow` | Follow player | Follow the nearest player instead of a POI |
| `hover` | Hover | Maintain altitude above terrain while moving toward POI |

**POI transport methods** (appear in the POI context menu):

- `CTP` ("Teleport (Client)") — Teleports player directly to the POI position.
- `STP` ("Teleport (Server)") — Sends a `/teleport` chat command to the server.
- `Autopilot` — Starts autopilot toward the POI.

**FlightHUD target line**: when a POI is selected, the target HUD shows the
target's bearing relative to your nose (`⟵`/`⟶`/`↑` + degrees) and vertical
distance (`▲`/`▼` + meters). The speed readout additionally shows the
climb/descent rate. Autopilot notifies on arrival.

## API

All exported on the global `autofly` table.

- `autofly.tpos` (vector or nil) — Current target position for flight modes.
- `autofly.atpos` (vector or nil) — Actual POI position (may differ from `tpos` in 2d_aim).
- `autofly.follow_name` (string or nil) — Name of the player being followed.
- `autofly.warp(name)` → bool — Warp to a named waypoint. Returns `false` if the waypoint is in the void dimension.
