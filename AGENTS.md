# Antilua

This repo is Antilua, a fork of Luanti (formerly Minetest) — a free
open-source voxel game engine with client-side enhancements.

## Skills

- `skills/antilua-lua-pipe/SKILL.md` — Control the Antilua client via the named pipe IPC (Lua pipe). Use when the client is running and you need to send Lua commands, interact with the world, craft items, or manage inventory through the FIFO at `/tmp/antilua_lua`.

## Remotes

- `luanti` — upstream Luanti at https://github.com/luanti-org/luanti/
- `origin` — antilua fork on GitHub (`git@github.com:corarona/antilua.git`)
- `kreepy` — Codeberg mirror at https://codeberg.org/notkreepy/Antilua.git
- `ws` — waspsaliva (related fork at https://repo.or.cz/waspsaliva.git)

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

## CI

Only commit and push code after all CI checks pass locally.

### Running CI checks locally

```sh
# 1. Build (catches compile errors)
cmake -B build -DCMAKE_BUILD_TYPE=Release -DRUN_IN_PLACE=TRUE -DBUILD_SERVER=OFF
cmake --build build -j3

# 2. C++ unit tests
./bin/antilua --run-unittests

# 3. Lua lint (catches code issues in builtin/)
luacheck builtin

# 4. C++ static analysis (uses compile_commands.json from build/)
./util/ci/clang-tidy.sh

# 5. Integration tests (if C++ or Lua changed)
./util/ci/run_al_tests.sh
```

### CI workflows

| Workflow | What it checks | Run locally? |
|----------|---------------|--------------|
| `linux.yml` | Build + unit tests on GCC 9/14, Clang 11/20, ARM64 | Yes — `cmake --build build -j3 && ./bin/antilua --run-unittests` |
| `lua.yml` | Luacheck on `builtin/` and `games/devtest/` | Yes — `luacheck builtin && luacheck --config=games/devtest/.luacheckrc games/devtest` |
| `cpp_lint.yml` | clang-tidy on changed C++ files | Yes — `./util/ci/clang-tidy.sh` |
| `whitespace_checks.yml` | Trailing whitespace, tabs in wrong places | Yes — `git ls-files '*.cpp' '*.h' \| xargs grep -n '\s$'` etc. |
| `png_file_checks.yml` | PNG file integrity | Yes — `./util/ci/check_png_optimized.sh` (needs optipng) |
| `macos.yml` | Build + test on macOS (Xcode) | No — needs macOS runner |
| `windows.yml` | Build + test on Windows (MSVC) | No — needs Windows runner |
| `android.yml` | Build Android APK | No — needs Android SDK/NDK |

### Policy

- **Never commit failing code.** All C++ unit tests (50 modules) must pass.
- **Never force-push to `origin/main`.** Rebase onto `luanti/master` on a feature branch, not main.
- **Run the full CI suite before pushing** — partial checks miss issues (e.g., the static init order fiasco only crashes under ASan/LTO in CI, not in debug builds).
- **Fix all clang-tidy warnings-as-errors** (`modernize-use-emplace`, `performance-*`) introduced by your changes.

## Code conventions

- **C++17** standard, GCC >= 7.5 or Clang >= 7.0.1
- **Tabs** for indentation (4-space wide), UTF-8, LF line endings
- **No clang-format** — uses clang-tidy for linting with a limited check set:
  `modernize-use-emplace`, `performance-*`, misc checks
  (`util/ci/clang-tidy.sh`)
- Lua: luacheck (see `.luacheckrc`)
- **Small atomic commits** whenever possible — each commit should be one
  logical change, compile, and pass tests independently
- **Fix all errors and warnings as soon as it makes sense** — do not put them
  off for later
- **New settings** must be added to both `src/defaultsettings.cpp` (C++ default)
  and `builtin/settingtypes_al.txt` (type definition for the settings UI)

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
- Entity/Player ESP hitboxes and wallhack live in the `DrawTracersAndESP`
  pipeline step (`src/client/render/plain.cpp`). Tracer lines (entity/player/
  node) are Lua-rendered via `core.draw3d` from
  `clientmods/ANTILUA/wasplib/tracers.lua` (moved out of C++). The Lua tracer
  origin is `core.camera:get_pos() + look_dir * 0.2`; a small forward offset
  (`look_dir * 0.2 * BS` in the old C++ code) avoids near-plane clipping. The
  node scan stays in C++ and is exposed to Lua via `core.get_node_esp_positions()`.
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
| `clientmods/ANTILUA/schembuilder/init.lua` | Schematic builder: load MTS, preview as particles, place via AutoSchemPlace/SchemBuilderBot/RhythmBuildBot, auto-loot materials |
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

## Camera Roll

Adds camera roll support — rotating the camera around its look direction axis.
Controllable via player keybindings (default: Q/E) and Lua API.

Roll is stored on `LocalPlayer` (radians) and applied in `Camera::update()` by
rotating the up vector around the camera direction via a quaternion. This
produces a mathematically pure roll unaffected by pitch or yaw.

### Key bindings

| Setting | Default | Description |
|---------|---------|-------------|
| `keymap_camera_roll_left` | Q | Roll camera counterclockwise |
| `keymap_camera_roll_right` | E | Roll camera clockwise |
| `camera_roll_speed` | 90 | Degrees per second |
| `camera_roll_max` | 180 | Maximum roll angle in degrees (set to 360 for full barrel roll) |
| `camera_roll_auto_reset` | true | Auto-reset camera roll to 0 when idle |
| `camera_roll_auto_reset_delay` | 3.0 | Seconds of input idle before reset starts |
| `camera_roll_auto_reset_duration` | 0.3 | Duration of smooth roll decay |
| `camera_roll_adaptive_mouse` | both | `both` or `pitch` — whether mouse movement adapts to camera roll |

Note: `keymap_drop` was unbound (was Q) and `keymap_aux1` moved to Left Ctrl
(was E) to free Q/E for camera roll.

### Lua API

```lua
core.localplayer:get_roll()       -- returns roll in radians
core.localplayer:set_roll(0.5)    -- sets roll to 0.5 radians
```

### Key files

| File | Change |
|------|--------|
| `src/client/keys.h` | `CAMERA_ROLL_LEFT`, `CAMERA_ROLL_RIGHT` enum entries |
| `src/client/inputhandler.cpp` | Key binding registration |
| `src/defaultsettings.cpp` | Default settings for keys, speed, max |
| `src/client/localplayer.h/cpp` | `m_camera_roll`, `setCameraRoll()`, `getCameraRoll()` |
| `src/client/camera.cpp` | Up vector rotation in `Camera::update()` |
| `src/client/game.cpp` | Keyboard roll input handling in main loop |
| `src/script/lua_api/l_localplayer.h/cpp` | `get_roll()` / `set_roll()` Lua bindings |

## Pitch Wraparound

Allows the camera pitch to pass beyond ±90° instead of clamping, enabling
loopings and inverted flight. Controlled by the `pitch_wraparound` setting.

When enabled, pitch is wrapped to [-180, 180] via `wrapDegrees_180()` instead
of clamped. The camera head node and airplane forward vector already handle
arbitrary pitch values, so this is the only change needed.

### Setting

| Setting | Default | Description |
|---------|---------|-------------|
| `pitch_wraparound` | false | Allow pitch to wrap past ±90° for loopings |

### Known limitations

Brief gimbal lock if looking exactly straight up/down with zero camera roll.
In airplane mode with bank, the up vector is not parallel to the direction
so this doesn't occur.

### Key files

| File | Change |
|------|--------|
| `src/client/game.cpp` | Conditional wrap vs clamp in `updateCameraOrientation()` |

## Sound API

The `core.sound_play()` function is now wired up (was a dead stub). It returns a
`ClientSoundHandle` userdata object with `:stop()` and `:fade()` methods.

```lua
local handle = core.sound_play({ name = "my_sound.ogg" }, { gain = 0.5, loop = false })
handle:stop()
handle:fade(-1, 0)   -- fade out over 1 second
```

Positional sound:
```lua
core.sound_play({ name = "explode.ogg" }, { gain = 1.0, pos = { x = 0, y = 10, z = 0 } })
```

The underlying `ISoundManager`/`DummySoundManager`/OpenAL pipeline was already
functional — `ModApiClientSound::Initialize()` and `ClientSoundHandle::Register()`
just needed to be called from `scripting_client.cpp`.

### Key files

| File | Change |
|------|--------|
| `src/script/scripting_client.cpp` | +2 lines to register `ModApiClientSound` + `ClientSoundHandle` |
| `src/script/lua_api/l_client_sound.h/cpp` | Existing code, previously unregistered |

## LocalPlayer Physics Extras

Additional read-only getters on `core.localplayer`:

| Method | Returns | Description |
|--------|---------|-------------|
| `get_collisionbox()` | array `[minX, minY, minZ, maxX, maxY, maxZ]` | Player collision bounding box (in BS) |
| `get_eye_offset()` | `{x, y, z}` vector | Camera eye offset from player position (BS) |
| `get_standing_node()` | `{x, y, z}` or nil | Position of node under the player's feet |
| `get_gravity()` | number | Current effective downward acceleration (BS/s²) |
| `can_jump()` | boolean | Whether the player can initiate a jump this frame |
| `get_autojump()` | boolean | Current autojump state |
| `set_autojump(bool)` | nil | Enable/disable autojump |

### Key files

| File | Change |
|------|--------|
| `src/client/localplayer.h` | Added `getStandingNode()`, `canJump()`, `setAutojump()` |
| `src/client/localplayer.cpp` | Added `setAutojump()` implementation |
| `src/script/lua_api/l_localplayer.h/cpp` | 7 new Lua method bindings |

## Camera Nametag API

Adds world-space nametag support through `core.camera`. Nametags are
rendered as 2D text projected from 3D positions (not billboards), following
the same rendering pipeline as entity nametags.

### Lua API

```lua
-- Add a nametag at a world position
local id = core.camera:add_nametag({
    pos = { x = 0, y = 10, z = 0 },
    text = "Hello World",
    color = "#FFFFFF",         -- optional: text color (default white)
    bgcolor = "#000000",       -- optional: background color (default transparent)
    size = 24,                 -- optional: font size (default 16)
    scale_z = true,            -- optional: enable distance-based scaling
})

-- Remove by id
local ok = core.camera:remove_nametag(id)

-- Remove all
core.camera:clear_nametags()
```

### Key files

| File | Change |
|------|--------|
| `src/script/lua_api/l_camera.h/cpp` | New Lua bindings: `add_nametag`, `remove_nametag`, `clear_nametags` |

## Minimap Marker API

Adds world-position markers rendered on the minimap surface. Markers are
drawn as colored dots on the minimap overlay, using the same projection
math as entity markers (`object_marker_red.png`).

### Lua API

```lua
-- Add a marker at a world position (returns numeric id)
local id = core.ui.minimap:add_marker({
    pos = { x = 0, y = 10, z = 0 },
    color = "#FF0000",      -- optional: CSS color string (default red)
    label = "home",         -- optional: name shown next to the dot on the big map
})

-- Remove by id
local ok = core.ui.minimap:remove_marker(id)

-- Remove all
core.ui.minimap:clear_markers()
```

Markers are shown on the minimap as dots; any marker with a `label` is also
drawn (dot + name) on the Antilua big map, rim-clamped to the screen edge
when outside the current view.

### Key files

| File | Change |
|------|--------|
| `src/client/minimap.h` | `MinimapLuaMarker` struct, `addLuaMarker`/`removeLuaMarker`/`clearLuaMarkers` |
| `src/client/minimap.cpp` | Marker projection in `updateActiveMarkers()`, colored dot draw in `drawMinimap()` |
| `src/script/lua_api/l_minimap.h/cpp` | Lua bindings for `add_marker`, `remove_marker`, `clear_markers` |

## Big Map (Per-Server Minimap Persistence)

The server never sends minimap map data (only `TOCLIENT_MINIMAP_MODES`
definitions); all minimap blocks are derived client-side from the ordinary
block stream. The big map captures those client-derived `MinimapMapblock`s as
they arrive, persists them per server, and provides a fullscreen pan/zoom
overlay composed from every saved block.

**Storage** — one SQLite database per server/world (`bigmap.sqlite`), with
one row per 16×16 block: a position key + a self-contained BLOB (raw `MapNode`
params + `height` + `air_count`, plus a per-block content-id→name map so
blocks remap correctly to a later session's nodedef; no `nodedef.bin` needed):
- remote: `~/.antilua/data/server/<addr>_<port>/minimap/bigmap.sqlite`
- singleplayer: `<world_path>/minimap/bigmap.sqlite` (travels with the world)

The previous per-file format (`minimap/blocks/*.bin`) is migrated into the
database on first load and the files removed.

Blocks stream in live, are batched to disk in `AlBigMap::step()` (≤128
writes/step in one transaction), and flushed on disconnect. Cap via
`minimap_save_max_blocks` (blocks farthest from the player are pruned).

**Open/close:** `keymap_big_map` (default `M`), cheat menu "BigMap" entry, or
Lua. ESC also closes it (without opening the pause menu). Pan: drag with dig
button (mouse shown while open). Zoom: mouse wheel. `set_follow_player` keeps
the map centered on the player; panning disables it. An on-screen **Follow**
button (top-right) re-centers on the player / toggles follow after panning.
The overlay draws a status readout (center coords, zoom, block count) and
first-open control hints (dismissed on interaction). The unexplored void is a
translucent scrim so the world stays dimly visible; the player position is
drawn as a rotating arrow (minimap `player_marker.png`) and minimap Lua
markers (e.g. POI waypoints) are shown as colored dots with their label.

**Lua API (`core.al_bigmap`)** — dot or colon syntax both work:
- View: `open() close() toggle() is_open()`, `set_center/get_center`,
  `pan(dx,dz)`, `set_zoom/get_zoom`, `set_follow_player/get_follow_player`
- Persistence: `set_save_enabled/get_save_enabled`, `save() load() clear()`,
  `get_block_count()`, `get_save_dir()`, `get_coverage()`
- Data: `has_block(x,z)`, `get_pixel(x,z)` → `{node,param2,height,air_count}`,
  `set_pixel(x,z,{node,height,air_count,param2})`, `get_block(x,z)` → 16×16
- Render: `render_section({pos={x,z}, size={x,z}})` (or `min`/`max`) renders
  a section of the saved map to a PNG and returns a texture name usable in a
  formspec `image` element (`nil` on failure). Saved to
  `<savedir>/images/` (registered as a texture search dir on connect).
  `clear_images()` deletes all rendered section PNGs (they otherwise
  accumulate).
- Callbacks: `core.register_on_bigmap_open/close(fn)` (fired on key-toggle)
- `/bigmap` chat command toggles the overlay.

Requires `enable_minimap=true` (default) since that gates minimap block
generation.

### Key files

| File | Change |
|------|--------|
| `src/client/al_bigmap.h/cpp` | `AlBigMap`: capture, per-server persistence, nodedef remap, tiles, rasterize, input |
| `src/client/render/al_bigmap_overlay.h/cpp` | Fullscreen overlay render step (added in `plain.cpp`/`anaglyph.cpp`) |
| `src/client/al_hooks.h/cpp` | `on_minimap_block`, bigmap wiring in `on_connect`/`on_disconnect`/`on_pre_step` |
| `src/script/cpp_api/al/al_callbacks.h/cpp` | `init_bigmap_api()` → `core.al_bigmap`, `on_bigmap_open/close` |
| `src/client/client.h/cpp` | `m_al_bigmap` member, block-capture hook at `client.cpp` block delivery |
| `src/client/game.cpp` | `client->setWorldPath(server->getWorldPath())` for singleplayer storage |
| `src/client/keys.h` + `inputhandler.cpp` | `KeyType::BIG_MAP` ← `keymap_big_map` |
| `builtin/settingtypes_al.txt` | `enable_minimap_saving`, `minimap_save_max_blocks`, `keymap_big_map` |
| `builtin/client/register_al.lua` + `cheats.lua` + `chatcommands_al.lua` | callbacks, cheat entry, `/bigmap` |
| `clientmods/al_test/test_bigmap.lua` | Integration tests |

## Sky API

Client-side access to the sky parameters via `core.sky`.

```lua
core.sky:set_sun_visible(true)
core.sky:set_moon_visible(true)
core.sky:set_stars_visible(true)
core.sky:set_star_count(1000)
core.sky:set_star_color("#FFFFFF")
core.sky:set_star_scale(1.0)
core.sky:set_sun_scale(1.0)
core.sky:set_moon_scale(1.0)
core.sky:set_body_orbit_tilt(23.5)
core.sky:set_clouds_enabled(true)
core.sky:set_fog_distance(100)
core.sky:set_fog_start(0.5)
core.sky:set_fog_color("#FFFFFF")

local b = core.sky:get_brightness()
local sun_dir = core.sky:get_sun_direction()
local moon_dir = core.sky:get_moon_direction()
local cloud_col = core.sky:get_cloud_color()
```

### Key files

| File | Change |
|------|--------|
| `src/script/lua_api/l_sky.h/cpp` | New Lua bindings for Sky |

## Clouds API

Client-side access to cloud parameters via `core.clouds`.

```lua
core.clouds:set_density(0.4)
core.clouds:set_height(120)
core.clouds:set_thickness(16)
core.clouds:set_speed({ x = 0, z = -2 })
core.clouds:set_color_bright("#FFFFFF")
core.clouds:set_color_ambient("#000000")
core.clouds:set_color_shadow("#CCCCCC")
local c = core.clouds:get_color()
local inside = core.clouds:is_camera_inside()
```

### Key files

| File | Change |
|------|--------|
| `src/script/lua_api/l_clouds.h/cpp` | New Lua bindings for Clouds |

## Commit conventions

Each feature or callback addition must be an **atomic commit** — one commit per logical change, never mixing unrelated work. A commit should:
- Touch only files related to that single change
- Compile and run independently (no half-finished state)
- Have a concise message matching the repo style

## OpenGL Drivers

- **EDT_OPENGL3** (`irr/src/OpenGL/` + `irr/src/OpenGL3/`): Modern driver using `COpenGL3DriverBase`, requires OpenGL 3.2 compat profile. Zero fixed-function code — every material type uses GLSL shaders.
- **EDT_OPENGL** (`irr/src/COpenGLDriver.cpp`): Legacy driver with full fixed-function pipeline (material renderers, `glTexEnv`, `GL_ALPHA_TEST`, client-side vertex arrays). Compiles only when `_IRR_COMPILE_WITH_OPENGL_` is defined (always on for Luanti).
