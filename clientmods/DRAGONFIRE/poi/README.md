# poi

Persistent waypoint (POI) system. Stores named positions per-server, displays
HUD waypoints with distance/speed/ETA info, provides a formspec GUI for
management, and supports a transport callback system for teleportation mods.

## Player usage

### Chat commands

| Command | Aliases | Description |
|---------|---------|-------------|
| `/waypoints` | `/wp`, `/wps`, `/waypoint` | Open the waypoint GUI |
| `/add_waypoint <pos> <name>` | `/wa`, `/add_wp` | Add a waypoint at coordinates (e.g. `0,0,0 home`) |
| `/add_waypoint_here [name]` | `/wah`, `/add_wph` | Mark current position as waypoint (default: timestamp) |
| `/clear_waypoint` | `/cwp`, `/cls` | Hide the displayed waypoint HUD |
| `/wpdisplay <pos> <name>` | `/wpd` | Display a waypoint at arbitrary position |
| `/dump_pois` | — | Log all stored POI positions to debug |

### Cheats

| Cheat | Setting | Category | Description |
|-------|---------|----------|-------------|
| DeathTP | `death_tp` | Player | Auto-teleport to death location and collect bones |
| ShowNames | `poi_shownames` | Render | Show local player name and nearby player names on HUD |
| POIs | — | Misc | Open the waypoint formspec GUI |

### Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `death_tp` | bool | false | Auto-teleport to death location |

## API

### Global

`poi` — main namespace table.

`poi.registered_transports` — array of `{name, func}` transport registrations.

`poi.speed` — current player speed in nodes/second (updated once per second).

`poi.last_name` — name of last displayed waypoint.

`poi.last_pos` — position of last displayed waypoint.

`poi.etatime` — estimated time of arrival in minutes.

### Functions

`poi.check_vector(v)` — validate that `v` is a table with numeric x, y, z fields (no NaN). Returns `bool`.

`poi.getwps()` — return sorted array of waypoint names for the current server.

`poi.set_waypoint(pos, name)` — store a waypoint. `pos` can be a vector or string; returns `true`.

`poi.get_waypoint(name)` — return the position vector for a named waypoint, or `nil`.

`poi.delete_waypoint(name)` — remove a waypoint by name.

`poi.rename_waypoint(oldname, newname)` — rename a waypoint; returns `true` on success.

`poi.has_wp_near(pos)` — check if any waypoint exists within 256 nodes of `pos`.

`poi.get_quad()` — return cardinal quadrant string (e.g. `"North-east"`).

`poi.set_hud_wp(pos, title)` — display a HUD waypoint element pointing to `pos` with `title`.

`poi.set_hud_info(text)` — update the HUD info panel with speed, velocity, yaw, pitch, destination name, position, and ETA.

`poi.display(pos, name)` — show a HUD waypoint at `pos` with label `name`.

`poi.display_waypoint(name)` — look up waypoint by name, aim at it, display HUD, show info panel.

`poi.get_nearest_name()` — return the name of the closest waypoint within 500m, or the quadrant name.

`poi.register_transport(name, func)` — register a transport method for the formspec GUI. `func(pos, name)` is called when the button is pressed; return truthy to signal an error.

`poi.display_formspec()` — open the waypoint management formspec with textlist, display/rename/delete buttons, and registered transport buttons.
