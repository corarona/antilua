# Antilua

This repo is Antilua, a fork of Luanti (formerly Minetest) — a free
open-source voxel game engine with client-side enhancements.

## Remotes

- `luanti` — upstream Luanti at https://github.com/luanti-org/luanti/
- `origin` — antilua fork on Codeberg
- `ws` — waspsaliva (related fork)

The project is being actively rebased onto `luanti/master` on the `df-rebased`
branch, splitting the old single-branch DF history (~199 commits) into clean
feature commits.

## Build
Building can take a long time. Always use long timeouts( > 30 minutes!)

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Release -DRUN_IN_PLACE=TRUE -DBUILD_SERVER=OFF
cmake --build build -j$(nproc)
```

For debug builds:

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DRUN_IN_PLACE=TRUE -DBUILD_SERVER=OFF
cmake --build build -j$(nproc)
```

Only build debug builds when actually needed!

Out-of-tree builds in `build/` only (in-tree artifacts break CMake). See
`util/ci/build.sh` for CI build flags.

Prefer `-j3` on 4-core machines (keep one core free).

## Test

```sh
# C++ unit tests (requires -DBUILD_UNITTESTS=TRUE, which is the default)
./bin/antilua --run-unittests

# Integration tests (Antilua client-side features)
# Requires xvfb-run or Xvfb for headless display.
# Lua-only changes don't need a rebuild — just re-run.
./util/ci/run_al_tests.sh

# Lua lint (see .github/workflows/lua.yml)
```

The integration test mod lives at `clientmods/al_test/` and runs automatically
on the devtest game. A server coordinator mod is at
`games/devtest/mods/al_test_server/`. Tests report `[AL_TEST] PASS/FAIL/SKIP`.
Features not yet ported from DF are marked `SKIP (not ported)` — see
`DF_MISSING.md` for details.

Tests that depend on `core.localplayer` (ClientObjectRef, inventory location)
are deferred until the player joins the world, so results appear in two batches.

Always run the integration test after any C++ or Lua change to verify
nothing is broken:
```sh
./util/ci/run_al_tests.sh
```
Requires `xvfb-run` (from the `xvfb` package) for headless display.

For the Client Lua Pipe feature (named pipe IPC):
```sh
./util/ci/test_pipe_lua.sh
```
This spawns the game headless with `pipe_lua_enable=true`, writes Lua
expressions to the FIFO, reads responses, and verifies results.

For interactive testing on the active X server (requires i3 and xprintidle):
```sh
./util/start_test.sh
```
Opens the test world with `--go` on workspace 11. If idle >10 min, runs
headless and reports results instead.

## Code conventions

- **C++17** standard, GCC >= 7.5 or Clang >= 7.0.1
- **Tabs** for indentation (4-space wide), UTF-8, LF line endings
- **No clang-format** — uses clang-tidy for linting with a limited check set:
  `modernize-use-emplace`, `performance-*`, misc checks
  (`util/ci/clang-tidy.sh`)
- Lua: luacheck (see `.luacheckrc`), run via `.github/workflows/lua.yml`

## Key directories
- **Engine**: This repo. C++ core + Irrlicht fork.
- **Game**: Separate data (mods, textures, sounds) in `games/`. Default: `games/minetest_game`.
- **Mods**: User mods go in `mods/`, engine-provided mods in `clientmods/`.

## OpenGL / Rendering

- Two drivers: EDT_OPENGL3 (shader-based, OpenGL 3.2+ compat) and EDT_OPENGL (legacy, OpenGL 1.4+ with FFP).
- Driver selection order controlled by `src/client/renderingengine.cpp:getSupportedVideoDrivers()`.
- When `enable_shaders=false`, the legacy EDT_OPENGL driver is preferred.
- Shaders live in `client/shaders/`.
- Irrlicht built-in shader files (Solid.vsh, etc.) are compiled-in paths, not on disk.

## OpenGL 1.4 Compatibility

Adds an `enable_shaders` toggle (`Settings → Enable shaders`) that falls back to the legacy fixed-function pipeline (FFP) via EDT_OPENGL when disabled.

**Key files changed:**

| File | What changed |
|------|-------------|
| `irr/src/CIrrDeviceSDL.cpp` | EDT_OPENGL requests GL 1.4 context (fallback to 2.1) |
| `irr/include/IVideoDriver.h` | Added `virtual setVBOEnabled(bool)` |
| `irr/src/COpenGLDriver.h/cpp` | `setVBOEnabled()`, `isFBOAvailable()`, VBO/FBO guards |
| `irr/src/COpenGLMaterialRenderer.h` | Runtime `queryOpenGLFeature()` checks instead of `#ifdef`; added `GL_MODULATE` fallback; texture env reset in SOLID/REF renderers |
| `src/client/shader.cpp` | `ShaderSource` skips GLSL compilation when disabled, returns base EMT types |
| `src/client/renderingengine.cpp` | Prefers EDT_OPENGL when shaders disabled; calls `setVBOEnabled()` |
| `src/client/tile.h/cpp` | Added FFP `applyMaterialOptions()` + `applyMaterialOptionsWithShaders()` rename; handles all `TILE_MATERIAL_*` types |
| `src/client/mapblock_mesh.cpp/h` | Day/night vertex color animation, sunlight baking for FFP |
| `src/client/content_cao.cpp/h` | Entity FFP path: `setMeshColor()` instead of `ColorParam`, `final_color_blend()` |
| `src/client/wieldmesh.cpp/h` | FFP path: `colorizeMeshBuffer()`, `EHM_DYNAMIC` hint |
| `src/client/clouds.cpp/h` | FFP: `EMT_TRANSPARENT_ALPHA_CHANNEL`, pre-baked vertex colors |
| `src/client/sky.cpp/h` | FFP: `EMT_TRANSPARENT_ALPHA_CHANNEL` for stars, `setMeshBufferColor()` |
| `src/client/hud.cpp` | FFP material for selection/block bounds |
| `src/client/minimap.cpp/h` | FFP material fallback |
| `src/client/render/plain.cpp` | Post-processing guarded behind `enable_shaders` |
| `builtin/common/settings/` | `shader_warning_component.lua`, `dlg_settings.lua` updates |

**FFP material type mapping** (`src/client/tile.cpp`):
- `TILE_MATERIAL_BASIC`, `WAVING_*`, `LIQUID_OPAQUE` → `EMT_TRANSPARENT_ALPHA_CHANNEL_REF` (alpha test)
- `TILE_MATERIAL_ALPHA`, `LIQUID_TRANSPARENT`, `PLAIN_ALPHA` → `EMT_TRANSPARENT_ALPHA_CHANNEL` (alpha blend)
- `TILE_MATERIAL_OPAQUE`, `PLAIN` → `EMT_SOLID`

**What doesn't work when shaders disabled:**
- Post-processing (bloom, FXAA, volumetric light), dynamic shadows, waving animation
- Day/night uses CPU vertex color updates (slower)
- VBOs and FBOs unavailable

**Testing:** `./bin/antilua --run-unittests` — all 50 modules must pass.

## Key Directories

| Path | Purpose |
|------|---------|
| `src/` | C++ engine source (client + server) |
| `src/client/` | Client-specific code (game loop, rendering, sound) |
| `src/server/` | Server-specific code |
| `src/script/` | Lua scripting integration (API bindings, callbacks) |
| `src/gui/` | GUI elements (formspec, menus, HUD) |
| `src/client/pipe_lua.h/cpp` | Named pipe IPC for client-side Lua execution |
| `src/client/session.h/cpp` | Detach/reattach session file management |
| `irr/` | IrrlichtMt renderer (bundled) |
| `lib/` | Third-party libs (tiniergltf, catch2, sha256) |
| `builtin/` | Builtin Lua scripts (client, server, mainmenu) |
| `clientmods/` | Client-side mods (loaded at runtime) |
| `games/` | Game definitions (devtest shipped) |
| `po/` | Translations |
| `util/ci/` | CI scripts (build, lint, test) |
| `.github/workflows/` | GitHub Actions CI definitions |

## Architecture notes

- Client-side modding uses `Client::loadMods()` which loads from
  `clientmods/` and `mods/` directories (replaces the removed SSCSM system)
- The `ScriptApiBase` hierarchy provides virtual inheritance for Lua API classes
  (`ScriptApiClient`, `ScriptApiCheats`, `ScriptApiSecurity`, etc.)
- `g_game` (global `Game*`) is accessible from scripting via `setGame()` on
  `ScriptApiBase`
- Entity/Player ESP and Tracers live in `DrawTracersAndESP` pipeline step
  (`src/client/render/plain.cpp`). Uses `getCameraNode()->getAbsolutePosition()`
  for the tracer origin (NOT `camera->getPosition()`, which is world space).
  A small forward offset (`look_dir * 0.2 * BS`) avoids near-plane clipping.
- The cheat menu uses a **panel system** (`src/gui/cheatMenu.cpp`). Pressing
  TAB opens a dark overlay layer with mouse cursor. Panels are movable,
  pinnable, and keyboard-focusable. Each panel renders as a 2D rectangle with
  title bar, close/pin/focus/reset buttons, and clickable item list. Settings
  panels build widgets from `cheat_settings` (Lua table). The `get_formspec`
  field on cheat defs can provide custom formspec-based settings pages.
- `.clang-tidy` checks are configured as warnings-as-errors for performance items
- The `vcpkg.json` exists but is not the primary dependency manager on Linux

## Session Detach / Reattach

The client can detach (hide its SDL window, run headlessly) and reattach from
the terminal. Implemented via `RenderingEngine::setDetached()` which hides the
SDL window and writes a JSON session file (`$XDG_RUNTIME_DIR/antilua/session`)
with PID and pipe_lua path. Reattach uses `ClientLuaPipe::sendCommand()` to
write `core.reattach()` to the detached session's FIFO.

### Key files

| File | Purpose |
|------|---------|
| `src/client/session.h/cpp` | Session file read/write/isLive/remove |
| `src/client/renderingengine.h/cpp` | `setDetached()` — hide window, write/remove session |
| `src/client/pipe_lua.h/cpp` | `sendCommand()` static method for reattach IPC |
| `src/client/game_formspec.cpp` | "Detach" button on pause menu |
| `src/script/lua_api/l_client.h/cpp` | `core.detach()` and `core.reattach()` Lua bindings |
| `src/main.cpp` | `--attach`, `--forcenew` CLI option handling |
| `irr/include/IrrlichtDevice.h` | `setWindowVisible()` / `isWindowVisible()` virtual |
| `irr/src/CIrrDeviceSDL.h/cpp` | `SDL_HideWindow()` / `SDL_ShowWindow()` implementations |


## Raw Packet API

Allows client-side mods to send arbitrary MTP packets and intercept/modify packets in transit.

### Lua API

```lua
-- Send a raw packet to the server
core.send_raw_packet(command, payload)
-- command: number (opcode), string name like "TOSERVER_INTERACT" or "HUDCHANGE",
--           or using constant tables (numbers)
-- payload: string of raw bytes (can be empty)

-- Intercept packets from the server
core.register_on_receiving_raw_packet(function(command_id, payload)
    -- command_id is a number; payload is a raw byte string
    -- return nil/false → let through
    -- return true → silently drop
    -- return "new_payload" → replace payload and let handler process
end)

-- Intercept packets going to the server
core.register_on_sending_raw_packet(function(command_id, payload)
    -- same return conventions
end)
```

### Constant tables

These are populated at engine startup from the C++ opcode tables:

| Table | Example entries |
|-------|-----------------|
| `core.TOCLIENT` | `HELLO=0x02`, `HUDCHANGE=0x4B`, `CHAT_MESSAGE=0x2F`, `INVENTORY=0x27` |
| `core.TOSERVER` | `INTERACT=0x39`, `CHAT_MESSAGE=0x32`, `PLAYERPOS=0x23`, `INVENTORY_ACTION=0x31` |

### Safety

The following opcodes are **blacklisted** from `send_raw_packet`: `TOSERVER_INIT`, `TOSERVER_INIT2`, `TOSERVER_FIRST_SRP`, `TOSERVER_SRP_BYTES_A`, `TOSERVER_SRP_BYTES_M`. Attempting to send them raises a Lua error.

### Architecture

- **Hook sites**: `Client::ProcessData()` for incoming via `Client::interceptIncomingPacket()`, `Client::Send()` for outgoing via `Client::interceptOutgoingPacket()` — both at `src/client/client.cpp`
- **Script bridge**: `AlClientHooks` namespace (`src/client/al_hooks.h/cpp`) → `AlScriptApi` (`src/script/cpp_api/al/al_callbacks.h/cpp`) → Lua callbacks
- **Callback tables**: `registered_on_receiving_raw_packet` and `registered_on_sending_raw_packet` registered in `builtin/client/register_al.lua`
- **Payload encoding**: Lua receives/sends raw byte strings (can contain null bytes). Use `string.byte`, `string.char`, `string.sub` in Lua for structured access.
- **Return value semantics**: Return `false`/`nil` to passthrough, `true` to drop, or a string to replace the payload in-place. Single-byte `0x01` payloads are not mistaken for "drop" — the drop signal is a boolean `true`.

### Key files

| File | Purpose |
|------|---------|
| `src/network/networkpacket.h/cpp` | `NetworkPacket::setPayload()` for in-place payload replacement |
| `src/script/cpp_api/al/al_callbacks.h/cpp` | `AlScriptApi` methods: `on_raw_packet_received`, `on_raw_packet_sending`, `send_raw_packet`, `init_raw_packet_api` |
| `src/client/al_hooks.h/cpp` | `AlClientHooks` bridge functions; also defines `RawPacketHookResult` struct |
| `src/client/client.cpp` | Hook sites in `ProcessData()` and `Send()`; `Client::interceptIncomingPacket()` and `Client::interceptOutgoingPacket()` |
| `src/script/lua_api/l_client.h/cpp` | `ModApiClient::l_send_raw_packet` Lua binding |
| `builtin/client/register_al.lua` | Antilua-specific callback table registrations |
| `clientmods/al_test/test_raw_packet.lua` | Integration tests |

## Client-Side Item Override

Provides `core.override_item()` to modify item definitions client-side (mirrors server-side `minetest.override_item()`).

### Lua API

```lua
core.override_item(name, redefinition)
-- name: string item/node name (e.g. "mcl_core:stone")
-- redefinition: table of fields to override (name and type fields are rejected)
```

### Safety

Attempting to redefine `name` or `type` fields raises a Lua error. Defined in `builtin/client/register_al.lua`.

---

## Schematic API (Client-Side)

Exposes MTS schematic deserialization/serialization to client-side mods. Mirrors the server-side `core.read_schematic()` and `core.serialize_schematic()` signatures.

### Lua API

```lua
-- Read an MTS schematic from raw binary data
local schem = core.read_schematic(mts_binary_data, options)
-- mts_binary_data: string of raw .mts file bytes
-- options: { write_yslice_prob = "all"|"low"|"none" }  (optional, default "all")
-- Returns: {
--   size = { x = <int>, y = <int>, z = <int> },
--   yslice_prob = { { ypos = <int>, prob = <int> }, ... }, -- per-layer probabilities
--   data = { { name = "<node_name>", prob = <int>, param2 = <int>, force_place = <bool> }, ... }
-- }

-- Serialize a schematic table to MTS binary format
local mts_data = core.serialize_schematic(schem_table, format, options)
-- schem_table: table with size and data fields (same format as read_schematic returns)
-- format: "mts" (default) or "lua"
-- options: { lua_use_comments = false, lua_num_indent_spaces = 0 }
-- Returns: string (raw MTS bytes or Lua table text)

-- Also accepts a table directly via read_schematic for identity/round-trip:
local schem2 = core.read_schematic({ size = {...}, data = {...} }, {})
```

### Table format (same as server-side)

The `data` array has `size.x * size.y * size.z` entries in Z/Y/X order. Each entry:

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Node name (e.g. `"mcl_core:stone"`) |
| `prob` | int | Probability * 2 (0-254). 254 = always place |
| `param2` | int | Param2 value (default 0) |
| `force_place` | bool | Optional, default false |

### Key files

| File | Purpose |
|------|---------|
| `src/script/lua_api/l_client.h/cpp` | `ModApiClient::l_read_schematic`, `l_serialize_schematic` |
| `clientmods/ANTILUA/schembuilder/init.lua` | Schematic builder: load MTS, preview as particles, place via PlaceLiteM/SchemBuilderBot, auto-loot materials |
| `clientmods/al_test/test_schembuilder.lua` | Integration tests for schembuilder features |

---

## Client Lua Pipe

An optional named pipe (FIFO) for sending Lua code to the client and receiving
results. Controlled by the `pipe_lua_enable` setting (default `false`).

### Usage

```sh
# Enable in settings (minetest.conf or via core.settings):
#   pipe_lua_enable = true
#   pipe_lua_path = /tmp/antilua_lua

# Send a Lua expression to execute:
echo '{"code":"return core.localplayer:get_pos()", "file":"/tmp/resp"}' > /tmp/antilua_lua

# Read the result:
cat /tmp/resp
# ok
# {x=100, y=20, z=-30}
```

### Protocol

Requests are JSON lines (one per line, terminated by `\n`) written to the FIFO:

| Field | Required | Description |
|-------|----------|-------------|
| `code` | Yes | Lua code to execute in the shared client scripting state |
| `file` | No | Response file path (default: `/tmp/antilua_lua_response`) |

Response file format: first line is `ok` or `error`, followed by the result.

### Key files

| File | Purpose |
|------|---------|
| `src/client/pipe_lua.h` | `ClientLuaPipe` class declaration |
| `src/client/pipe_lua.cpp` | FIFO management, Lua execution, response writing |
| `src/client/client.h` | `m_pipe_lua` member on `Client` |
| `src/client/client.cpp` | Init in `loadMods()`, poll in `step()` |
| `src/defaultsettings.cpp` | `pipe_lua_enable`, `pipe_lua_path` defaults |

## OpenGL Drivers

- **EDT_OPENGL3** (`irr/src/OpenGL/` + `irr/src/OpenGL3/`): Modern driver using `COpenGL3DriverBase`, requires OpenGL 3.2 compat profile. Zero fixed-function code — every material type uses GLSL shaders.
- **EDT_OPENGL** (`irr/src/COpenGLDriver.cpp`): Legacy driver with full fixed-function pipeline (material renderers, `glTexEnv`, `GL_ALPHA_TEST`, client-side vertex arrays). Compiles only when `_IRR_COMPILE_WITH_OPENGL_` is defined (always on for Luanti).
