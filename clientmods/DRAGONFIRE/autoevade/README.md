# autoevade

Teleports the player a random horizontal distance when a projectile (arrow, splash potion, or shulker bullet) comes within trigger range.

## Player usage

**Cheat:** `AutoEvade` (category: Combat) — Registered via `ws.rg()` with the `autoevade` setting.

**Settings:**

- `autoevade.scan_range` (number, default 4, min 1, max 20) — Radius for scanning nearby objects for projectiles.
- `autoevade.trigger_distance` (number, default 4, min 1, max 10) — Distance at which a detected projectile triggers evasive teleport.
- `autoevade.evade_distance` (number, default 2, min 1, max 10) — Maximum random horizontal offset (X/Z) for the teleport.

**Behavior:** On each global step, scans nearby objects for projectile textures (`arrow_box`, `_splash`, `shulkerbullet.png`). If a projectile with non-zero velocity is within trigger distance, the player is teleported to a random offset position (Y=2, X/Z in ±evade_distance).

## API

None.

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| AutoEvade | autoevade | Teleports player away from incoming projectiles within trigger range. |
