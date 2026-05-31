# dte

Client-Side Mod Development & Testing Environment. An in-game Lua and formspec
editor. Write, save, and run Lua scripts without reloading the game. Scripts
run in a sandboxed environment where errors are caught and displayed in the UI
instead of crashing the game.

## Player usage

### Chat commands

| Command | Description |
|---------|-------------|
| `/dte` | Open the Lua IDE formspec |

### Cheats

| Cheat | Category | Description |
|-------|----------|-------------|
| Run DTE | DevTools | Run the currently loaded script in the editor |

### UI Tabs

- **LUA EDITOR** — code editor with Run, Clear, Save buttons. Output is
  displayed in a colored textlist below. Multiple named files can be switched
  via dropdown.
- **LUA CONSOLE** — placeholder (coming soon).
- **FILES** — manage Lua files: create, delete, open by double-click.
- **STARTUP** — choose files to run automatically when joining a world.
- **FUNCTIONS** — placeholder (coming soon).
- **HELP** — placeholder (coming soon).

## API

### Global

`dte` — namespace table.

`dte.modstorage` — mod storage object for persisting files and scripts.

`dte.modpath` — absolute path to the dte mod directory.

### Functions

`print(...)` — overrides the global `print`. Output is captured to the UI
output buffer instead of the console. Supports multi-line strings and multiple
arguments.

`safe(func)` — wraps a function in `pcall`. Errors are displayed in the UI
output buffer and logged. Returns the wrapped function. Use this when
registering minetest callbacks within an editor script to prevent crashes.

### Storage

Scripts and files are persisted in mod storage using key prefixes:

| Key | Description |
|-----|-------------|
| `_lua_temp` | Current unsalted file content |
| `_lua_file_<name>` | Named file content |
| `_lua_saved` | Currently selected file name |
| `_lua_startup` | Comma-separated startup file list |
| `_lua_files_list` | Comma-separated file name list |
| `_UI_files_list` | UI file list (formspec editor) |

### 3rd-party

The `3rdparty/Highlighter/` directory contains a syntax highlighter bundled
with the mod (used by the formspec editor).
