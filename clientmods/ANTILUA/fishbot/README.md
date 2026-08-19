# fishbot

Automated fishing bot for Mineclonia / VoxeLibre. Uses a state machine to cast, wait for a bite, and reel in. Bites are detected via the bobber's bubble particles (VoxeLibre) or bobber movement (Mineclonia).

## Player usage

### Cheats

| Cheat | Category | Setting | Description |
|-------|----------|---------|-------------|
| FishBot | Bots | `fishbot` | Automated fishing — casts rod, reels in on bite (bubble particles or bobber movement) |

### Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `fishbot.bobber_range` | 10 | Range to detect bobber entity |

### State machine

| State | Description |
|-------|-------------|
| 1 | No bobber — cast the rod (throttled to avoid spam) |
| 2 | Bobber present — wait for it to settle; if it stops moving, advance to state 3 |
| 3 | Bobber settled — wait for a bite (bubble particles near the bobber on VoxeLibre, or bobber movement on Mineclonia); reel in, or recast if the bobber sits on land |
| 4 | Cooldown — wait until bobber is gone, then reset to state 1 |

FishBot auto-equips an enchanted fishing rod (falls back to normal) from the hotbar. Requires Mineclonia/VoxeLibre game.

### Daughter mods

FishBot enables `autodump`, `autoeject`, and `lockview` when active.

## API

None.

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| FishBot | `fishbot` | Automated fishing — casts rod, reels in on bite (bubble particles or bobber movement) |
