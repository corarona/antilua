# DF Lua Callbacks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add ~24 new Lua callbacks to DragonfireClient using separate files to minimize upstream merge conflicts.

**Architecture:** New DfScriptApi class (in src/script/cpp_api/df/) holds all callback implementations. New DfClientHooks bridge (in src/client/) provides single-line injection points in upstream packet handlers. Upstream files receive only ~6 single-line insertions total.

**Tech Stack:** C++17, Lua 5.1, Luanti engine, Catch2 unit tests, Lua integration tests

---

### Task 1: Create DfScriptApi header and stub

**Files:**
- Create: `src/script/cpp_api/df/df_callbacks.h`
- Create: `src/script/cpp_api/df/df_callbacks.cpp`
- Create: `src/client/df_hooks.h`
- Create: `src/client/df_hooks.cpp`
- Modify: `src/script/scripting_client.h` (+1 line for virtual inheritance)
- Modify: `src/script/scripting_client.cpp` (+1 line for setClient call)
- Modify: `CMakeLists.txt` (+4 new .cpp files)

- [ ] **Step 1: Create `src/script/cpp_api/df/df_callbacks.h`**
- [ ] **Step 2: Create `src/script/cpp_api/df/df_callbacks.cpp`** with stub implementations
- [ ] **Step 3: Create `src/client/df_hooks.h`**
- [ ] **Step 4: Create `src/client/df_hooks.cpp`** with stub bridge implementations
- [ ] **Step 5: Update `src/script/scripting_client.h`** — add `public DfScriptApi` to class declaration
- [ ] **Step 6: Update `src/script/scripting_client.cpp`** — add `DfScriptApi::setClient(getClient())` in constructor
- [ ] **Step 7: Update `CMakeLists.txt`** — add src files
- [ ] **Step 8: Build to verify compilation**

---

### Task 2: Register all new Lua callbacks in register_df.lua

**Files:**
- Modify: `builtin/client/register_df.lua`

- [ ] **Step 1: Add 15 new registration tables for Phase 2-4 callbacks**
- [ ] **Step 2: Run luacheck** to verify

---

### Task 3: Implement Phase 1a — Wire 9 dead callbacks

**Files:**
- Modify: `src/script/cpp_api/df/df_callbacks.cpp`
- Modify: `src/client/df_hooks.cpp`
- Modify: `src/network/clientpackethandler.cpp` (+9 single-line calls)

- [ ] **Step 1: Implement `on_recieve_physics_override` + `push_movement_table` helper**
- [ ] **Step 2: Implement bridge + packet handler call for movement**
- [ ] **Step 3: Build + test**
- [ ] **Step 4: Implement `on_play_sound` + `push_sound_table` helper**
- [ ] **Step 5: Implement bridge + handler call for play_sound**
- [ ] **Step 6: Build + test**
- [ ] **Step 7: Implement `on_spawn_particle`**
- [ ] **Step 8: Implement bridge + handler call**
- [ ] **Step 9: Build + test**
- [ ] **Step 10: Implement `on_receive_particlespawner`**
- [ ] **Step 11: Implement bridge + handler call**
- [ ] **Step 12: Build + test**
- [ ] **Step 13: Implement `on_sending_inventory_fields` + `on_sending_nodemeta_fields`**
- [ ] **Step 14: Find sendInventoryFields/NodemetaFields in client.cpp, add bridges**
- [ ] **Step 15: Build + test**
- [ ] **Step 16: Implement `on_detached_inventory_update` + `on_receiving_inventory_form` + `on_open_nodemeta_form`**
- [ ] **Step 17: Add bridges + handler calls**
- [ ] **Step 18: Build + test**

---

### Task 4: Implement Phase 1b — Move and call 4 existing methods

**Files:**
- Modify: `src/script/cpp_api/df/df_callbacks.cpp` (move 4 methods)
- Remove from: `src/script/cpp_api/s_client.cpp` (delete 4 methods)
- Remove from: `src/script/cpp_api/s_client.h` (delete 4 declarations)
- Modify: `src/client/df_hooks.cpp` (add 4 bridges)
- Modify: `src/network/clientpackethandler.cpp` (add 2-3 single-line calls)
- Modify: `src/client/game.cpp` (add 1 call)

- [ ] **Step 1: Move `on_death()` to DfScriptApi, add bridge + call in game.cpp**
- [ ] **Step 2: Move `on_object_add/hp_change/properties_change`, add bridges + calls**
- [ ] **Step 3: Remove old declarations/implementations from s_client.h/cpp**
- [ ] **Step 4: Full build + test**

---

### Task 5: Implement Phase 2 — New interception callbacks

**Files:**
- Modify: `src/script/cpp_api/df/df_callbacks.cpp`
- Modify: `src/client/df_hooks.cpp`
- Modify: `src/network/clientpackethandler.cpp` (+7 single-line calls)

- [ ] **Step 1: Implement `on_receiving_formspec`**
- [ ] **Step 2: Add bridge + call in handleCommand_ShowFormSpec**
- [ ] **Step 3: Build + test**
- [ ] **Step 4: Implement `on_node_add/remove`**
- [ ] **Step 5: Add bridges + calls**
- [ ] **Step 6: Build + test**
- [ ] **Step 7: Implement `on_hud_add/remove/change`**
- [ ] **Step 8: Add bridges + calls**
- [ ] **Step 9: Build + test**
- [ ] **Step 10: Implement `on_time_of_day`**
- [ ] **Step 11: Add bridge + call**
- [ ] **Step 12: Build + test**

---

### Task 6: Implement Phase 3 — New notification callbacks

**Files:**
- Modify: `src/script/cpp_api/df/df_callbacks.cpp`
- Modify: `src/client/df_hooks.cpp`
- Modify: `src/network/clientpackethandler.cpp` (+4 calls)
- Modify: `src/client/client.cpp` (+2 calls)

- [ ] **Step 1: Implement all 6 notification methods**
- [ ] **Step 2: Add bridges + handler calls for on_privileges/breath/player_list/lighting**
- [ ] **Step 3: Add on_connect bridge + call in handleCommand_AuthAccept**
- [ ] **Step 4: Add on_disconnect bridge + call in Client::disconnect**
- [ ] **Step 5: Build + test**

---

### Task 7: Implement Phase 4 — Game loop hooks

**Files:**
- Modify: `src/script/cpp_api/df/df_callbacks.cpp`
- Modify: `src/client/df_hooks.cpp`
- Modify: `src/client/client.cpp` (+2 calls in Client::step())

- [ ] **Step 1: Implement on_pre_step + on_post_step**
- [ ] **Step 2: Add bridges + calls in Client::step()**
- [ ] **Step 3: Build + test**

---

### Task 8: C++ unit tests

**Files:**
- Modify: `src/unittest/test_scriptapi.cpp`

- [ ] **Step 1: Write test for Phase 1a callbacks**
- [ ] **Step 2: Write test for interception callbacks**
- [ ] **Step 3: Write test for complex table callbacks**
- [ ] **Step 4: Run all unit tests**

---

### Task 9: Integration tests

**Files:**
- Create: `clientmods/al_test/test_callback_firing.lua`
- Create: `clientmods/al_test/test_callback_intercept.lua`
- Modify: `clientmods/al_test/init.lua`
- Modify: `games/devtest/mods/al_test_server/init.lua`

- [ ] **Step 1: Create test_callback_firing.lua**
- [ ] **Step 2: Extend al_test_server/init.lua**
- [ ] **Step 3: Run integration tests**
- [ ] **Step 4: Create test_callback_intercept.lua**
- [ ] **Step 5: Run integration tests**
- [ ] **Step 6: Update al_test/init.lua**

---

### Task 10: Documentation

**Files:**
- Modify: `doc/df_csm_api.md`

- [ ] **Step 1: Document Phase 1a dead callbacks**
- [ ] **Step 2: Document Phase 1b wired callbacks**
- [ ] **Step 3: Document Phase 2 interception callbacks**
- [ ] **Step 4: Document Phase 3 notification callbacks**
- [ ] **Step 5: Document Phase 4 game loop hooks**

---

### Task 11: Final verification

- [ ] **Step 1: Full build** — `cmake -B build && cmake --build build -j3`
- [ ] **Step 2: Run C++ unit tests** — `./bin/luanti --run-unittests`
- [ ] **Step 3: Run integration tests** — `./util/ci/run_al_tests.sh`
- [ ] **Step 4: Run luacheck** — `luacheck clientmods/al_test/ builtin/client/register_df.lua`
