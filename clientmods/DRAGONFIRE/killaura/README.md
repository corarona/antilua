# killaura

Auto-attack nearby entities with configurable targeting. Supports player enemies, all players (except friends), mobs, and combined modes. Includes friend/enemy list management via settings formspec.

## Player usage

### Cheats

| Cheat | Category | Setting | Description |
|-------|----------|---------|-------------|
| Killaura | Combat | `killaura` | Auto-punch nearby targets (configurable mode) |

### Targeting modes

| Mode | Description |
|------|-------------|
| `players_enemies` | Attack only players in enemy list (default) |
| `players_all` | Attack all players except friends |
| `mobs` | Attack hostile mobs (mesh-based detection) |
| `all` | Attack enemies + mobs |

### Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `killaura.hph` | 1 | Hits per hit (1–10) |
| `killaura.hit_y` | -0.1 | Vertical velocity offset on each hit |
| `killaura.range` | 10 | Attack range |
| `killaura.target_mode` | `players_enemies` | Targeting mode |

### Friend/enemy list

Open the Killaura cheat settings in the cheat menu to manage friend and enemy lists via formspec. Friends are never attacked in any mode. Enemies are always attacked in `players_enemies` and `all` modes.

## API

```lua
killaura = {
	hph = 1,
	hit_y = -0.1,
}
```

### `killaura.get(key)`

Get a killaura setting value by key, falling back to the default.

### `killaura.punch_object(obj)`

Punch an object multiple times (`hph` times) while preserving the player's original velocity and position.

**Parameters:**
- `obj` — `ObjectRef` to punch
