# basic_moves

Flight automation, axis snapping, auto-forward-sprint, and POI-based transport methods. Provides several auto-pilot modes that navigate toward a selected POI.

## Player usage

**Cheats:**

- `Fly3d` (category: Movement, setting `afly3d`) — Aims toward the selected POI in 3D while `continuous_forward` is held. Stops when within landing distance. Daughters: `continuous_forward`, `pitch_move`.
- `Mv3d` (category: Movement, setting `aflymv3d`) — Sets velocity toward the POI with zero gravity. Restores gravity on stop. Daughters: `continuous_forward`.
- `Fly2d` (category: Movement, setting `afly2d`) — Aims horizontally toward the POI (same Y level as player), leaving vertical movement manual. Daughters: `continuous_forward`.
- `FlyNRoof` (category: Movement, setting `aflynroof`) — Aims toward a Nether-ratio target (X/8, Z/8) for portal-based travel. Daughters: `continuous_forward`.
- `AutoFsprint` (category: Movement, setting `autoforwardsprint`) — Holds `special1` key while `continuous_forward` is enabled. No daughters.
- `AxisSnap` (category: Player, setting `axissnap`) — Snaps player yaw to the nearest 90° cardinal direction (0, 90, 180, 270).

**POI transport methods** (appear in the POI context menu):

- `CTP` — Teleports player directly to the POI position.
- `STP` — Sends a `/teleport` chat command to the server.
- `Fly3D` — Starts Fly3d toward the POI.
- `Mv3D` — Starts Mv3d toward the POI.
- `Fly2D` — Starts Fly2d toward the POI.
- `Nroof` — Starts FlyNRoof toward the POI.

## API

All exported on the global `autofly` table.

- `autofly.landing_distance` (number, default 15) — Distance at which flight modes consider the target reached.
- `autofly.tpos` (vector or nil) — Current target position for flight modes.
- `autofly.atpos` (vector or nil) — Actual POI position (may differ from `tpos` in Fly2d).
- `autofly.warp(name)` → bool — Warp to a named waypoint. Returns `false` if the waypoint is in the void dimension.

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| AutoFsprint | autoforwardsprint | Holds special1 key while continuous_forward is active. |
| AxisSnap | axissnap | Snaps player yaw to nearest 90° cardinal direction. |
| Fly3d | afly3d | Aims toward selected POI in 3D while continuous_forward is held. |
| Mv3d | aflymv3d | Sets velocity toward POI with zero gravity. |
| Fly2d | afly2d | Aims horizontally toward POI at same Y level as player. |
| FlyNRoof | aflynroof | Aims toward Nether-ratio target for portal-based travel. |
| FlightHUD | flight_hud | Shows flight mode HUD overlay. |
