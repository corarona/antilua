Antilua Client-Side Modding API
===============================

This document describes all client-side modding (CSM) API features added by
Antilua — features not present in upstream Luanti. These extend the
`core.*` API, add new Lua callbacks, a cheat menu system, settings, rendering
extensions, the `ws.*` utility library (wasplib, in the ANTILUA modpack),
client-side schematic support, and a named pipe IPC interface.

---

Table of Contents
-----------------

1. Core API Extensions
2. ClientObjectRef (LocalPlayer & entities)
3. Callback Registration
4. Chat Commands
5. Cheat System
6. Custom Settings
7. Key Bindings
8. Rendering: ESP & Tracers
9. Raw Packet API
10. Client-Side Item Override
11. Schematic API
12. Client Lua Pipe
13. Session Detach / Reattach
14. The `ws.*` Library (wasplib, ANTILUA modpack)
15. Globalhack System (wasplib)
16. Notification System (wasplib)
17. Constraint System (wasplib)
18. Particle System

---

1. Core API Extensions
======================

These functions are added to the global `core.*` table (also available as
`minetest.*`).

### General

```lua
core.get_current_modname() -> string
core.get_modpath(modname) -> string
core.get_last_run_mod() -> string
core.set_last_run_mod(modname)
core.get_builtin_path() -> string
```

### Chat & Display

```lua
core.display_chat_message(message)      -- Show a message in chat
core.send_chat_message(message)         -- Send a message to the server
core.clear_out_chat_queue()             -- Clear pending outgoing messages
core.get_player_names() -> {string,...} -- Names of connected players
```

### Forms

```lua
core.show_formspec(formname, formspec)  -- Show a formspec
core.close_formspec(formname)           -- Close a formspec
```

### World Interaction (client-side)

```lua
core.get_node_or_nil(pos)               -- Get cached node (may be nil)
core.get_meta(pos)                      -- Get node metadata
core.place_node(pos)                    -- Place wielded item at pos
core.dig_node(pos)                      -- Dig node at pos
core.get_pointed_thing() -> table       -- Raycast result
core.interact(action, pointed_thing)    -- Perform interaction
core.find_nodes_near(pos, radius, nodenames, search_center) -> {pos,...}
    -- Find nodes matching names within radius, expanding outward by shell
```

### Utilities

```lua
core.print(text)                                    -- Print to console
core.show_toast(text, type)                         -- Show toast notification (type: "info", etc.)
core.get_language() -> locale, lang_code            -- System locale and language code
core.gettext(text) -> string                        -- Gettext translation
core.read_file(path) -> content                     -- Read file from disk (blocks ".." traversal)
core.get_dir_list(path, is_dir) -> {name,...}        -- List directory contents
core.get_modpath_real(modname) -> string             -- Resolve virtual mod path to real path
core.get_server_info() -> table                     -- {address, ip, port, protocol_version}
core.get_item_def(itemstring) -> table               -- Item definition
core.get_node_def(nodename) -> table                 -- Node definition
core.get_privilege_list() -> {string,...}            -- Available privileges
core.get_csm_restrictions() -> {string,...}          -- CSM restriction flags
core.make_screenshot() -> filename                   -- Take screenshot, returns basename
```

### Sound

```lua
core.sound_play(spec, params) -> handle
core.sound_stop(handle)
core.sound_fade(handle, step, gain)
```

### Player

```lua
core.get_objects_inside_radius(pos, radius) -> {ObjectRef,...}
core.get_wielded_item() -> ItemStack
core.get_inventory(location) -> InventoryRef
    -- Access inventory by location string (e.g. "current_player")
core.send_damage(damage)                   -- Send fake damage to server
core.send_respawn()                        -- Send respawn request
core.disconnect()                          -- Exit to main menu
core.set_keypress(key_setting, pressed) -> bool
    -- Simulate pressing/releasing a key binding
core.drop_selected_item()                  -- Drop currently wielded item stack
core.send_inventory_fields(formname, fields)
    -- Send inventory form fields to server (requires open form)
core.send_nodemeta_fields(pos, formname, fields)
    -- Send nodemeta form fields to server

core.create_client_entity(pos, properties) -> ObjectRef
    Create a client-only entity (GenericCAO) without server involvement.
    pos: v3f position in BS units (e.g. {x=0.5, y=1.5, z=0.5}).
    properties: table with ObjectProperties fields (visual, textures, node, etc.)
    Returns an ObjectRef with the full API (set_properties, remove, etc.).
    The entity is visible only to the local player and does not interact
    with the server. Use obj:remove() to delete it.
    Example:
        local e = core.create_client_entity({x=10.5, y=20.5, z=30.5}, {
            visual = "node",
            node = { name = "mcl_core:stone" },
            is_visible = true,
        })
        -- later: e:remove()

Returned by `core.get_objects_inside_radius()`, `core.localplayer:get_object()`,
and `core.get_nearby_objects()`.

---

2. ClientObjectRef (LocalPlayer & entities)
===========================================

### LocalPlayer (`core.localplayer:*`)

```lua
:get_pos() -> pos
:set_pos(pos)                       -- Teleport
:get_velocity() -> v3f
:set_velocity(vel)
:get_yaw() -> degrees
:set_yaw(degrees)
:get_pitch() -> degrees
:set_pitch(degrees)
:get_hp() -> int
:get_name() -> string
:get_wield_index() -> int           -- 1-based
:set_wield_index(idx)               -- 1-based
:get_wielded_item() -> ItemStack
:get_breath() -> int
:get_hotbar_size() -> int
:get_last_pos() -> pos
:get_last_velocity() -> v3f
:get_last_look_horizontal() -> degrees
:get_last_look_vertical() -> degrees

:is_attached() -> bool
:is_touching_ground() -> bool
:is_in_liquid() -> bool
:is_in_liquid_stable() -> bool
:is_climbing() -> bool
:swimming_vertical() -> bool

:get_control() -> { up, down, left, right, jump, sneak, aux1, zoom, dig, place }
:get_physics_override() -> table
:set_physics_override(override)

:get_movement_acceleration() -> table
:get_movement_speed() -> table
:get_movement() -> table
:get_armor_groups() -> { group=value, ... }
:get_move_resistance() -> float

:hud_add(element) -> id
:hud_remove(id)
:hud_change(id, stat, data)
:hud_get(id) -> table

:get_object() -> ObjectRef           -- CAO for local player
```

### Generic ObjectRef

Methods available on entity/ObjectRef references:

```lua
:get_pos() -> pos
:get_velocity() -> v3f
:get_acceleration() -> v3f
:get_rotation() -> v3f
:is_player() -> bool
:is_local_player() -> bool
:get_name() -> string
:get_attach() -> ObjectRef           -- Parent entity (or nil)
:get_max_hp() -> int                 -- Deprecated, use get_properties().hp_max
:get_nametag() -> string             -- Deprecated, use get_properties().nametag
:get_item_textures() -> string       -- Deprecated, use get_properties().textures
:get_properties() -> table
:set_properties(table)               -- Client-side only
:get_hp() -> int                     -- NOTE: currently always returns 0 (stub)
:punch()                             -- Attack entity
:rightclick()
:remove()
```

---

3. Callback Registration
========================

All callbacks available to client-side mods, organized by category.

### Upstream Callbacks

```lua
core.register_globalstep(func(dtime))
core.register_on_mods_loaded(func())
core.register_on_shutdown(func())
core.register_on_receiving_chat_message(func(msg) -> string|bool)
core.register_on_sending_chat_message(func(msg) -> bool)
core.register_on_chatcommand(func(msg))
core.register_on_damage_taken(func(amount))
core.register_on_hp_modification(func(new_hp))
core.register_on_dignode(func(pos, node))
core.register_on_punchnode(func(pos, node))
core.register_on_placenode(func(pointed, item))
core.register_on_item_use(func(item, pointed))
core.register_on_formspec_input(func(formname, fields))
core.register_on_inventory_open(func(inventory))
core.register_on_modchannel_message(func(channel, sender, message))
core.register_on_modchannel_signal(func(channel, signal))
```

Return `true` from a `register_on_receiving_chat_message` handler to suppress
the message. Return a string to replace the message with a modified version
(e.g., `core.strip_colors(msg)` to remove color codes).

### Notification Callbacks (fire-and-forget)

```lua
core.register_on_death(func())
core.register_on_connect(func())
core.register_on_disconnect(func())
core.register_on_receive_physics_override(func(movement))
core.register_on_detached_inventory_update(func(name, keep))
core.register_on_privileges_changed(func(privs))
core.register_on_breath_changed(func(breath))
core.register_on_player_list_changed(func(type, names))
core.register_on_lighting_changed(func(lighting))
core.register_on_pre_step(func(dtime))
core.register_on_post_step(func(dtime))
```

- **`on_death`**: Called when the player dies (death screen shown).
- **`on_connect`**: Called when the client successfully connects and joins the world.
- **`on_disconnect`**: Called when the client begins disconnecting from the server.
- **`on_receive_physics_override`**: Called when server sends movement/physics parameters.
  `movement` table: `{acceleration_default, acceleration_air, acceleration_fast, speed_walk, speed_crouch, speed_fast, speed_climb, speed_jump, liquid_fluidity, liquid_fluidity_smooth, liquid_sink, gravity}`.
- **`on_detached_inventory_update`**: Called when a detached inventory is updated or removed.
  `name` is the inventory name, `keep` is true for updates, false for removal.
- **`on_privileges_changed`**: Called when server updates your privileges.
  `privs` is an array of privilege strings like `{"interact", "shout"}`.
- **`on_breath_changed`**: Called when breath/air value changes. `breath` is the new value.
- **`on_player_list_changed`**: Called when the player list changes.
  `type` is 0 (init), 1 (add), or 2 (remove). `names` is an array of player names.
- **`on_lighting_changed`**: Called when server updates lighting params.
  `lighting` table with shadow/exposure/bloom fields.
- **`on_pre_step(dtime)`**: Called at the start of every client tick, before all packet processing.
- **`on_post_step(dtime)`**: Called at the end of every client tick, after all processing.

### Interception Callbacks (can modify or block)

```lua
core.register_on_receiving_inventory_form(func(formspec) -> modified_formspec)
core.register_on_receiving_formspec(func(formname, formspec) -> modified_formspec)
core.register_on_hud_add(func(hud_def) -> true to block)
core.register_on_hud_remove(func(id) -> true to block)
core.register_on_hud_change(func(id, stat, value) -> true to block)
core.register_on_time_of_day(func(time, speed) -> modified_time)
```

- **`on_receiving_inventory_form`**: Called when server sends inventory formspec.
  Return a modified formspec string to replace it.
- **`on_receiving_formspec`**: Called when server sends any formspec.
  Return a modified formspec to replace, or empty string `""` to block.
- **`on_hud_add/remove/change`**: Called when server adds/removes/changes a HUD element.
  Return `true` to prevent the change.
- **`on_time_of_day`**: Called when server updates time of day.
  Return a new time (0-24000) to override, or nil to keep original.

### Object & World Callbacks

```lua
core.register_on_object_add(func(id))
core.register_on_object_hp_change(func(id, hp))
core.register_on_object_properties_change(func(id))
core.register_on_node_add(func(pos, node))
core.register_on_node_remove(func(pos))
```

- **`on_object_add`**: Called when a new active object (entity) appears.
- **`on_object_hp_change`**: Called when an object's HP changes. `id` is the object ID, `hp` is the new HP.
- **`on_object_properties_change`**: Called when object properties are synchronized.
- **`on_node_add`**: Called when the server adds a node at a position.
- **`on_node_remove`**: Called when the server removes a node at a position.

### Formsound & Interaction Callbacks

```lua
core.register_on_sending_inventory_fields(func(formname, fields) -> true to cancel)
core.register_on_sending_nodemeta_fields(func(formname, fields) -> true to cancel)
core.register_on_open_nodemeta_form(func(pos, formspec) -> true to cancel)
```

- **`on_sending_inventory_fields`**: Called before sending inventory formspec fields to the server.
  Return `true` to cancel the submission.
- **`on_sending_nodemeta_fields`**: Called before sending nodemeta formspec fields.
  Return `true` to cancel the submission.
- **`on_open_nodemeta_form`**: Called when a nodemeta formspec is about to open.
  Return `true` to block it.

### Sound & Particle Callbacks

```lua
core.register_on_play_sound(func(spec) -> true to cancel)
core.register_on_spawn_particle(func(particle) -> true to cancel)
core.register_on_receive_particlespawner(func(spawner) -> true to cancel)
```

- **`on_play_sound`**: Called when server plays a sound. `spec` table contains `{name, gain, type, pos, object_id, loop, fade, pitch, ephemeral, start_time, server_id}`.
  Return `true` to prevent the sound from playing.
- **`on_spawn_particle`**: Called when server spawns a particle.
  Return `true` to suppress it.
- **`on_receive_particlespawner`**: Called when server adds a particle spawner.
  Return `true` to suppress it.

---

4. Chat Commands
================

All commands use the `.` prefix. Register via `core.registered_chatcommands`:

| Command | Description |
|---------|-------------|
| `.say <text>` | Send raw chat text |
| `.teleport <x>,<y>,<z>` | Teleport to coordinates |
| `.wielded` | Print itemstring of wielded item |
| `.disconnect` | Exit to main menu |
| `.players` | List online players |
| `.kill` | Kill yourself (10k damage) |
| `.set [-n] <name> <value>` | Read/set a client setting |
| `.place <x>,<y>,<z>` | Place wielded item at position |
| `.dig <x>,<y>,<z>` | Dig node at position |
| `.setyaw <yaw>` | Set camera yaw |
| `.setpitch <pitch>` | Set camera pitch |
| `.respawn` | Respawn (ghost mode) |
| `.help [cmd]` | Show help |

Commands can be registered by client mods via:

```lua
core.registered_chatcommands["name"] = {
    params = "",
    description = "...",
    func = function(param) end,
}
```

---

5. Cheat System
===============

Cheats are registered in the `core.cheats` table, organized by category:

```lua
core.cheats["Combat"]["AntiKnockback"]   = "antiknockback"
core.cheats["Movement"]["JetPack"]       = "jetpack"
core.cheats["Render"]["Xray"]            = "xray"
core.cheats["Interact"]["FastDig"]       = "fastdig"
core.cheats["Player"]["Reach"]           = "reach"
```

### Registration

```lua
core.register_cheat(cheatname, category, func_or_setting)
```

When called from a Lua mod, the third parameter is the setting name (a string)
or a function. The cheat menu displays the category/name and toggles the
corresponding setting.

### Built-in Cheat Categories & Cheats (engine-level)

| Category | Cheat | Setting | Effect |
|----------|-------|---------|--------|
| **Combat** | AntiKnockback | `antiknockback` | No knockback |
| | AttachmentFloat | `float_above_parent` | Float above mounts |
| | AutoHit | `autohit` | Auto-attack entities |
| **Movement** | Freecam | `freecam` | Detached camera |
| | Freelook | `freelook` | Mouse-look without holding |
| | AutoForward | `continuous_forward` | Auto-run |
| | PitchMove | `pitch_move` | Move in look direction |
| | AutoJump | `autojump` | Auto-jump obstacles |
| | Jesus | `jesus` | Walk on water |
| | NoSlow | `no_slow` | No movement slowdown |
| | JetPack | `jetpack` | Fly with jump key |
| | AntiSlip | `antislip` | No ice slipping |
| | AirJump | `airjump` | Jump in mid-air |
| | Spider | `spider` | Climb walls |
| | EntitySpeed | `entity_speed` | Entities at player speed |
| **Render** | Xray | `xray` | See through terrain |
| | Fullbright | `fullbright` | Always max light |
| | HUDBypass | `hud_flags_bypass` | Ignore server HUD flags |
| | NoHurtCam | `no_hurt_cam` | No damage screen shake |
| | CheatHUD | `cheat_hud` | Active cheats overlay |
| | EntityHitboxes | `enable_entity_esp` | Entity wireframe hitboxes |
| | EntityWallhack | `enable_entity_wallhack` | Through-walls entity ESP |
| | EntityTracers | `enable_entity_tracers` | Entity tracer lines |
| | PlayerHitboxes | `enable_player_esp` | Player wireframe hitboxes |
| | PlayerWallhack | `enable_player_wallhack` | Through-walls player ESP |
| | PlayerTracers | `enable_player_tracers` | Player tracer lines |
| | NodeESP | `enable_node_esp` | Node bounding-box highlights (stub, no C++ rendering) |
| **Interact** | FastDig | `fastdig` | Faster digging |
| | FastPlace | `fastplace` | Faster placement |
| | AutoDig | `autodig` | Auto-dig nearest |
| | AutoPlace | `autoplace` | Auto-place blocks |
| | InstantBreak | `instant_break` | One-hit break |
| | FastHit | `spamclick` | Auto-click |
| **Player** | NoFallDamage | `prevent_natural_damage` | No environmental damage |
| | NoForceRotate | `no_force_rotate` | No forced rotation |
| | Reach | `reach` | Extended interaction range |
| | PointAll | `point_all` | Point any node except air |
| | PrivBypass | `priv_bypass` | Bypass privilege checks |
| | ThroughWalls | `dont_point_nodes` | Don't auto-point nodes |

Cheats can be toggled via the cheat menu (default `TAB`) or by setting the
corresponding setting to `"true"` / `"false"`.

### Mod-Registered Categories & Cheats

Additional cheats registered by client-side mods (ANTILUA modpack):

| Category | Cheat | Setting | Provided by |
|----------|-------|---------|-------------|
| **Combat** | Killaura | `killaura` | `combat` mod (key X) |
| **Bots** | PatrolGuard | `combat_bot` | `combat` mod |
| **Movement** | AutoFsprint | `autoforwardsprint` | `basic_moves` mod |
| | RhythmTP | `rhythmtp` | `rhythmtp` mod |
| **Render** | AlwaysDay | `always_day` | `always_day` mod |
| | CleanHUD | `clean_hud` | `clean_hud` mod |
| | StripChatColors | `strip_chat_colors` | `wasplib` |
| | EntityLogger | `entity_logger` | `event_logger` mod |
| | WorldObserver | `world_observer` | `event_logger` mod |
| | MovementDisplay | `movement_display` | `event_logger` mod |
| | POIShowNames | `poi_shownames` | `poi` mod |
| **Player** | AutoRespawn | `autorespawn` | Engine (Lua builtin) |
| | InvSaver | `invsaver` | `invsaver` mod |
| | HeadSaver | `headsaver` | `wasplib` |
| | LockView | `lockview` | `wasplib` |
| | DeathWaypoints | `auto_death_waypoint` | `poi` mod |
| | AutoScreenshot | `auto_screenshot` | `poi` mod |
| | DeathTP | `death_tp` | `poi` mod |
| | BreathAlert | `breath_alert` | `event_logger` mod |
| **Place** | MultiScaff (Scaffold) | `scaffold` | `place` mod (key Y) |
| | Reap | `farmtool_reap` | `farmtool` mod |
| | AutoTorch | `auto_torch` | `inventory` mod |
| **Inventory** | AutoRefill | `autorefill` | `inventory` mod |
| | AutoEject | `autoeject` | `inventory` mod |
| | ChestStealer | `chest_stealer` | `inventory` mod |
| | PunchInv | `punchinv` | `inventory` mod |
| | AutoSort | (function) | `inventory` mod |
| | AutoBlock | `autoblock` | `inventory` mod |
| | AutoTool | `autotool` | `wasplib` |
| **Dig** | DigCustom | `digcustom` | `dig` mod |
| | IceBreaker | `icebreaker` | `wasplib` |
| **Interact** | FormspecBlocker | `formspec_blocker` | `al_formspec` mod |
| **Player** | Autocraft | `autocraft` | `autocraft` mod |
| | AutoEat | `autoeat` | `autoeat` mod |
| **DevTools** | ItemMeta/PointedMeta/PosMeta | (functions) | `devtools` mod |
| | Run DTE | (function) | `dte` mod |
| | FindVoidAir | `fvair` | `devtools` mod |
| **Info** | BlockLogger | `block_logger` | `event_logger` mod |
| | BlockStats | (function) | `event_logger` mod |
| **Social** | ChatAlerts | `chat_alerts` | `session_logger` mod |
| | NameColorizer | `name_colorizer` | `session_logger` mod |
| **Misc** | POIs | (function) | `poi` mod |
| | Help | (function) | `help` mod |
| | Keybinds | (function) | `help` mod |
| **Bots** | (various) | (various) | `sbots` mod |

Cheats can be toggled via the cheat menu (default `TAB`) or by setting the
corresponding setting to `"true"` / `"false"`.

---

6. Custom Settings
==================

These settings exist only in Antilua. Set via `core.settings:set()`,
`.set` command, or the cheat menu.

### Toggle Cheats

| Setting | Default | Description |
|---------|---------|-------------|
| `airjump` | `false` | Jump in mid-air |
| `spider` | `false` | Climb walls |
| `jetpack` | `false` | Fly with jump key |
| `no_slow` | `false` | No movement slowdown |
| `antislip` | `false` | No ice slipping |
| `entity_speed` | `false` | Entities move at player speed |
| `antiknockback` | `false` | No knockback |
| `autodig` | `false` | Auto-dig nearest node |
| `fastdig` | `false` | Faster digging |
| `jesus` | `false` | Walk on water |
| `fastplace` | `false` | Faster placement |
| `autoplace` | `false` | Auto-place blocks |
| `instant_break` | `false` | Instant node breaking |
| `point_all` | `false` | Point any node except air |
| `spamclick` | `false` | Fast auto-clicking |
| `no_force_rotate` | `false` | Prevent forced rotation |
| `float_above_parent` | `false` | Float above attached parent |
| `cheat_hud` | `true` | Show cheat overlay |
| `autohit` | `false` | Auto-hit entities |
| `autojump` | `false` | Auto-jump over obstacles |
| `pitch_move` | `false` | Move in look direction |
| `continuous_forward` | `false` | Always run forward |
| `autorespawn` | `false` | Auto-respawn on death |
| `dont_point_nodes` | `false` | Don't point at nodes |

### Render Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `xray` | `false` | X-ray vision |
| `xray_nodes` | `default:stone,...` | Nodes visible in xray |
| `fullbright` | `false` | Maximum light level |
| `freecam` | `false` | Detached camera |
| `hud_flags_bypass` | `true` | Ignore server HUD flags |
| `no_hurt_cam` | `false` | Disable hurt camera |
| `priv_bypass` | `true` | Bypass privilege checks |
| `prevent_natural_damage` | `true` | No environmental damage |
| `reach` | `true` | Extended reach |
| `enable_node_esp` | `false` | Node ESP |
| `enable_entity_esp` | `false` | Entity wireframe hitboxes |
| `enable_entity_tracers` | `false` | Entity tracer lines |
| `enable_entity_wallhack` | `false` | Through-walls entity ESP |
| `enable_player_esp` | `false` | Player wireframe hitboxes |
| `enable_player_tracers` | `false` | Player tracer lines |
| `enable_player_wallhack` | `false` | Through-walls player ESP |
| `node_esp_nodes` | `""` | Node ESP filter list |
| `entity_esp_color` | `(255,255,255)` | ESP line color |
| `player_esp_color` | `(255,255,255)` | Player ESP color |

### Cheat Menu Styling

Colors use RGB tuple format `(R, G, B)`.

| Setting | Default | Description |
|---------|---------|-------------|
| `cheat_menu_font` | `"FM_Standard"` | Font face |
| `cheat_menu_bg_color` | `(4, 4, 8)` | Background color |
| `cheat_menu_bg_color_alpha` | `190` | Background opacity |
| `cheat_menu_active_bg_color` | `(0, 0, 0)` | Active item bg |
| `cheat_menu_active_bg_color_alpha` | `210` | Active item opacity |
| `cheat_menu_font_color` | `(0, 255, 0)` | Font color |
| `cheat_menu_font_color_alpha` | `195` | Font opacity |
| `cheat_menu_selected_font_color` | `(255, 255, 255)` | Selected item color |
| `cheat_menu_selected_font_color_alpha` | `235` | Selected opacity |
| `cheat_menu_head_height` | `50` | Header height |
| `cheat_menu_entry_height` | `35` | Entry height |
| `cheat_menu_entry_width` | `200` | Entry width |
| `cheat_menu_panel_bg` | `(30, 30, 45)` | Panel background color |
| `cheat_menu_title_bg` | `(50, 50, 75)` | Title bar background |
| `cheat_menu_border` | `(10, 10, 10)` | Border color |
| `cheat_menu_item_bg` | `(45, 45, 55)` | Item background |
| `cheat_menu_item_bg_alt` | `(45, 45, 65)` | Alternate item background |

---

7. Key Bindings
===============

| Key | Default | Action |
|-----|---------|--------|
| `keymap_toggle_cheat_menu` | `TAB` | Open/close cheat menu |
| `keymap_toggle_killaura` | `X` | Toggle killaura |
| `keymap_toggle_freecam` | `G` | Toggle freecam |
| `keymap_toggle_scaffold` | `Y` | Toggle scaffold assist |
| `keymap_enderchest` | `H` | Open ender chest |
| `keymap_select_up` | `Up` | Cheat menu up |
| `keymap_select_down` | `Down` | Cheat menu down |
| `keymap_select_left` | `Left` | Cheat menu back |
| `keymap_select_right` | `Right` | Cheat menu enter category |
| `keymap_select_confirm` | `F` | Toggle selected cheat |

---

8. Rendering: ESP & Tracers
============================

Entity and Player ESP/Tracer rendering is implemented as a custom render
pipeline step in `DrawTracersAndESP`.

### Settings

- `enable_entity_esp` — Draws wireframe hitboxes around all entities
- `enable_entity_tracers` — Draws lines from camera to each entity
- `enable_entity_wallhack` — Through-walls entity boxes (ECFN_ALWAYS depth test; no color distinction)
- `enable_player_esp` — Draws wireframe hitboxes around other players
- `enable_player_tracers` — Draws lines from camera to each player
- `enable_player_wallhack` — Through-walls player boxes (ECFN_ALWAYS depth test; no color distinction)
- `entity_esp_color` / `player_esp_color` — RGB tuple for ESP line color

### Implementation Notes

- The tracer origin is `camera_node_position + (look_dir * 0.2 * BS)`,
  NOT `camera:getPosition()` (which maps incorrectly in view space).
- Boxes use `draw3DBox` and lines use `draw3DLine`.
- `enable_node_esp` (node bounding-box highlights) exists as a setting but has
  no C++ rendering implementation (stub). Filter list: `node_esp_nodes`.

---

9. Raw Packet API
=================

See AGENTS.md for the full raw packet API documentation. Key functions:

```lua
core.send_raw_packet(command, payload)
core.register_on_receiving_raw_packet(func(command_id, payload) -> nil|true|string)
core.register_on_sending_raw_packet(func(command_id, payload) -> nil|true|string)
```

Constant tables `core.TOCLIENT` and `core.TOSERVER` map opcode names to
numeric IDs. Certain init-phase opcodes are blacklisted.

---

10. Client-Side Item Override
============================

```lua
core.override_item(name, redefinition)
```

Modify item/node definitions client-side. The `name` and `type` fields in the
redefinition table are rejected (raises a Lua error). Mirrors the server-side
`minetest.override_item()`.

---

11. Schematic API (Client-Side)
==============================

Deserialize/serialize MTS schematics client-side:

```lua
-- Read an MTS schematic from raw binary data
local schem = core.read_schematic(mts_binary_data, options)
-- Returns: { size = {x,y,z}, yslice_prob = {...}, data = {{name, prob, param2, force_place}, ...} }

-- Serialize a schematic table to MTS binary format
local mts_data = core.serialize_schematic(schem_table, format, options)
-- format: "mts" (default) or "lua"
```

The data array follows the same Z/Y/X order as the server-side API.
Each entry also includes `{x, y, z}` position fields indicating the node's
coordinates within the schematic.

---

12. Client Lua Pipe
==================

An optional named pipe (FIFO) for sending Lua code to the client and receiving
results. Controlled by the `pipe_lua_enable` setting.

Write a JSON line to the FIFO at `pipe_lua_path` (default `/tmp/antilua_lua`):

```json
{"code":"return core.localplayer:get_pos()", "file":"/tmp/resp"}
```

Response file format:
```
ok
{result}
```

On error, the first line is `error` followed by the error message.

---

13. Session Detach / Reattach
============================

The client can detach (hide its window, run headlessly) and later reattach.

- **Detach**: `core.detach()` or the "Detach" button in the pause menu.
  The game loop continues (physics, network, Lua) but rendering is suspended.
  A session file is written to `$XDG_RUNTIME_DIR/antilua/session`.
- **Reattach**: Run `antilua --attach` from the terminal. Requires
  `pipe_lua_enable = true` — the reattach command is sent via the Lua pipe.
- **Start fresh**: `antilua --forcenew` bypasses the session check.

---

14. The `ws.*` Library (wasplib, ANTILUA modpack)
================================

The `ws` global namespace is provided by the `wasplib` mod (part of the
`ANTILUA` modpack). Load order: settings → coord → inventory → tools →
world → combat → waypoints.

Additionally, `core.switch_to_item(item)` is a global alias for
`ws.switch_to_item(item)`, and `core.register_cheat_description(name, category, setting, description)`
is a compat shim that stores descriptions on cheat definitions.

### Settings (`ws.*`)

```lua
ws.s(name, [value])                      -- Get/set setting
ws.sb(name, [value])                     -- Get/set bool setting
ws.dcm(msg)                              -- Display chat message
ws.set_bool_bulk({settings,...}, value)  -- Set multiple bools
ws.shuffle(tbl)                          -- Fisher-Yates shuffle
ws.in_list(val, list)                    -- Value in list check
ws.random_table_element(tbl)             -- Random element
ws.round2(num, decimals)                 -- Round to N decimals
ws.pos_to_string(pos)                    -- Round + stringify
ws.string_to_pos(param)                  -- Parse pos string
ws.between(x, y, z)                      -- Inclusive range check
ws.register_chatcommand_alias(old, ...)  -- Create aliases
```

### Coordinates (`ws.coord.*`)

```lua
ws.coord(x, y, z)                        -- vector.new wrapper
ws.ordercoord(c)                         -- Normalize {1,2,3} to {x=1,y=2,z=3}
ws.optcoord(x, y, z)                     -- Accept both formats
ws.cadd(c1, c2)                          -- Vector add
ws.relcoord(x, y, z, rpos)               -- Relative offset from pos
ws.is_same_pos(p1, p2)                   -- Rounded equality
ws.get_reachable_positions(range, under) -- Get cube of positions
ws.do_area(radius, func, plane)          -- Iterate over area
ws.getaxis()                             -- "x" or "z" from facing
ws.setdir(dir)                           -- Set yaw to N/S/E/W
ws.getdir([yaw])                         -- Get cardinal direction
ws.dircoord(f, y, r, rpos, rdir)        -- Forward/right/up offset
ws.get_dimension(pos)                    -- Dimension by y-level
```

### Inventory (`ws.inv.*`)

```lua
ws.find_item_in_table(items, rnd)        -- Find match in table
ws.find_empty(inv)                       -- First empty slot
ws.count_empty_slots(inv)                -- Empty slot count
ws.find_named(inv, name)                 -- Slot by exact item name
ws.itemnameformat(desc)                  -- Strip colors/formatting
ws.find_nametagged(list, name)           -- Match by description
ws.to_hotbar(it_slot, hslot)             -- Move item to hotbar
ws.switch_to_item(item, hslot)           -- Wield matching item
ws.in_inv(item)                          -- Item exists in inventory
ws.inv_full([item])                      -- Inventory full check
ws.inv_get_space([item])                 -- Available stack space
ws.switch_inv_or_echest(name, max, h)    -- Try inv then ender chest
ws.invparse(location)                    -- Parse inv location string
ws.invpos(pos)                           -- Nodepos → "nodemeta:x,y,z"
ws.move_stack(from_loc, from_list, from_idx, to_loc, to_list, to_idx, [count])
                                         -- Move items between inventories
ws.cheat_setting(self, key, default)     -- Read numeric cheat sub-setting
ws.register_keypress_cheat(setting, desc, category, keyname, [condition])
                                         -- Register key-hold cheat
ws.hud_set(id, stat, data)              -- Nil-safe HUD change wrapper
```

### Tools (`ws.tools.*`)

```lua
ws.get_digtime(nodename)                 -- Best dig time for node
ws.select_best_tool(pos_or_nodename)     -- Switch to best tool
ws.find_best_tool(nodename) -> idx, time -- Find fastest-digging tool
```

### World Interaction (`ws.world.*`)

```lua
ws.buildable_to(pos)                     -- Check buildable-to
ws.tplace(pos, node, stay)              -- TP-place a node
ws.ytp(y)                                -- Teleport to y-level
ws.isnode(pos, arg)                      -- Check node name
ws.can_place_at(pos)                     -- Is node placeable air/fluid
ws.can_place_wielded_at(pos)             -- Wielded item & placeable
ws.find_any_swap(items, hslot)           -- First matching item to wield
ws.place(pos, items, hslot, place_fn)    -- Smart place
ws.place_if_able(pos)                    -- Place if possible
ws.is_diggable(pos)                      -- Check diggable
ws.dig(pos, condition, autotool)         -- Smart dig
ws.chunk_loaded()                        -- Current chunk loaded?
ws.get_near(nodes, range)                -- Find nodes by name
ws.is_laggy()                            -- Ping > 1000
ws.donodes(poss, func, condition)        -- Execute on nodes (rate-limited)
ws.allow_dig(pos)                        -- Permission check (always true)
ws.dignodes(poss, condition)             -- Dig multiple nodes
ws.replace(pos, arg)                     -- Replace node (place or dig+place)
ws.in_cube(tpos, p1, p2)                 -- Point-in-cube test
ws.in_wall(pos)                          -- MCEdit wall region (hardcoded)
ws.inside_wall(pos)                      -- Inner wall region
ws.find_closest_reachable_airpocket(pos) -- Nearest air node
ws.find_closest_pos(poss)                -- Nearest position
ws.make_blocks()                         -- Auto-craft from wielded item
ws.invdump(src, dst)                     -- Dump inventory (via quint)
ws.dumpto()                              -- Dump to pointed chest
ws.loot()                                -- Take from pointed chest
ws.icebreaker()                          -- Dig ice in range
ws.invtoec()                             -- Dump inv to ender chest
ws.ectoinv()                             -- Restore inv from ender chest
ws.loot_list(items, range, max_per_scan) -- Loot matching items from nearby containers
```

### Combat

```lua
ws.aim(pos)                              -- Aim camera at position
ws.gaim(pos, velocity, gravity)          -- Gravity-compensated aim
ws.find_player(name) -> pos, object      -- Nearby player lookup
ws.playeron(name) -> bool                -- Player online check
```

### Waypoints

```lua
ws.get_hud_by_texture(texture)           -- Find HUD element
ws.display_wp(pos, name) -> id           -- Show waypoint
ws.clear_wp(id)                          -- Remove waypoint
ws.clear_wps()                           -- Clear all
```

---

15. Globalhack System (wasplib)
=====================

The globalhack system provides a framework for toggleable cheat features that
run every globalstep. It is part of wasplib.

### Core

```lua
ws.registered_globalhacks = {}            -- All registered hack functions
```

### Templates

```lua
ws.globalhacktemplate(def)
    -- Creates a handler function from a def table:
    --   def = {
    --     setting   = "my_setting",        -- Setting to check
    --     on_step   = function(self, dtime) end,  -- Each step while active
    --     on_start  = function(self) end,         -- On activation (return false to allow)
    --     on_stop   = function(self) end,         -- On deactivation
    --     daughters = {"dependent_setting", ...}, -- Settings to toggle
    --     delay     = 0.2,                        -- Rate limit
    --     name      = "MyCheat",                  -- Display name (optional)
    --   }
    -- The handler checks `core.settings:get_bool(def.setting)` each step,
    -- calls on_start on activation, on_step each step while active,
    -- on_stop on deactivation, and toggles daughter settings.

ws.register_globalhack(func)
    -- Appends func to ws.registered_globalhacks

ws.register_globalhacktemplate(name, category, setting, func, funcstart, funcstop, daughters, delay)
    -- Combinator (positional-arg style): creates template + registers hack + registers cheat
    -- (via minetest.register_cheat and the cheat menu)

ws.register_globalhacktemplate(name, def_table)
    -- Combinator (def-table style): same as above but with a def table
    -- that can include cheat_settings and get_formspec fields.

ws.rg = ws.register_globalhacktemplate  -- Shorthand

ws.step_globalhacks(dtime)
    -- Iterates ws.registered_globalhacks, called from
    -- minetest.register_globalstep

ws.on_connect(func)
    -- Defers func until core.localplayer is available
    -- (polls via minetest.after)
```

### Example (positional-arg style)

```lua
ws.rg("MyCheat", "MyCategory", "my_cheat", function()
    -- runs each step while enabled
    core.localplayer:set_pos(ws.dircoord(0, 1, 0))
end, function()
    -- runs on activation
    return false  -- false = allow activation
end, function()
    -- runs on deactivation
end, {"dependent_setting"}, 0.1)
```

### Example (def-table style with settings form)

```lua
ws.rg("Killaura", {
    category = "Combat",
    setting = "killaura",
    on_step = function(self, dtime)
        -- attack logic
    end,
    on_start = function(self) end,
    on_stop = function(self) end,
    daughters = {},
    delay = 0.1,
    cheat_settings = {
        { key = "range",      label = "Range",      type = "number", default = 4 },
        { key = "hph",        label = "HP threshold", type = "number", default = 20 },
    },
    get_formspec = function(self)
        return "label[0,0;Custom settings UI]"
    end,
})
```

---

16. Notification System (wasplib)
==================================

The notification system provides chat and toast notifications via `ws.*`:

```lua
ws.NOTIFY_INFO = "info"                  -- Notification type constants
ws.NOTIFY_SUCCESS = "success"
ws.NOTIFY_WARNING = "warning"
ws.NOTIFY_ERROR = "error"

ws.notify(text, [ntype], [opts])         -- Send notification (chat + optional toast)
    -- ntype: one of ws.NOTIFY_* constants (default INFO)
    -- opts: optional table with fields like { toast = true/false }

ws.notify_cheat(cheat_name, enabled)     -- Show cheat toggle notification (toast)

ws.set_notify_handler(handler)           -- Override notification handler
    -- handler: function(text, ntype, opts) or nil to restore default
```

---

17. Constraint System (wasplib)
================================

The constraint system limits world interactions to a defined region:

```lua
ws.constraint_pos1                       -- Region corner 1
ws.constraint_pos2                       -- Region corner 2

ws.set_pos1([pos])                       -- Set constraint position 1 (defaults to current pos)
ws.set_pos2([pos])                       -- Set constraint position 2 (defaults to current pos)
ws.reset_constraints()                   -- Clear both positions and their HUD waypoints
ws.inside_constraints(pos) -> bool       -- Check if pos is inside constraints (true if not fully set)

ws.place_if_needed(items, pos, [place])  -- Place items at pos if not already present
ws.dig_if_able(pos)                      -- Dig node at pos if inside constraints

ws.get_nodes_per_tick() -> int           -- Read ws_nodes_per_tick setting (default 8)
ws.get_slot(inv, [filter])               -- Find first slot matching optional filter
ws.get_itemslot_bg_v4(x, y, w, h, [margin])
                                         -- Generate formspec item slot background images
```

---

18. Particle System
===================

Client-side particle API (no server required). Uses tween table format — fields
accept either a single value or `{min=..., max=...}` for random range:

```lua
core.add_particle({
    pos = {x=0, y=0, z=0},
    velocity = {x=0, y=0, z=0},
    acceleration = {x=0, y=0, z=0},
    expirationtime = 1.0,
    size = 1.0,
    collisiondetection = false,
    collision_removal = false,
    object_collision = false,
    vertical = false,
    texture = "particle.png",
    glow = 0,
    -- Optional fields:
    drag = {x=0, y=0, z=0},             -- Air resistance
    jitter = {x=0, y=0, z=0},           -- Random position jitter
    bounce = 0,                          -- Bounce factor on collision
    animation = { tile_w=1, tile_h=1, frame_length=0.2, frame_count=1 },
    node = { name = "...", param2 = 0 }, -- Node-based visual
    node_tile = 0,                       -- Texture tile index for node visual
})

core.add_particlespawner({
    amount = 1,
    time = 0,
    pos = {x=0, y=0, z=0},              -- Tween: single or {min=..., max=...}
    vel = {x=0, y=0, z=0},              -- Velocity (tween)
    acc = {x=0, y=0, z=0},              -- Acceleration (tween)
    size = 1,                            -- Size (tween)
    exptime = 1,                         -- Expiration time (tween)
    collisiondetection = false,
    collision_removal = false,
    object_collision = false,
    vertical = false,
    texture = "particle.png",
    glow = 0,
    -- Optional fields (all tweenable):
    drag = {x=0, y=0, z=0},             -- Air resistance
    jitter = {x=0, y=0, z=0},           -- Random position jitter
    bounce = 0,                          -- Bounce factor on collision
    radius = 0,                          -- Spawn radius (tween)
    texpool = {"tex1.png", "tex2.png"},  -- Random texture pool
    animation = { tile_w=1, tile_h=1, frame_length=0.2, frame_count=1 },
    node = { name = "...", param2 = 0 }, -- Node-based visual
    node_tile = 0,                       -- Texture tile index
    attractor = {
        kind = "point",                  -- "point", "linear", or "radial"
        strength = 1.0,
        origin = {x=0, y=0, z=0},       -- or origin_attached = object_ref
        direction = {x=0, y=0, z=0},    -- for linear attractors
        die_on_contact = false,
    },
}) -> id

core.delete_particlespawner(id)
core.clear_all_particles()               -- Remove all particles and spawners
```

---

License
-------

This documentation applies to Antilua, a fork of Luanti (formerly Minetest).
See `LICENSE.txt` in the repository root for the full license.
