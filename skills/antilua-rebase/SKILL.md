# Antilua Rebase Skill

Rebase the Antilua fork onto upstream `luanti/master` with minimal pain.

## Before you start

```sh
git branch backup/main-before-rebase
git checkout -b df-rebased main
```

## Conflict patterns

Every conflict in the 488-commit rebase falls into one of these patterns:

### 1. Gamepad key bindings (`defaultsettings.cpp`)

**Conflict:** luanti/master added gamepad bindings (`|GAMEPAD_AXIS_PLUS_1`).
DF commits replace them with plain scancodes + camera roll comments.

**Rule:** Keep the gamepad bindings AND add the DF key reassignments.

```
// Keep:  settings->setDefault("keymap_drop", "SYSTEM_SCANCODE_20|GAMEPAD_BUTTON_12");
// Add:   settings->setDefault("keymap_camera_roll_left", "SYSTEM_SCANCODE_20");
```

### 2. Camera look keys (`keys.h`, `inputhandler.cpp`, `defaultsettings.cpp`)

**Conflict:** luanti/master has `CAMERA_YAW_LEFT/RIGHT/PITCH_UP/DOWN`. DF
commits remove them when adding Antilua-specific keys.

**Rule:** NEVER remove camera look enums or bindings. Add Antilua keys
alongside. The camera look code uses `ShaderFeatures` API in master
(not the old positional `getShader` call).

### 3. Joystick frustum (`game.cpp`)

**Conflict:** DF uses `input->joystick.getAxisWithoutDead(JA_FRUSTUM_*)`.
Master doesn't have `InputHandler::joystick` as a public member.

**Rule:** Delete `input->joystick.*` calls. Camera rotation axis scaling
is already handled by the `camera_rotation_actions` array in
`inputhandler.cpp`.

### 4. Player direction keys (`player.cpp`, `player.h`)

**Conflict:** Auto-merger often drops `direction_keys` field from
`PlayerControl`.

**Rule:** Add `u8 direction_keys = 0;` alongside `movement_speed` and
`movement_direction`.

### 5. `keyIsDown` → `keyWasDown` (`inputhandler.h`)

**Conflict:** DF renamed `keyIsDown` to `keyWasDown` but master already has
`keyWasDown`. The DF `setKeypress()`/`unsetKeypress()` methods reference
`keyIsDown` which doesn't exist.

**Rule:** Replace `keyIsDown` with `keyWasDown`.

### 6. `Game::startup` error handling (`game.cpp`)

**Conflict:** DF uses `error_message = "..."` (local variable). Master
passes `GameErrorData &errordata`.

**Rule:** Replace `error_message = "..."` with
`errordata.setError("...")`.

### 7. Raw packet API (`client.cpp`)

**Conflict:** DF uses `pkt->getString(0)`. Master has
`pkt->readRawString(len)` and `pkt->seek(pos)`.

**Rule:** Replace with:
```cpp
pkt->seek(0);
payload = pkt->readRawString(size);
```
Two occurrences (incoming + outgoing intercept).

### 8. OpenGL 1.4 / FFP

~10–15 commits touching 30+ files. Cannot be cleanly rebased because
upstream IrrlichtMt and shader systems changed significantly.

**Rule:** SKIP these commits. Re-implement as a single clean commit on
top after the rebase. Remove `ffp_isEnabled()`, `ffp_blendDayNight()`
references during conflict resolution when they appear in non-FFP commits.

## Post-rebase checklist

The build will fail with these. Fix in order:

```sh
# 1. Missing files from DF that master doesn't have
git show backup/main-before-rebase:builtin/client/misc.lua > builtin/client/misc.lua
git show backup/main-before-rebase:builtin/common/settings/shader_warning_component.lua > builtin/common/settings/shader_warning_component.lua

# 2. Raw packet API (if not already fixed during rebase)
#    grep for pkt->getString in client.cpp

# 3. FFP references (if any non-FFP commits reference ffp functions)
#    grep for ffp_ in src/

# 4. m_enable_shaders member (if setShadersEnabled exists but member doesn't)
#    grep content_cao.h for setShadersEnabled — add bool m_enable_shaders = true;
```

## Recovery

```sh
git rebase --abort                          # start over
git show backup/main-before-rebase:path/to/file > path/to/file  # restore one file
```
