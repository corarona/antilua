# Camera Roll System

## Summary

Add camera roll support to Antilua — rotating the camera around its look
direction axis. Controllable via player keybindings (Q/E) and Lua API.

## Architecture

Roll stored on `LocalPlayer`, read and applied in `Camera::update()`.

### Data flow

```
Key press → game.cpp checks CAMERA_ROLL_LEFT/RIGHT
         → player->setCameraRoll(roll)
         → Camera::update() reads player->getCameraRoll()
         → rotates absolute up vector around camera direction via quaternion
         → CCameraSceneNode builds look-at matrix with rolled up vector
```

## Implementation

### 1. KeyType enum (`src/client/keys.h`)

Add `CAMERA_ROLL_LEFT`, `CAMERA_ROLL_RIGHT` after existing camera look keys.

### 2. Input handler (`src/client/inputhandler.cpp`)

Register `keymap_camera_roll_left` / `keymap_camera_roll_right` in
`reloadKeybindings()`.

### 3. Default settings (`src/defaultsettings.cpp`)

| Setting | New default | Notes |
|---------|-------------|-------|
| `keymap_drop` | `""` (unbound) | Was Q, now unset |
| `keymap_aux1` | `"SYSTEM_SCANCODE_224"` | Left Ctrl (was E) |
| `keymap_camera_roll_left` | `"SYSTEM_SCANCODE_20"` | KEY_KEY_Q |
| `keymap_camera_roll_right` | `"SYSTEM_SCANCODE_8"` | KEY_KEY_E |
| `camera_roll_speed` | `"90.0"` | degrees/sec |
| `camera_roll_max` | `"45.0"` | degrees |

### 4. LocalPlayer (`src/client/localplayer.h`)

- Add `m_camera_roll` (f32, radians, default 0) in private
- Add `setCameraRoll(f32)` / `getCameraRoll()` in public

### 5. Camera (`src/client/camera.cpp`)

In `Camera::update()`, after computing `abs_cam_up` (line ~412) and
before setting camera node (line ~457), rotate the up vector:

```cpp
f32 roll = player->getCameraRoll();
if (roll != 0.0f) {
    core::vector3df axis = m_camera_direction;
    axis.normalize();
    core::quaternion q(axis, roll);
    core::vector3df abs_cam_up_rolled = abs_cam_up;
    q.rotateVector(abs_cam_up_rolled);
    abs_cam_up = abs_cam_up_rolled;
}
```

This rotates the up vector around the camera's world-space look direction,
producing a mathematically pure roll.

### 6. Game loop (`src/client/game.cpp`)

In `Game::step()`, before `updatePlayerControl()`, handle roll keys:

```
If CAMERA_ROLL_LEFT held:
    roll -= camera_roll_speed * dtime
    roll = max(roll, -camera_roll_max)
If CAMERA_ROLL_RIGHT held:
    roll += camera_roll_speed * dtime
    roll = min(roll, camera_roll_max)
player->setCameraRoll(roll * DEG_TO_RAD)
```

Roll uses degrees internally for the settings (more intuitive), converted
to radians for the camera (matching the math convention).

### 7. Lua API

On `core.localplayer`:

```
get_roll() → number (radians)
set_roll(radians) → nil
```

### 8. AGENTS.md

Document the feature with key bindings and Lua API.

## Files changed

| File | Lines changed |
|------|--------------|
| `src/client/keys.h` | +2 |
| `src/client/inputhandler.cpp` | +2 |
| `src/defaultsettings.cpp` | +4, ~2 |
| `src/client/localplayer.h` | +5 |
| `src/client/camera.cpp` | +12 |
| `src/client/game.cpp` | +20 |
| `src/script/lua_api/l_localplayer.h` | +2 |
| `src/script/lua_api/l_localplayer.cpp` | +28 |
| `AGENTS.md` | +3 |
