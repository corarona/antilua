# fishbot

Automated fishing bot for MineClone (and similar). Uses a state machine to cast, wait for a bite, and reel in.

## Player usage

### Cheats

| Cheat | Category | Setting | Description |
|-------|----------|---------|-------------|
| FishBot | Bots | `fishbot` | Automated fishing — casts rod, waits for bobber movement, reels in |

### Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `fishbot.water_range` | 10 | Range to search for water sources |
| `fishbot.bobber_range` | 10 | Range to detect bobber entity |

### State machine

| State | Description |
|-------|-------------|
| 0 | Cast the fishing rod |
| 1 | Wait — monitor bobber position; if it stops moving, advance to state 2 |
| 2 | Bobber stationary — wait for movement (bite); reel in if bobber moves or if water beneath it disappears |
| 3 | Cooldown — wait until bobber is gone, then reset to state 0 |

FishBot auto-equips an enchanted fishing rod (falls back to normal) from the hotbar. Requires MineClone/IA game.

### Daughter mods

FishBot enables `autodump`, `autoeject`, and `lockview` when active.

## API

None.
