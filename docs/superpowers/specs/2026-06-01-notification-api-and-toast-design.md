# Centralized Notification API & Toast Notifications

**Date:** 2026-06-01
**Status:** Design approved, pending implementation

## Overview

Replace ad-hoc `ws.dcm()` (display_chat_message) calls with a structured
`ws.notify()` API, add visual toast notifications for cheat toggles, and
migrate all cheat-related feedback messages.

## Architecture

Two components with a well-defined Lua↔C++ boundary:

```
Lua side (wasplib)
  ws.notify(text, type, opts)          -- centralized API
  ws.notify_cheat(name, enabled)       -- convenience for toggles
  ws.set_notify_handler(func)          -- override for testing
  ↓ calls
C++ side (ToastManager)
  core.show_toast(text, type)          -- Lua binding
  → ToastManager::addToast()
  → ToastManager::update(dtime)
  → ToastManager::draw(driver, dtime)  -- called from Game::drawScene()
```

## Lua API (`clientmods/DRAGONFIRE/wasplib/notification.lua`)

### Types (constants on `ws`)

| Constant | Value | Chat prefix | Toast color |
|----------|-------|-------------|-------------|
| `ws.NOTIFY_INFO` | `"info"` | `[*]` blue | dark blue-gray bg |
| `ws.NOTIFY_SUCCESS` | `"success"` | `[+]` green | dark green bg |
| `ws.NOTIFY_WARNING` | `"warning"` | `[?]` yellow | dark orange bg |
| `ws.NOTIFY_ERROR` | `"error"` | `[!]` red | dark red bg |
| `ws.NOTIFY_CHEAT_ON` | — | `[+]` green | dark green bg |
| `ws.NOTIFY_CHEAT_OFF` | — | `[-]` gray | dark gray bg |

### Functions

```lua
-- Core: send notification to chat + toast
ws.notify(text, [type="info"], [opts={toast=true}])
  -- Falls back to core.display_chat_message if core.show_toast unavailable

-- Convenience: cheat toggle notification
ws.notify_cheat(cheat_name, enabled)
  -- Calls ws.notify("Cheat enabled", "success") or ws.notify("Cheat disabled", "info")

-- Override handler for testing/customization
ws.set_notify_handler(func(text, type, opts))
  -- Pass nil to restore default handler
```

## Cheat Lifecycle Integration (`init.lua`)

### Return-value convention change in `ws.globalhacktemplate()`

Changed from `return true = abort` to standard Lua idiom:

| `on_start` return | Meaning |
|-------------------|---------|
| `nil` / no return | Success — show "enabled" toast |
| `true` | Success — show "enabled" toast |
| `false` | Failure — show error toast with default message |
| `false, "reason"` | Failure — show error toast with "reason" |

### New lifecycle logic

```lua
local ok, msg = def.on_start(def)
if ok ~= false then
    ws.notify_cheat(def.name, true)
    ws.set_bool_bulk(def.daughters, true)
    ghwason[setting] = true
else
    ws.notify(msg or (def.name .. " failed to activate"), "error")
    minetest.settings:set_bool(setting, false)
end
```

And on deactivation:

```lua
ghwason[setting] = false
ws.set_bool_bulk(def.daughters, false)
ws.notify_cheat(def.name, false)
def.on_stop(def)
```

## C++ ToastManager (`src/gui/toastManager.h/cpp`)

### Data structures

```cpp
enum class ToastType { INFO, SUCCESS, WARNING, ERROR };

struct Toast {
    std::wstring text;
    ToastType type;
    float elapsed = 0.0f;        // seconds since creation
    float duration = 3.0f;       // total display lifetime
    float fade_start = 2.0f;     // when alpha fade begins
};
```

### Class interface

```cpp
class ToastManager {
public:
    void addToast(const std::wstring &text, ToastType type);
    void update(float dtime);
    void draw(video::IVideoDriver *driver);

    // Configuration (via settings)
    void setPosition(v2s32 pos);
    void setMaxToasts(int n);
    void clear();

private:
    std::vector<Toast> m_toasts;
    v2s32 m_position;            // default: screen center top
    gui::IGUIFont *m_font = nullptr;
    int m_max_toasts = 5;
    s32 m_toast_width = 400;
    s32 m_toast_height = 30;
    s32 m_padding = 10;
};
```

### Rendering behavior

- Default position: top-center of screen (`screen.Width/2 - toast_width/2, 10`)
- Toasts stack downward from the origin, each separated by `m_padding`
- Each toast: rounded rect (semi-transparent dark bg) + white text
- Fade: alpha lerps from 255→0 over the last 1.0s of the 3.0s lifetime
- Max 5 visible toasts; oldest is removed when over capacity
- `update()` advances timers and removes expired toasts
- `draw()` calls `update()` then renders

### Integration points (minimal glue)

1. **`src/client/client.h`** — add `ToastManager m_toast_manager;` member + getter
2. **`src/client/game.cpp`** — in `drawScene()`, after existing overlays:
   `m_client->getToastManager().draw(driver, dtime);`
3. **`src/script/lua_api/l_client.cpp`** — new binding:
   ```cpp
   static int l_show_toast(lua_State *L);
   // API_FCT(show_toast)
   ```
4. **CMakeLists.txt** — add `src/gui/toastManager.cpp` to source list

### Toast type → color mapping

| Type | Background color | Text color |
|------|-----------------|------------|
| INFO | `SColor(200, 30, 40, 60)` | `SColor(255, 255, 255, 255)` |
| SUCCESS | `SColor(200, 20, 60, 30)` | `SColor(255, 255, 255, 255)` |
| WARNING | `SColor(200, 60, 40, 10)` | `SColor(255, 255, 255, 255)` |
| ERROR | `SColor(200, 60, 20, 20)` | `SColor(255, 255, 255, 255)` |

## Migration of `ws.dcm()` calls

### Automatic (via lifecycle hook)
~15 toggle-feedback messages in cheat `on_start`/`on_stop` handlers (e.g.,
"PlaceOn started", "Multiscaff stopped") — **remove**, replaced by auto toast.

### Convert to `return false, "msg"`
`basic_moves/autofly.lua` — `ws.dcm('Select a poi first.'); return true`
→ `return false, "Select a poi first."`

`place/init.lua` — similar error messages in `on_start` that abort activation.

### Convert to `ws.notify()` (chat + toast)
- `mclminer/init.lua` — `ws.dcm("LAVAAA")` → `ws.notify("LAVAAA", "warning")`
- `fishbot/init.lua` — compatibility errors → `ws.notify(..., "error")`
- `sbots/init.lua` — `ws.dcm("Another bot is active.")` → `ws.notify(..., "warning")`
- `invsaver/init.lua` — `ws.dcm("almost dead...")` → `ws.notify(..., "error")`

### Convert to `ws.notify(..., {toast=false})` (chat-only)
- Chat command feedback: constraint positions, digcyl commands, POI operations,
  nodelist management, devtool findings — useful as chat messages but don't
  need a visual toast popup.

### Keep as-is
- `ws.dcm()` calls unrelated to user notifications (e.g., debugging output)
  remain as `ws.dcm()`.

## Files changed

### New files
- `clientmods/DRAGONFIRE/wasplib/notification.lua` — Lua notification API
- `src/gui/toastManager.h` — ToastManager class declaration
- `src/gui/toastManager.cpp` — ToastManager implementation

### Modified files
- `clientmods/DRAGONFIRE/wasplib/init.lua` — load notification.lua, update lifecycle hooks
- `src/client/client.h` — add ToastManager member
- `src/client/game.cpp` — add ToastManager draw call
- `src/script/lua_api/l_client.cpp` — add show_toast binding
- `CMakeLists.txt` — add toastManager.cpp

### Converted cheat files
- `basic_moves/autofly.lua` — return value convention
- `place/init.lua` — return value convention, remove redundant ws.dcm
- `place/walls.lua` — remove redundant ws.dcm
- `farmtool/init.lua` — convert ws.dcm to ws.notify
- `fishbot/init.lua` — convert ws.dcm to ws.notify
- `mclminer/init.lua` — convert ws.dcm to ws.notify
- `invsaver/init.lua` — convert ws.dcm to ws.notify
- `sbots/init.lua` — convert ws.dcm to ws.notify
- `wasplib/integrations.lua` — convert constraint feedback
- `dig/sponge.lua` — convert command feedback
- `nlist/init.lua` — convert command feedback
- `poi/init.lua` — convert command feedback
- `devtools/init.lua` — convert command feedback

## Testing

- Unit tests in `clientmods/al_test/` for `ws.notify()` behavior
- Integration test verifying toast appears on cheat toggle
- Verify `ws.set_notify_handler()` override works
- Verify `return false, "reason"` produces error notification
