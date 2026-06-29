# Camera Roll Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add auto-reset camera roll (idle timeout → smooth decay to 0) and roll-adapted mouse control (mouse movement respects camera roll) with a configurable mode setting.

**Architecture:** Two independent changes to `game.cpp`: (1) idle tracking + decay logic in the roll key handling section, (2) roll-angle decomposition in the mouse delta → yaw/pitch conversion. Both gated by new settings in `defaultsettings.cpp`.

**Tech Stack:** C++17, IrrlichtMt math (cosf, sinf, f32)

---

### Task 1: Add settings

**Files:**
- Modify: `src/defaultsettings.cpp:378-380`

- [ ] **Add 4 new settings after `camera_roll_max`**

```cpp
settings->setDefault("camera_roll_auto_reset", "true");
settings->setDefault("camera_roll_auto_reset_delay", "3.0");
settings->setDefault("camera_roll_auto_reset_duration", "0.3");
settings->setDefault("camera_roll_adaptive_mouse", "both");
```

- [ ] **Commit**

```bash
git add src/defaultsettings.cpp
git commit -m "feat: add camera roll auto-reset and adaptive mouse settings"
```

---

### Task 2: Add auto-reset state fields to Game class

**Files:**
- Modify: `src/client/game_internal.h:~400`

- [ ] **Add 3 tracking fields after `m_is_paused`**

Use an idle counter (incremented each frame, reset on input) + decay state.

```cpp
// Camera roll auto-reset
f32 m_camera_roll_idle_time = 0.0f;     // seconds since last input
f32 m_camera_roll_at_reset_start = 0.0f;
f32 m_camera_roll_reset_timer = -1.0f;  // -1 = not decaying, 0+ = elapsed decay time
```

- [ ] **Commit**

```bash
git add src/client/game_internal.h
git commit -m "feat: add camera roll auto-reset state fields"
```

---

### Task 3: Track input idle time for auto-reset

**Files:**
- Modify: `src/client/game.cpp:584-631` (main loop, roll handling)
- Modify: `src/client/game.cpp:2174-2221` (updateCameraOrientation)

- [ ] **Increment `m_camera_roll_idle_time` each frame**

In `Game::run()` where `dtime` is available, add before the input section:

```cpp
if (!m_is_paused) {
    m_camera_roll_idle_time += dtime;
}
```

- [ ] **Reset idle timer on mouse movement**

In `Game::updateCameraOrientation()`, inside the existing `if (dist.X != 0 || dist.Y != 0)` block at line 2193, add:

```cpp
if (dist.X != 0 || dist.Y != 0) {
    input->setMousePos(center.X, center.Y);
    m_camera_roll_idle_time = 0.0f;    // <-- add
    if (auto *player = client->getEnv().getLocalPlayer()) {
        player->unlockYaw();
        player->unlockPitch();
    }
}
```

- [ ] **Reset idle timer on roll key press**

Inside the existing `if (roll_left || roll_right)` block (line 609), before the roll math:

```cpp
if (roll_left || roll_right) {
    m_camera_roll_idle_time = 0.0f;  // <-- add
    LocalPlayer *player = client->getEnv().getLocalPlayer();
    // ... existing roll math ...
}
```

- [ ] **Reset idle timer on movement keys**

Before `updatePlayerControl(m_cam_view)` at line 603, add:

```cpp
if (isKeyDown(KeyType::FORWARD) || isKeyDown(KeyType::BACKWARD) ||
    isKeyDown(KeyType::LEFT) || isKeyDown(KeyType::RIGHT) ||
    isKeyDown(KeyType::JUMP) || isKeyDown(KeyType::SNEAK) ||
    isKeyDown(KeyType::AUX1) || isKeyDown(KeyType::DIG) || isKeyDown(KeyType::PLACE)) {
    m_camera_roll_idle_time = 0.0f;
}
```

- [ ] **Commit**

```bash
git add src/client/game.cpp
git commit -m "feat: track input idle time for camera roll auto-reset"
```

---

### Task 4: Implement camera roll auto-reset decay

**Files:**
- Modify: `src/client/game.cpp:605-631` (roll handling block)

- [ ] **After the roll key handling `if` block (closing `}` at ~line 631), add auto-reset logic**

At line ~632, before `updatePauseState()`:

```cpp
// Camera roll auto-reset
if (g_settings->getBool("camera_roll_auto_reset")) {
    LocalPlayer *player = client->getEnv().getLocalPlayer();
    f32 current_roll = player->getCameraRoll();
    if (current_roll != 0.0f) {
        f32 delay = g_settings->getFloat("camera_roll_auto_reset_delay");
        f32 duration = g_settings->getFloat("camera_roll_auto_reset_duration");

        // Any input cancels idle and any in-progress decay
        bool any_input = (roll_left || roll_right) ||
            isKeyDown(KeyType::FORWARD) || isKeyDown(KeyType::BACKWARD) ||
            isKeyDown(KeyType::LEFT) || isKeyDown(KeyType::RIGHT) ||
            isKeyDown(KeyType::JUMP) || isKeyDown(KeyType::SNEAK) ||
            isKeyDown(KeyType::AUX1) || isKeyDown(KeyType::DIG) || isKeyDown(KeyType::PLACE);

        if (any_input) {
            m_camera_roll_idle_time = 0.0f;
            m_camera_roll_reset_timer = -1.0f;
        } else if (m_camera_roll_idle_time >= delay) {
            // Idle long enough — start or continue smooth decay to 0
            if (m_camera_roll_reset_timer < 0.0f) {
                m_camera_roll_reset_timer = 0.0f;
                m_camera_roll_at_reset_start = current_roll;
            }
            m_camera_roll_reset_timer += dtime;
            f32 t = fmin(m_camera_roll_reset_timer / duration, 1.0f);
            f32 smooth = t * t * (3.0f - 2.0f * t); // smoothstep
            f32 new_roll = m_camera_roll_at_reset_start * (1.0f - smooth);
            player->setCameraRoll(new_roll);
            if (t >= 1.0f) {
                player->setCameraRoll(0.0f);
                m_camera_roll_reset_timer = -1.0f;
            }
        }
    } else {
        m_camera_roll_reset_timer = -1.0f;
    }
}
```

`roll_left` and `roll_right` are already declared in scope above (lines 607-608).

- [ ] **Commit**

```bash
git add src/client/game.cpp
git commit -m "feat: implement camera roll auto-reset with smooth decay"
```

---

### Task 5: Implement roll-adapted mouse control

**Files:**
- Modify: `src/client/game.cpp:2190-2191` (`updateCameraOrientation`)

- [ ] **Replace the yaw/pitch update lines with roll-adaptive logic**

The key insight: the mouse delta (dx, dy) in screen space is rotated by
roll θ relative to the camera's yaw/pitch response axes. The standard
response (-dx, dy) is rotated by -θ so "up" aligns with the screen.

Replace lines 2190-2191:

```cpp
cam->camera_yaw   -= dist.X * m_cache_mouse_sensitivity * sens_scale;
cam->camera_pitch += dist.Y * m_cache_mouse_sensitivity * sens_scale;
```

With:

```cpp
f32 dx = (f32)dist.X * m_cache_mouse_sensitivity * sens_scale;
f32 dy = (f32)dist.Y * m_cache_mouse_sensitivity * sens_scale;

std::string mode = g_settings->get("camera_roll_adaptive_mouse");
if (mode == "both" || mode == "pitch") {
    if (auto *player = client->getEnv().getLocalPlayer()) {
        f32 roll = player->getCameraRoll();
        if (roll != 0.0f) {
            f32 cos_r = cosf(roll);
            f32 sin_r = sinf(roll);
            if (mode == "both") {
                // Both axes: rotate standard (-dx, dy) response by -θ
                cam->camera_yaw   -= dx * cos_r - dy * sin_r;
                cam->camera_pitch += dx * sin_r + dy * cos_r;
            } else {
                // Pitch only: only vertical channel adapts
                cam->camera_yaw   -= dx;
                cam->camera_pitch += dy * cos_r;
            }
            goto roll_applied;
        }
    }
}
// Fallback: no adaptation or zero roll
cam->camera_yaw   -= dx;
cam->camera_pitch += dy;
roll_applied: ;
```

The `goto` avoids duplicating the fallback code. At θ=0, cos_r=1, sin_r=0
so `both` mode gives the exact same result as the fallback.

Note on the "both" formula: at θ=+90°, mouse up (dy < 0) contributes
`-dy * sin_r = -dy` to yaw → yaw decreases → looking right (same as
mouse right at θ=0). Mouse right (dx > 0) contributes `dx * sin_r = dx`
to pitch → pitch increases → looking down (screen right = world down
at roll=90°). ✓

- [ ] **Commit**

```bash
git add src/client/game.cpp
git commit -m "feat: implement roll-adapted mouse control"
```

---

### Task 6: Build and verify

- [ ] **Build the project**

```bash
cmake --build build -j$(nproc)
```

- [ ] **Run unit tests**

```bash
./bin/antilua --run-unittests
```

- [ ] **Run integration tests**

```bash
./util/ci/run_al_tests.sh
```

- [ ] **Commit any build fixes**

```bash
git add -A
git commit -m "fix: address build issues for camera roll enhancements"
```

---

### Task 7: Document new settings in AGENTS.md

**Files:**
- Modify: `AGENTS.md`

- [ ] **Add new settings documentation**

Find the camera roll section in AGENTS.md and add the 4 new settings
after the existing `camera_roll_speed` / `camera_roll_max` table:

```markdown
| `camera_roll_auto_reset` | true | Auto-reset camera roll to 0 when idle |
| `camera_roll_auto_reset_delay` | 3.0 | Seconds of input idle before reset starts |
| `camera_roll_auto_reset_duration` | 0.3 | Duration of smooth roll decay |
| `camera_roll_adaptive_mouse` | both | `both` or `pitch` — whether mouse movement adapts to camera roll |
```

- [ ] **Commit**

```bash
git add AGENTS.md
git commit -m "docs: document camera roll enhancement settings"
```
