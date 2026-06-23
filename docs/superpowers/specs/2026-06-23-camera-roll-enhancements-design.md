# Camera Roll Enhancements: Auto-Reset and Roll-Adapted Mouse

## Summary

Two enhancements to the existing camera roll system (2025-06-19 spec):

1. **Auto-reset** — a setting that smoothly resets camera roll to 0 when the
   player stops providing input for a few seconds
2. **Roll-adapted mouse** — mouse movement adapts to camera roll so that mouse
   "up" always moves the view toward the camera's apparent up direction

## Settings

Added to `src/defaultsettings.cpp`:

| Setting | Default | Description |
|---------|---------|-------------|
| `camera_roll_auto_reset` | `true` | Enable auto-reset of camera roll |
| `camera_roll_auto_reset_delay` | `3.0` | Seconds of input idle before reset starts |
| `camera_roll_auto_reset_duration` | `0.3` | Duration of smooth lerp back to 0 |
| `camera_roll_adaptive_mouse` | `both` | `both` or `pitch` — mouse adaptation mode |

## Feature 1: Auto-Reset

### Idle detection

Each frame, `Game::updateCameraOrientation()` and keyboard handling in
`Game::step()` track whether any input was received:

- **Keyboard movement keys** (forward/back/left/right/jump/sneak/aux1/dig/place)
- **Mouse movement** (change in `getMousePos()` since last frame)
- **Camera roll keys** (Q/E)
- **Camera look keys** (if bound: yaw_left/right, pitch_up/down)

If none detected for `camera_roll_auto_reset_delay` seconds AND
`player->getCameraRoll() != 0`, a decay timer begins.

### Decay mechanics

```
When idle_time >= delay AND roll != 0:
    if reset_start_time == 0:
        reset_start_time = now
        roll_at_start = current_roll
    progress = min((now - reset_start_time) / duration, 1.0)
    current_roll = lerp(roll_at_start, 0, ease_in_out(progress))
    player->setCameraRoll(current_roll)
    if progress >= 1.0:
        roll = 0  // done
```

On any input during decay:
- Cancel the decay (`reset_start_time = 0`)
- Player takes over at current (partially decayed) roll value

A simple `ease_in_out(progress) = progress * progress * (3 - 2 * progress)`
(smoothstep) for natural feel.

### State tracking

Added to `Game` class in `game.h` / `game.cpp`:

```cpp
f32 m_camera_roll_at_reset_start = 0.0f;
f64 m_camera_roll_reset_start_time = 0.0;  // 0 = not resetting
```

Input time tracking already available via `m_last_time_made_noise`-style
mechanism, or add a dedicated `m_last_input_time`. Mouse idle is detected
by comparing `input->getMousePos()` against last frame's position.

## Feature 2: Roll-Adapted Mouse

### Math

Single change in `Game::updateCameraOrientation()` (`game.cpp` ~line 2174).

Let θ = camera roll in radians, (dx, dy) = mouse delta from center, sens =
effective sensitivity.

**`both` mode** (screen-space camera — both axes adapt):

```
Δyaw   = sens * (-dx * cos(θ) + dy * sin(θ))
Δpitch = sens * ( dx * sin(θ) + dy * cos(θ))
```

- θ=0: identical to current behavior
- θ=90°: mouse up → yaw right, mouse right → pitch down

**`pitch` mode** (only vertical adapts, horizontal stays world-yaw):

```
Δyaw   = sens * (-dx + dy * sin(θ))
Δpitch = sens * (dy * cos(θ))
```

- θ=0: identical to current behavior  
- θ=90°: mouse up → yaw right (via sin(θ) coupling), mouse right → unchanged
  world-yaw behavior
- This mode is more conservative; useful for users who find full screen-space
  camera disorienting

### No change to pitch wraparound

The pitch wraparound feature continues to work as before — roll-adapted mouse
just changes how the mouse delta is distributed to yaw/pitch, not how pitch
is clamped or wrapped.

## Files changed

| File | Lines changed |
|------|--------------|
| `src/defaultsettings.cpp` | +4 |
| `src/client/game.h` | +4 (reset state fields) |
| `src/client/game.cpp` | ~25 (mouse delta rotation + idle tracking + reset logic) |
| `AGENTS.md` | +5 (document settings) |
