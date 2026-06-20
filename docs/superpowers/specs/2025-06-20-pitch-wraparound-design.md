# Pitch Wraparound System

## Summary

Allow the player's camera pitch to pass beyond ±90°, enabling full
vertical rotation for loopings and inverted flight. Controlled by a
`pitch_wraparound` setting (default off).

## Architecture

The only pitch clamp in the engine is in `Game::updateCameraOrientation()`:

```cpp
cam->camera_pitch = rangelim(cam->camera_pitch, -90, 90);
```

Everything downstream already handles arbitrary pitch values:
- `LocalPlayer::setPitch()` stores unconditionally (no clamp)
- Camera rendering rotates the head node by the pitch value directly
- Forward vector computation uses `sin/cos` which handle any angle
- Server wraps pitch with `modulo360f` — no ±90 clamp

The change replaces this clamp with a conditional: either clamp to ±90
(setting off) or wrap to [-180, 180] (setting on).

## Implementation

### 1. Setting (`src/defaultsettings.cpp`)

Add `pitch_wraparound = false` near `camera_roll_max`.

### 2. UI (`builtin/settingtypes.txt`)

Add entry near `camera_roll_max`:

```
pitch_wraparound (Pitch wraparound) bool false
```

### 3. Game loop (`src/client/game.cpp`)

Replace `rangelim(cam->camera_pitch, -90, 90)` with:

```cpp
if (g_settings->getBool("pitch_wraparound"))
    cam->camera_pitch = wrapDegrees_180(cam->camera_pitch);
else
    cam->camera_pitch = rangelim(cam->camera_pitch, -90, 90);
```

`wrapDegrees_180()` already exists in `src/util/numeric.h` and wraps
any angle to [-180, 180].

### 4. AGENTS.md

Document the feature.

## Behavior

| pitch value | Look direction |
|-------------|---------------|
| 0° | Forward, horizontal |
| -90° | Straight up |
| -180° / 180° | Backward, horizontal (inverted) |
| 90° | Straight down |

A complete loop is 360° of pitch change: 0 → -90 → -180 → -90 → 0.

## Known limitations

**Gimbal lock at exact vertical**: When pitch is exactly -90° or 90° and
the camera up vector is parallel to the look direction, the cross product
that computes the camera's right vector fails. This causes a momentary
visual flip that resolves instantly once the camera moves past vertical.
In airplane mode, the player is banked during a loop so the up vector is
not parallel. Fixable in V2 by maintaining the camera's right vector
across frames.

## Files changed

| File | Change |
|------|--------|
| `src/client/game.cpp` | ±3 |
| `src/defaultsettings.cpp` | +1 |
| `builtin/settingtypes.txt` | +3 |
| `AGENTS.md` | +3 |
