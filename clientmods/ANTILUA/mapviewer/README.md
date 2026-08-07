# mapviewer

A formspec-based viewer for the Antilua big map (the client-side per-server
minimap persistence). Shows the map in a window with button-driven pan and
zoom, overlays the currently displayed POI waypoints, and can export the
visible section as a PNG.

## Usage

### Chat commands

| Command | Aliases | Description |
|---------|---------|-------------|
| `/mapviewer` | `/mv`, `/viewmap` | Open the big map viewer |

### Cheats

| Cheat | Category | Description |
|-------|----------|-------------|
| MapViewer | Render | Open the big map viewer |

The viewer is also available as a *Map* tab in the inventory screen.

## Features

- **Pan** — N/S/W/E buttons move the view by a fraction of the current view
  size (`mapviewer_pan_step`).
- **Zoom** — `+`/`-` buttons scale the section between `mapviewer_min_size`
  and `mapviewer_max_size` nodes (`mapviewer_zoom_factor` per press).
- **Center Player** — recenters the view on your position.
- **Fit Saved Area** — zooms out to cover every saved big-map block
  (`core.al_bigmap:get_coverage()`).
- **Refresh** — re-renders the current view so newly explored blocks appear.
- **POI overlay** — waypoints that the `poi` mod is currently displaying
  (the same set shown on the fullscreen big map) are drawn as colored dots
  with their names, rim-clamped to the map edge when off-screen.
- **Save as image** — copies the currently displayed map section to
  `<user data>/mapviewer/map_<x>_<z>_<size>_<time>.png` and shows the path.

## Notes

- Requires the Antilua big map (`enable_minimap = true`), which supplies the
  saved minimap blocks via `core.al_bigmap`.
- Rendered section PNGs accumulate in the big map's `images/` dir during a
  session and are cleaned up the next time the viewer is opened.
- The last viewed center/zoom is remembered per server.
