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
| `poi_screenshots` | bool | false | Capture a screenshot and store it with each new waypoint |
| `poi_map_section_size` | int | 512 | Size (nodes) of the big-map section shown in the waypoint GUI |

These settings are also exposed in the Settings dialog under *Client Mods > poi`
(plus `poi_show_all_waypoints`, `auto_death_waypoint`, `auto_death_waypoint_max`,
`poi_shownames`, `auto_screenshot`).

### Quick menu

Every waypoint is exposed as an entry in the Quick Access Palette (`~`).
Activating one selects it in the waypoint GUI and shows its HUD marker.
With `Show All Waypoints` (or the `poi_show_all_waypoints` setting) enabled,
waypoints from all servers are listed, with the `server:port:` prefix shown
in the entry label.

### Displayed waypoints

- Every displayed waypoint appears both as a world-space HUD marker and as a
  dot on the minimap (in the waypoint's group color), when the minimap is
  enabled. The minimap marker carries the waypoint name, which the Antilua
  big map shows next to the dot.
- The waypoint list always shows the distance to each waypoint; the A-Z/Dist
  button still controls the sort order.
- The "Add Here" button in the GUI adds a waypoint at your current position,
  with a suggested name from the node you're standing on.
- The waypoint GUI shows a big-map section centered on the selected waypoint
  right under its screenshot (requires the Antilua big map; size configurable
  via `poi_map_section_size`), with a **View on Map** button that opens the
  fullscreen big map centered on the waypoint.
- Rendered big-map section images are transient and are cleared on disconnect
  so they don't accumulate on disk.

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

`poi.set_hud_info(text)` — *removed, moved to FlightHUD*

`poi.display(pos, name)` — show a HUD waypoint at `pos` with label `name`.

`poi.display_waypoint(name)` — look up waypoint by name, aim at it, display HUD, show info panel.

`poi.select_waypoint(name)` — select the waypoint in the GUI and display it (aim + HUD marker). Returns `true` on success.

`poi.get_nearest_name()` — return the name of the closest waypoint within 500m, or the quadrant name.

`poi.register_transport(name, func, [label])` — register a transport method for the formspec GUI. `func(pos, name)` is called when the button is pressed; return truthy to signal an error. `label` is an optional friendly button text (defaults to `name`).

`poi.display_formspec()` — open the waypoint management formspec with textlist, display/rename/delete buttons, and registered transport buttons.
