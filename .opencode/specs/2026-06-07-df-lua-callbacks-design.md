# Design: New Lua Callbacks for DragonfireClient

## Goal

Add ~24 new Lua callbacks to DragonfireClient's client-side modding API,
providing hooks for events currently invisible to Lua. All changes use
separate files to minimize upstream merge conflicts.

## Architecture

### File layout

```
src/script/cpp_api/df/df_callbacks.h        — DfScriptApi class (all on_* methods)
src/script/cpp_api/df/df_callbacks.cpp      — Implementations + Lua table helpers
src/client/df_hooks.h                       — DfClientHooks namespace (bridge)
src/client/df_hooks.cpp                     — Bridge: Client → DfScriptApi calls
```

### Upstream file changes (minimal)

| File | # lines added | Reason |
|---|---|---|
| `src/script/scripting_client.h` | 1 | Add `public DfScriptApi` to `ClientScripting` |
| `src/network/clientpackethandler.cpp` | ~12 | One single-line `DfClientHooks::on_*(this, ...)` per handler |
| `src/client/client.cpp` | ~3 | `on_connect`, `on_disconnect`, `on_pre/post_step` |
| `src/client/game.cpp` | 1 | `on_death` in `processClientEvents()` |
| `CMakeLists.txt` | ~2 | Register new `.cpp` files |

### How injection works

Each packet handler gets ONE new line at the relevant point:

```cpp
void Client::handleCommand_Movement(NetworkPacket* pkt)
{
    // ... existing deserialization ...
    DfClientHooks::on_movement(this, player);
}
```

The bridge function in `df_hooks.cpp`:

```cpp
void DfClientHooks::on_movement(Client *client, LocalPlayer *player)
{
    if (client->modsLoaded())
        client->getScript()->on_recieve_physics_override(player);
}
```

## Callback Inventory

### Phase 1: Wire dead callbacks (already in register_df.lua, no C++)

| # | Lua name | Insertion point | Mode | Signature |
|---|---|---|---|---|
| 1 | `on_recieve_physics_override` | `handleCommand_Movement()` | FIRST | `func({movement})` |
| 2 | `on_play_sound` | `handleCommand_PlaySound()` | OR_SC | `func({spec}) → true=cancel` |
| 3 | `on_spawn_particle` | `handleCommand_SpawnParticle()` | OR_SC | `func({particle}) → true=cancel` |
| 4 | `on_receive_particlespawner` | `handleCommand_AddParticleSpawner()` | OR_SC | `func({spawner}) → true=cancel` |
| 5 | `on_sending_inventory_fields` | `Client::sendInventoryFields()` | OR_SC | `func(name, {fields}) → true=cancel` |
| 6 | `on_sending_nodemeta_fields` | `Client::sendNodemetaFields()` | OR_SC | `func(name, {fields}) → true=cancel` |
| 7 | `on_detached_inventory_update` | `handleCommand_DetachedInventory()` | FIRST | `func(name, keep, inv)` |
| 8 | `on_receiving_inventory_form` | `handleCommand_InventoryFormSpec()` | FIRST | `func(formspec) → modified` |
| 9 | `on_open_nodemeta_form` | nodemeta formspec open path | OR_SC | `func(pos, formspec) → true=cancel` |

### Phase 1b: Move from s_client.cpp, now called

| # | Lua name | C++ method | Call from |
|---|---|---|---|
| 10 | `on_death` | Moved to DfScriptApi | `processClientEvents() → CE_DEATHSCREEN_LEGACY` |
| 11 | `on_object_add(id)` | Moved to DfScriptApi | `handleCommand_ActiveObjectRemoveAdd()` add loop |
| 12 | `on_object_hp_change(id, hp)` | Moved, signature extended with hp | `handleCommand_HP()` + object msg path |
| 13 | `on_object_properties_change(id)` | Moved to DfScriptApi | `handleCommand_ActiveObjectRemoveAdd()` add loop |

### Phase 2: New interceptions

| # | Lua name | Insertion point | Mode | Signature |
|---|---|---|---|---|
| 14 | `on_receiving_formspec` | `handleCommand_ShowFormSpec()` | FIRST | `func(name, fs) → nil/""/modified` |
| 15a | `on_node_add` | `handleCommand_AddNode()` | FIRST | `func(pos, node)` |
| 15b | `on_node_remove` | `handleCommand_RemoveNode()` | FIRST | `func(pos)` |
| 16a | `on_hud_add` | `handleCommand_HudAdd()` | OR_SC | `func({hud}) → true=block` |
| 16b | `on_hud_remove` | `handleCommand_HudRemove()` | OR_SC | `func(id) → true=block` |
| 16c | `on_hud_change` | `handleCommand_HudChange()` | OR_SC | `func(id, stat, val) → true=block` |
| 17 | `on_time_of_day` | `handleCommand_TimeOfDay()` | FIRST | `func(time, speed) → modified or nil` |

### Phase 3: New notifications

| # | Lua name | Insertion point | Signature |
|---|---|---|---|
| 18 | `on_connect` | `handleCommand_AuthAccept()` end | `func()` |
| 19 | `on_disconnect` | `Client::disconnect()` | `func()` |
| 20 | `on_privileges_changed` | `handleCommand_Privileges()` | `func({privs})` |
| 21 | `on_breath_changed` | `handleCommand_Breath()` | `func(breath)` |
| 22 | `on_player_list_changed` | `handleCommand_UpdatePlayerList()` | `func(type, {names})` |
| 23 | `on_lighting_changed` | `handleCommand_SetLighting()` | `func({lighting})` |

### Phase 4: Game loop hooks

| # | Lua name | Insertion point | Signature |
|---|---|---|---|
| 24a | `on_pre_step` | `Client::step()` start | `func(dtime)` |
| 24b | `on_post_step` | `Client::step()` end | `func(dtime)` |

## Testing

### C++ unit tests (`src/unittest/test_scriptapi.cpp`)
- **test_df_callbacks_registration**: Create `ClientScripting` instance, register a Lua callback via each `core.register_on_*`, invoke the `DfScriptApi::on_*()` trigger, verify the Lua callback fired with correct args.

### Integration tests (`clientmods/df_test/`)
- `test_callback_firing.lua`: Tests that all 24 callbacks actually fire when their trigger event occurs. Uses modchannel to instruct server coordinator to emit specific packets.
- `test_callback_intercept.lua`: Tests OR_SC callbacks — register a callback that returns `true`, assert the action was suppressed.
- Extend `df_test_server/init.lua` with modchannel commands for each test packet type.

### Documentation (`doc/df_csm_api.md`)
- Add each new callback to Section 3 with signature, return value, and table field descriptions.
- Add subsection headers: "Notification Callbacks", "Interception Callbacks", "Game Loop Hooks".
- Update status notes for previously-dead callbacks.

## Build & Verify

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DRUN_IN_PLACE=TRUE -DBUILD_SERVER=OFF
cmake --build build -j3
./bin/luanti --run-unittests
./util/ci/run_df_tests.sh
```
