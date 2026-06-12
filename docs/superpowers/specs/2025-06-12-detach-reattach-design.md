# Detach/Re-attach for Antilua

## Summary

Allow the Antilua client to "detach" — hide the window and keep running
headless (network connection, Lua mods, pipe_lua) — and later "re-attach"
by showing the window again. Similar to `tmux`/`screen`, but for the game
client.

## Use Cases

- Headless scripting: run Lua code via `pipe_lua` while the client runs in
  background
- Keep client-side automation mods alive without a visible window
- Detach from a game session, reattach later from the terminal

## Architecture

### SDL Window Hide/Show (not destroy)

When detaching, the SDL window is hidden via `SDL_HideWindow()` — the
OpenGL context stays alive, all GPU resources (textures, shaders, VBOs)
remain valid. The `IrrlichtDevice` continues running; `run()` returns
true because the event loop still processes. The game loop continues but
skips `drawScene()` (guarded by `device->isWindowVisible()`).

### Session File as Rendezvous Point

A JSON session file at `$XDG_RUNTIME_DIR/antilua/session` (fallback:
`/tmp/antilua-$USER/session`) is written when detaching and cleaned up on
shutdown. It contains:

```json
{
  "pid": 12345,
  "pipe_lua_path": "/tmp/antilua_lua",
  "timestamp": 1718000000
}
```

### Pipe IPC for Reattach

The `--attach` flag reads the session file, checks PID liveness, then
writes `{"code":"core.reattach()", "file":"/tmp/antilua_attach_resp"}`
to the detached client's pipe_lua FIFO. The detached client processes
the command (shows window, resumes rendering). The `--attach` process
exits.

### CLI Interface

| Flag | Behavior |
|------|----------|
| (none) | Check session file. If live session exists → error + hint. |
| `--attach` | Send reattach command to detached session, exit. |
| `--forcenew` | Ignore any existing session, start fresh. |

## Files Changed

| File | Change |
|------|--------|
| `irr/include/IrrlichtDevice.h` | Add `virtual setWindowVisible(bool)` |
| `irr/src/CIrrDeviceSDL.h` | Declare `setWindowVisible` override |
| `irr/src/CIrrDeviceSDL.cpp` | Implement via `SDL_HideWindow`/`SDL_ShowWindow`; update `isWindowVisible()` to check SDL window flags |
| `src/client/renderingengine.h/cpp` | Add `m_detached`, `isDetached()`, `setDetached()` |
| `src/client/session.h/cpp` | Session file read/write/check helpers |
| `src/client/pipe_lua.h/cpp` | Add `sendReattachCommand()` static helper |
| `src/main.cpp` | Parse `--attach`, `--forcenew`; session check at launch |
| `src/client/game.cpp` | Add throttle sleep when detached (drawScene already guarded by `isWindowVisible`) |
| `src/client/game_formspec.cpp` | Add "Detach" button to pause menu |
| `src/gui/mainmenumanager.h` | Add `detach_requested` callback flag |
| `src/script/lua_api/l_client.h/cpp` | Add `core.detach()`, `core.reattach()` Lua bindings |
| `src/client/CMakeLists.txt` | Add `session.cpp` |

## Upstream Strategy

Changes are concentrated in Antilua files (`src/client/*`, `src/script/*`)
or are small additive changes to Irrlicht (`setWindowVisible` is a clean
pure-virtual addition).

## Testing

- Manual: `antilua --go`, detach via pause menu, `antilua --attach`
- Integration tests can verify via `pipe_lua` that `core.detach()` and
  `core.reattach()` succeed without crashing.
