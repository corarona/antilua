# DragonfireClient (Luanti fork)

This repo is DragonfireClient, a fork of Luanti (formerly Minetest) — a free
open-source voxel game engine with client-side enhancements.

## Remotes

- `luanti` — upstream Luanti at https://github.com/luanti-org/luanti/
- `origin` — dragonfireclient fork on GitHub
- `ws` — waspsaliva (related fork)

The project is currently being rebased onto `luanti/master` on the `df-rebased`
branch, splitting the old single-branch DF history (~199 commits) into clean
feature commits.

## Build

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DRUN_IN_PLACE=TRUE -DBUILD_SERVER=OFF
cmake --build build -j$(nproc)
```

Out-of-tree builds in `build/` only (in-tree artifacts break CMake). See
`util/ci/build.sh` for CI build flags.

Prefer `-j3` on 4-core machines (keep one core free).

## Test

```sh
# C++ unit tests (requires -DBUILD_UNITTESTS=TRUE, which is the default)
./bin/luanti --run-unittests

# Integration tests (DragonfireClient client-side features)
# Requires xvfb-run or Xvfb for headless display.
# Lua-only changes don't need a rebuild — just re-run.
./util/ci/run_df_tests.sh

# Lua lint (see .github/workflows/lua.yml)
```

The integration test mod lives at `clientmods/df_test/` and runs automatically
on the devtest game. A server coordinator mod is at
`games/devtest/mods/df_test_server/`. Tests report `[DF_TEST] PASS/FAIL/SKIP`.
Features not yet ported from DF are marked `SKIP (not ported)` — see
`DF_MISSING.md` for details.

Tests that depend on `core.localplayer` (ClientObjectRef, inventory location)
are deferred until the player joins the world, so results appear in two batches.

Always run the integration test after any C++ or Lua change to verify
nothing is broken:
```sh
./util/ci/run_df_tests.sh
```
Requires `xvfb-run` (from the `xvfb` package) for headless display.

## Code conventions

- **C++17** standard, GCC >= 7.5 or Clang >= 7.0.1
- **Tabs** for indentation (4-space wide), UTF-8, LF line endings
- **No clang-format** — uses clang-tidy for linting with a limited check set:
  `modernize-use-emplace`, `performance-*`, misc checks
  (`util/ci/clang-tidy.sh`)
- Lua: luacheck (see `.luacheckrc`), run via `.github/workflows/lua.yml`

## Key directories

| Path | Purpose |
|------|---------|
| `src/` | C++ engine source (client + server) |
| `src/client/` | Client-specific code (game loop, rendering, sound) |
| `src/server/` | Server-specific code |
| `src/script/` | Lua scripting integration (API bindings, callbacks) |
| `src/gui/` | GUI elements (formspec, menus, HUD) |
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
- `.clang-tidy` checks are configured as warnings-as-errors for performance items
- The `vcpkg.json` exists but is not the primary dependency manager on Linux
