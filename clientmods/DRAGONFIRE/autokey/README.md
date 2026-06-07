# autokey

Continuously holds a key (e.g. sneak, sprint) while a cheat setting is enabled, releasing it when the cheat is toggled off.

## Player usage

**Cheats:**

- `AutoSneak` (category: Movement, setting `autosneak`) — Holds the sneak key while touching the ground.
- `AutoSprint` (category: Movement, setting `autosprint`) — Holds the aux1 key at all times.

## API

All exported on the global `autokey` table.

- `autokey.register_keypress_cheat(setting, desc, category, keyname, condition)` — Registers a new keypress cheat.
  - `setting` (string) — `core.settings` bool key that controls the cheat.
  - `desc` (string) — Display name for the cheat menu.
  - `category` (string) — Cheat menu category.
  - `keyname` (string) — Key to hold (e.g. `"sneak"`, `"aux1"`).
  - `condition` (function or nil) — Optional function returning a bool; the key is only held when this returns true.
  - Returns nothing. Internally registers a `core.register_cheat` and a globalstep that calls `core.set_keypress`.

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| AutoSneak | autosneak | Continuously holds the sneak key while touching the ground. |
| AutoSprint | autosprint | Continuously holds the aux1 key. |
