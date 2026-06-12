# Client Lua Pipe Design

## Summary
An optional named pipe (FIFO) that the client creates to receive Lua code for
execution and write results to a response file. Intended as a debugging and
automation interface — external programs can inspect/set game state without
modifying client mods.

## Setting
Controlled by `pipe_lua_enable` (bool, default `false`) in
`src/defaultsettings.cpp`. Path configured via `pipe_lua_path` (default
`/tmp/antilua_lua`). The response file path is included in each request, or
defaults to `/tmp/antilua_lua_response` if omitted.

## Protocol

Request (single JSON line, written to FIFO):
```json
{"code":"return core.localplayer:get_pos()", "file":"/tmp/resp"}
```

The `file` field is optional. Code is arbitrary Lua, executed in the shared
client scripting state.

Response (written to the specified file):
```
ok
result
```
or:
```
error
error message
```

Multiple return values are newline-separated. No return values write just `ok`
alone.

## Implementation

### New files
- `src/client/pipe_lua.h` — class declaration
- `src/client/pipe_lua.cpp` — FIFO creation, polling, Lua execution, response

### Modified files
- `src/client/client.h` — add `std::unique_ptr<ClientLuaPipe> m_pipe_lua`
- `src/client/client.cpp` — create in `loadMods()`, poll in `step()`, auto-destroy
- `src/defaultsettings.cpp` — add `pipe_lua_enable` + `pipe_lua_path` settings
- `src/client/CMakeLists.txt` — add `pipe_lua.cpp` to `client_SRCS`

### Class: ClientLuaPipe
- **Constructor**: `mkfifo()` + `open(O_RDONLY | O_NONBLOCK)`
- **Destructor**: `close()` + `unlink()`
- **`process()`**: Called each frame from `Client::step()`. Performs a
  non-blocking read on the FIFO, splits input into lines, processes each line.
- **`processLine()`**: JSON-parses the line, extracts `code` and `file`,
  executes via `luaL_loadstring` + `lua_pcall` on the client Lua state.
  Writes `"ok\\n<result>"` or `"error\\n<msg>"` to the response file.
- Thread safety: all operations on the main thread (same as `Client::step()`).

### Execution details
- Lua state obtained via `Client::getScript()->getLuaState()`
- Uses `lua_pcall` with `msgh = 0` (error message on stack)
- Return values are converted to strings using Lua type checks
- Stack is cleaned up after each execution

### Error handling
- FIFO creation failure logs a warning but doesn't crash
- Invalid JSON on the pipe is logged to `warningstream`
- Lua compile errors and runtime errors are returned via the response file
- Missing `code` field returns nothing and logs a warning

## Testing
The test writes Lua expressions to the pipe, reads the response file, and
verifies results match expected values. See `test_pipe_lua.lua`.

## Merge conflict strategy
- All additions to existing files are minimal (1-5 lines each)
- New files don't exist upstream, so no conflict
- The CMakeLists.txt source list is the most common conflict point but is
  trivially resolved
