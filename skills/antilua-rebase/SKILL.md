# Antilua Rebase Skill

Rebase the Antilua fork onto upstream `luanti/master`.

## Before you start

```sh
git branch backup/before-rebase
git checkout -b df-rebased main
```

Use a single interactive rebase for all squash work. Don't do multiple
sequential rebases — the commit SHA changes make it impossible to maintain
correct line numbers.

## Key rebase invariants

Every conflict in the 488-commit rebase falls into one of these patterns:

### 1. Gamepad key bindings (`defaultsettings.cpp`)

luanti/master added gamepad bindings (`|GAMEPAD_AXIS_PLUS_1`). DF commits
replace them with plain scancodes + camera roll comments.

**Keep the gamepad bindings AND add the DF key reassignments.**

```
// Keep:  settings->setDefault("keymap_drop", "SYSTEM_SCANCODE_20|GAMEPAD_BUTTON_12");
// Add:   settings->setDefault("keymap_camera_roll_left", "SYSTEM_SCANCODE_20");
```

### 2. Camera look keys (`keys.h`, `inputhandler.cpp`, `defaultsettings.cpp`)

luanti/master has `CAMERA_YAW_LEFT/RIGHT/PITCH_UP/DOWN`. DF commits remove
them when adding Antilua-specific keys.

**NEVER remove camera look enums.** Add Antilua keys alongside. In `keys.h`,
camera enums go in the main section, Antilua enums at the
`// DragonfireClient-specific keys` end section.

### 3. Joystick frustum (`game.cpp`)

DF uses `input->joystick.*`. Master does not have this as a public member.
**Delete `input->joystick.*` calls** — camera rotation axis scaling is
handled by the `camera_rotation_actions` array in `inputhandler.cpp`.

### 4. Player direction keys (`player.cpp`, `player.h`)

Auto-merger often drops `direction_keys` from `PlayerControl`.
**Add `u8 direction_keys = 0;`** alongside `movement_speed` and
`movement_direction`.

In `l_localplayer.cpp`, keep BOTH the master's control fields (`movement_x/y`,
`c.up`) AND the DF polar fields (`movement_speed`, `direction_keys`).

### 5. `keyIsDown` → `keyWasDown` (`inputhandler.h`)

DF `setKeypress()`/`unsetKeypress()` reference `keyIsDown` which doesn't
exist in master. **Replace `keyIsDown` with `keyWasDown`.**

### 6. `Game::startup` error handling (`game.cpp`)

DF uses `error_message = "..."`. Master uses `errordata.setError("...")`.
**Replace the former with the latter.**

### 7. Raw packet API (`client.cpp`)

DF uses `pkt->getString(0)`. Master has `pkt->readRawString(len)`.
**Replace both occurrences** (incoming + outgoing intercept):

```cpp
pkt->seek(0);
payload = pkt->readRawString(size);
```

### 8. `l_get_object` stack issue (`l_localplayer.cpp`)

The luanti/master `get_object` function pushes a HUD element table AFTER
the `ClientObjectRef` userdata, then `return 1` — the HUD table overwrites
the ref on the Lua stack. **Remove the HUD table push** — the function
should only return the `ClientObjectRef`.

```cpp
// WRONG — returns HUD table instead of ClientObjectRef
ClientObjectRef::create(L, cao);
lua_newtable(L);  // ← THIS buries the ref
// ... fill table ...
return 1;         // ← returns the table, ref is lost
```

## Squashing fix-up chains

After a successful rebase, squash adjacent fix-up commits to make future
rebases easier. Use `GIT_SEQUENCE_EDITOR` with sed:

```sh
# Example: squash lines 22-23 into 21, 41 into 40, etc.
GIT_SEQUENCE_EDITOR='sed -i "22,23s/^pick/fixup/;41s/^pick/fixup/"' \
  git rebase -i b84aee2bf
```

For reordering commits (e.g., moving a fix-up to be adjacent to its
feature), use a shell script as the sequence editor:

```sh
cat > /tmp/rebase-editor.sh << 'EOF'
#!/bin/sh
file="$1"
# Swap lines N and M
sed -n 'Mp' "$file" > /tmp/lm
sed -n 'Np' "$file" > /tmp/ln
sed -i 'Mc\ '"$(cat /tmp/lm)" "$file"
sed -i 'Nc\ '"$(cat /tmp/ln)" "$file"
EOF
GIT_SEQUENCE_EDITOR=/tmp/rebase-editor.sh git rebase -i b84aee2bf
```

Always build and run tests after squashing:

```sh
cmake --build build -j3 && ./bin/antilua --run-unittests && ./util/ci/run_al_tests.sh
```

## Incorporating new commits from old main

After rebasing, if `main` has new commits (e.g., from a merged PR) that
weren't part of the rebase:

```sh
# The rebased branch is on rebase-and-compact
git checkout rebase-and-compact
# Cherry-pick each new commit from the old main
for c in $(git log main --not rebase-and-compact --reverse --format=%H); do
  git cherry-pick $c
done
# Reset main to this new HEAD
git checkout -B main rebase-and-compact
git push --force-with-lease
```

## Post-rebase build fix checklist

Build will fail with these errors. Fix in order:

```sh
# 1. Missing builtin/client/misc.lua (DF file not in upstream)
git show backup/before-rebase:builtin/client/misc.lua > builtin/client/misc.lua

# 2. Raw packet API (grep for pkt->getString in client.cpp)
```

Build w/ zero warnings after fixes:

```sh
cmake --build build -j3 2>&1 | grep -E "error:|warning:" | grep -v "Wno-" | grep -v "unknown-pragmas"
# Expect no output
```

## Recovery

```sh
git rebase --abort
git checkout backup/before-rebase  # full recovery
git show backup/before-rebase:path/to/file > path/to/file  # single file
```
