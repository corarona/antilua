# Cheat Settings: Formspec-Only Approach

## Problem

The cheat menu has two competing settings systems:

1. **C++ inline panel** (newer): Reads `cheat_settings` tables and renders them
   inline within the category panel. Only supports `bool` toggles; `number` and
   `string` settings display as read-only text. Has a coordinate bug in
   `handleMouse` where the click zone for expanded settings doesn't match the
   draw position (requires clicking ~1.3 lines above the actual item).

2. **Lua formspec system** (original): `core.show_cheat_settings_form()` in
   `builtin/client/cheats.lua` generates formspecs from `cheat_settings` tables,
   supporting `bool`, `number`, and `string` types with full editing. Also
   supports custom formspecs via the `get_formspec` field on cheat defs
   (used by nlist).

The C++ inline approach is incomplete, buggy, and duplicates what the formspec
system already does correctly.

## Solution

Remove all C++ inline settings code and route all settings interaction through
the existing formspec system. Clicking the gear icon on a cheat row calls
`script->show_cheat_settings(cheat->m_setting)` which invokes
`core.show_cheat_settings_form()` – the same `builtin/client/cheats.lua` function
that already handles auto-generated and custom formspecs.

## Changes

### src/gui/cheatMenu.h

Remove these fields from `CheatPanel`:
- `int show_settings_for` — cheat index with expanded inline settings
- `std::vector<CheatSettingWidget> expanded_settings` — inline setting widgets
- `int selected_setting` — keyboard focus index for inline settings
- `int hover_setting` — hover tracking for inline settings

The `CheatSettingWidget` struct can be removed entirely (no longer used).

### src/gui/cheatMenu.cpp

1. **drawPanel** — Remove the expanded-settings rendering block (currently
   lines 265–314 in the cat panel handler) and the entire `isSetPanel` branch
   (lines 319–340). The `h` calculation for cat panels no longer needs the
   expanded_settings size addition.

2. **handleMouse** — Change the gear icon click handler (lines 490–498) to call
   `script->show_cheat_settings(cheat->m_setting)` instead of expanding inline
   settings. Remove the expanded-settings click handling block (lines 472–487).
   Remove the `isSetPanel` branch (lines 509–523).

3. **openCheatSettings** — Remove this method entirely (lines 527–578). It was
   an alternate code path for opening a dedicated settings panel, which is now
   replaced by formspec.

4. **selectRight** — Remove the expanded-settings toggle (lines 699–705).
   Gear icon → formspec only, so keyboard expand is unnecessary.

5. **selectUp/selectDown** — Remove the `isSetPanel` branches that cycle
   `selected_setting` (no longer needed).

### builtin/client/cheats.lua

No changes expected — this already works correctly for all types.

### src/script/cpp_api/s_cheats.cpp

No changes expected — `show_cheat_settings()` already calls
`core.show_cheat_settings_form()` on the Lua side.

## Interaction Flow

```
User clicks gear icon on "Multiscaff"
  → CheatMenu::handleMouse detects gear click zone
  → Calls script->show_cheat_settings("scaffold")
  → ScriptApiCheats::show_cheat_settings("scaffold")
  → Lua: core.show_cheat_settings_form("scaffold")
  → Auto-generates formspec from cheat_settings:
       size[5,3.5,true]
       bgcolor[#000000;true]
       label[0,0;MultiScaff Settings]
       field[0.3,1;4.4,0.8;scaffold.width;width;5]
       field[0.3,2.1;4.4,0.8;scaffold.depth;depth;1]
       button_exit[1.5,3.3;2,0.8;;Save]
  → User edits values, clicks Save
  → Lua: core.register_on_formspec_input saves settings
```

For cheats with custom formspecs (e.g., nlist's textlist editor):
```
  → cheat_defs["nlist_edmode"].get_formspec("nlist_edmode")
  → Returns custom formspec with dropdowns, textlists, buttons
  → c.show_formspec("cheat_settings:nlist_edmode:custom", fs)
  → nlist registers its own on_formspec_input handler
```

## Files Changed

| File | Lines touched | Type |
|------|--------------|------|
| `src/gui/cheatMenu.h` | ~10 lines removed | Remove fields and struct |
| `src/gui/cheatMenu.cpp` | ~100 lines removed | Remove inline settings code |
| `builtin/client/cheats.lua` | 0 | Already correct |
| `src/script/cpp_api/s_cheats.cpp` | 0 | Already correct |

## Testing

Existing integration tests in `clientmods/df_test/test_cheats.lua` verify that
all cheat settings exist and toggle correctly via `core.settings`. These should
continue to pass. The formspec system itself is tested via the existing formspec
API tests in `test_api.lua` and `test_callbacks.lua`.

A new test should verify that `core.show_cheats_settings_form` produces valid
formspec output for a setting with `cheat_settings`.
