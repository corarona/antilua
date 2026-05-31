# Freecam Implementation Plan

Based on CloakV4's working freecam (forked from later Luanti than DF).

## Files to change

### 1. `src/client/localplayer.h` — Add freecam state tracking

**New private members:**
```cpp
bool m_freecam = false;
v3f m_legit_position;
v3f m_legit_speed;
f32 m_legit_yaw = 0.0f;
f32 m_legit_pitch = 0.0f;
```

**New public methods:**
```cpp
v3f getLegitPosition() const { return m_legit_position; }
v3f getLegitSpeed() const { return m_freecam ? m_legit_speed : m_speed; }
f32 getLegitYaw() const { return m_legit_yaw; }
f32 getLegitPitch() const { return m_legit_pitch; }

void setLegitPosition(const v3f &position) {
    if (m_freecam) { m_legit_position = position; }
    else { m_legit_position = position; setPosition(position); }
}
void setLegitSpeed(const v3f &speed) {
    if (m_freecam) { m_legit_speed = speed; }
    else { m_legit_speed = speed; setSpeed(speed); }
}

inline void freecamEnable() { m_freecam = true; }
inline void freecamDisable() {
    m_freecam = false;
    setPosition(m_legit_position);
    setSpeed(m_legit_speed);
}
```

**Modify existing methods:**
```cpp
// setPosition: only update legit_position when not freecaming
inline void setPosition(const v3f &position) {
    m_position = position;
    if (!m_freecam)
        m_legit_position = position;
    m_sneak_node_exists = false;
}

// addPosition: same pattern
inline void addPosition(const v3f &added_pos) {
    m_position += added_pos;
    if (!m_freecam)
        m_legit_position += added_pos;
    m_sneak_node_exists = false;
}
```

### 2. `src/client/localplayer.cpp` — Use legit position/speed

In the `move()` function, use `getLegitPosition()` instead of `m_position` for:
- Standing node detection (already likely uses member)
- Collision detection
- Auto-jump

In `step()`, use `getLegitPosition()` for position retrieval.

Add `getSendSpeed()`:
```cpp
v3f LocalPlayer::getSendSpeed() {
    v3f speed = getLegitSpeed();
    // (existing mod callback integration if present)
    return speed;
}
```

### 3. `src/client/game.cpp` — Freecam lifecycle and input

**Constructor:**
```cpp
g_settings->registerChangedCallback("freecam", &freecamChangedCallback, this);
```

**Destructor:**
```cpp
g_settings->deregisterChangedCallback("freecam", &freecamChangedCallback, this);
```

**`freecamChangedCallback`:**
```cpp
void Game::freecamChangedCallback(const std::string &setting_name, void *data) {
    Game *game = (Game *) data;
    LocalPlayer *player = game->client->getEnv().getLocalPlayer();
    if (g_settings->getBool("freecam")) {
        game->camera->setCameraMode(CAMERA_MODE_FIRST);
        player->freecamEnable();
    } else {
        player->freecamDisable();
    }
    game->updateCameraMode();
}
```

**`readSettings()` or startup:** force reset when entering game:
```cpp
g_settings->setBool("freecam", false);
```

**`allow_noclip`:** include freecam:
```cpp
draw_control->allow_noclip = (m_cache_enable_noclip && client->checkPrivilege("noclip"))
    || g_settings->getBool("freecam");
```

**CAO visibility:** Show player body in first-person during freecam:
```cpp
playercao->setChildrenVisible(g_settings->getBool("freecam")
    || camera->getCameraMode() > CAMERA_MODE_FIRST);
```
(search in game.cpp for `setChildrenVisible` or similar — may be `m_local_player->setVisible`)

**Block camera mode cycling** when freecam is on:
```cpp
if (wasKeyPressed(KeyType::CAMERA_MODE) && !g_settings->getBool("freecam"))
    camera->toggleCameraMode();
```

**Fly/noclip checks** should also pass during freecam:
```cpp
if (client->checkPrivilege("fly") || g_settings->getBool("freecam")) { ... }
if (client->checkPrivilege("noclip") || g_settings->getBool("freecam")) { ... }
```

### 4. `src/client/game_internal.h` — Method declaration

Add to Game class:
```cpp
static void freecamChangedCallback(const std::string &setting_name, void *data);
```
