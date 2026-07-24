# Combat cheats

Killaura, AutoEvade, and AutoCombatLog — client-side combat enhancements.

## killaura

Auto-attack nearby entities with configurable targeting. Supports player enemies, all players (except friends), mobs, and combined modes. Includes friend/enemy list management via settings formspec.

## AutoEvade

Auto-evade incoming projectiles and maintain distance from enemy players. The head (1 block above player position) always stays in air — no teleporting into solid blocks.

### Cheats

| Cheat | Category | Setting | Description |
|-------|----------|---------|-------------|
| Killaura | Combat | `killaura` | Auto-punch nearby targets (configurable mode) |
| AutoEvade | Combat | `auto_evade` | Auto-evade projectiles and enemy players |
| AutoCombatLog | Player | `autoclog` | Disconnect and teleport randomly when other players are detected nearby |

### Killaura targeting modes

| Mode | Description |
|------|-------------|
| `players_enemies` | Attack only players in enemy list (default) |
| `players_all` | Attack all players except friends |
| `mobs` | Attack hostile mobs (mesh-based detection) |
| `all` | Attack enemies + mobs |

### Killaura settings

| Setting | Default | Description |
|---------|---------|-------------|
| `killaura.hph` | 1 | Hits per hit (1–10) |
| `killaura.hit_y` | -0.1 | Vertical velocity offset on each hit |
| `killaura.range` | 4.5 | Attack range (1–30) |
| `killaura.target_mode` | `players_enemies` | Targeting mode |

### Target HUD

When killaura is active, a text HUD appears in the top-right corner showing the closest valid target:
```
► Zombie   ♥ 14/20   ███████░░░   6.2m
```

Displays: target name, current/max HP, ASCII health bar (10 segments), distance. Color-coded by health (green > 60%, yellow > 30%, red ≤ 30%). HUD clears when no targets are nearby.

### AutoEvade settings

| Setting | Default | Description |
|---------|---------|-------------|
| `auto_evade.range` | 8 | Evade scan range (3–20) |
| `auto_evade.player_min_distance` | 6 | Min distance from non-friend players (3–20) |
| `auto_evade.cooldown` | 0.3 | Seconds between evades (0.1–2) |
| `auto_evade.evade_projectiles` | true | Evade incoming projectiles |
| `auto_evade.evade_players` | true | Evade enemy player proximity |

### Friend/enemy list

Open the Killaura cheat settings in the cheat menu to manage friend and enemy lists via formspec. Friends are never attacked in any mode. Enemies are always attacked in `players_enemies` and `all` modes. AutoEvade never evades friends.

## AutoCombatLog

Disconnects and teleports randomly when other players are detected within range. A combat-evasion cheat for avoiding unwanted encounters.

### AutoCombatLog settings

| Setting | Default | Description |
|---------|---------|-------------|
| `autoclog.detect_range` | 270 | Player detection range (10–500) |

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
