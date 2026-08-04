# autoeat

Automatically eats food when the player's hunger drops below a configurable threshold. Integrates with the `autodupe` mod when only one food type is available.

## Player usage

**Cheat:** `AutoEat` (category: Player) — Toggles auto-eating via the `autoeat` setting.

**Settings:**

- `autoeat` (bool) — Master toggle.
- `autoeat_cooldown` (number, default 0.5) — Minimum seconds between eats.
- `autoeat_hunger` (number, default 9) — Hunger threshold; eat when below this value. The mod reads the `hbhunger_icon.png` HUD element to determine current hunger (falls back to 20 if not found).

## API

All exported on the global `autoeat` table.

- `autoeat.lock` (bool) — Lock flag; when `true` the globalstep skips eating. Set by the autodupe integration.
- `autoeat.eat()` — Finds the first food item in the main inventory, wields it, and activates it. If only one food type is present and `autodupe` exists, delegates to `autodupe.needed()` instead.
- `autoeat.get_hunger()` → number — Returns the player's current hunger level, tracked by intercepting server HUDADD/HUDCHANGE packets for the hunger bar (or 20 as fallback).

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| AutoEat | autoeat | Automatically eats food when hunger drops below configurable threshold. |
