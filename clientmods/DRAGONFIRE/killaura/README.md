# killaura

Combat automation: auto-attack players (Killaura), auto-attack mobs (Mobaura), repulsion field (ForceField), and in-air position preservation (AirHead). Includes friend/enemy list management.

## Player usage

### Cheats

| Cheat | Category | Setting | Description |
|-------|----------|---------|-------------|
| Killaura | Combat | `killaura` | Auto-punch nearby players (respects friend/enemy lists) |
| Mobaura | Combat | `mobaura` | Auto-punch nearby mobs (detected by mesh name) |
| ForceField | Combat | `forcefield` | Repulsion field effect |
| AirHead | Player | `airhead` | Teleport back to a safe spot when flying into air |

### Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `killaura.hph` | 1 | Hits per hit (1–10) |
| `killaura.hit_y` | -0.1 | Vertical velocity offset on each hit |
| `killaura.range` | 10 | Attack range |
| `killaura.attack_all` | false | Attack all players (not just enemies) |
| `mobaura.range` | 10 | Mob attack range |

### Chat commands

| Command | Description |
|---------|-------------|
| `/list friend [names]` | Configure friend list (friends are not attacked) |
| `/list enemies [names]` | Configure enemy list (enemies are always attacked) |

## API

```lua
killaura = {
	hph = 1,
	hps = 20,
	hit_y = -0.1,
}
```

### `killaura.get(key)`

Get a killaura setting value by key, falling back to the default from the `killaura` table.

**Parameters:**
- `key` — `string` setting name (e.g. `"hph"`, `"hit_y"`, `"range"`)

**Returns:** `number`

### `killaura.punch_object(obj)`

Punch an object multiple times (`hph` times) while preserving the player's original velocity and position.

**Parameters:**
- `obj` — `ObjectRef` to punch

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| Killaura | `killaura` | Auto-punch nearby players (respects friend/enemy lists) |
| Mobaura | `mobaura` | Auto-punch nearby mobs (detected by mesh name) |
| ForceField | `forcefield` | Repulsion field effect |
| AirHead | `airhead` | Teleport back to a safe spot when flying into air |
