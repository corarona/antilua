# Player Radar, Death Waypoints, Chest Stealer — Design

## 1. Player Radar

**Setting:** `player_radar` (bool, default false), **Category:** Render

A compass-style HUD bar showing nearby players. Format:
```
▲ Alex(30)  ▶ Bob(50)  ▼ Charlie(120)  ◀ Dave(80)
```

- Arrow direction relative to player's facing: ▲ ahead, ▶ right, ▼ behind, ◀ left
- Color-coded by distance: green < 50m, yellow 50-100m, red > 100m
- Configurable: max range (default 200), max players shown (default 8)
- Updates via globalstep, rendered as a single `hud_elem_type = "text"` element

**Mod:** `clientmods/DRAGONFIRE/player_radar/` — depends on wasplib

## 2. Death Waypoints

**Setting:** `auto_death_waypoint` (bool, default true), **Category:** Player

Extends existing POI death waypoint with a dedicated setting toggle. When enabled, death auto-creates a waypoint named "Death waypoint" at death location. If disabled, no auto-waypoint is created.

**Mod:** Modified in `clientmods/DRAGONFIRE/poi/init.lua`

## 3. Chest Stealer

**Setting:** `chest_stealer` (bool, default false), **Category:** Inventory

Injects a "Take All" button into container formspecs. On click, moves all items from the container into the player's first empty inventory slots.

**Flow:**
1. `on_receiving_formspec` detects nodemeta formspecs (chests, furnaces, etc.)
2. Injects `button[...,chest_stealer_take_all;Take All]` into the formspec
3. `on_sending_nodemeta_fields` intercepts the button click
4. Returns `true` to cancel server submission (server never sees the unknown field)
5. Iterates all container inventory lists, moves non-empty stacks to `current_player` main
6. Leaves formspec open for normal interaction

**Mod:** `clientmods/DRAGONFIRE/chest_stealer/` — depends on wasplib
