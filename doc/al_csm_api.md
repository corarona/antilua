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
8. Rendering: ESP and Tracers
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
19. Pathfinding
20. Task Markers & Tracers
21. Extended Object & Entity API
22. LocalPlayer & ClientObjectRef Extensions
23. Strata Pathfinding Bot

---

## 1. Core API Extensions

These functions are added to the global `core.*` table (also available as
`minetest.*`).

### General

```lua
core.get_current_modname() -> string
core.get_modpath(modname) -> string
core.get_last_run_mod() -> string
core.set_last_run_mod(modname)
core.get_builtin_path() -> string
core.get_data_path() -> string              -- Shared data dir (path_user/data/)
core.get_serverdata_path() -> string        -- Per-server data dir (path_user/data/server/<addr>_<port>/)
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
core.write_file(path, data) -> bool|nil,err         -- Write data to file (blocks ".." traversal)
core.decode_image(png_data) -> {width,height,data}|nil,err -- Decode PNG bytes to RGBA pixel data
core.encode_png(width, height, data[, compression]) -> png_bytes -- Encode RGBA pixel data to PNG with libpng (prefilters enabled)
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

## 2. ClientObjectRef (LocalPlayer & entities)

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

:get_roll() -> radians               -- Camera roll angle
:set_roll(radians)                   -- Set camera roll angle

:get_collisionbox() -> [minX, minY, minZ, maxX, maxY, maxZ]
:get_eye_offset() -> {x,y,z}         -- Camera eye offset from player pos (BS)
:get_standing_node() -> {x,y,z}|nil  -- Node under the player's feet
:get_gravity() -> number             -- Current effective gravity (BS/s²)
:can_jump() -> bool                  -- Whether player can jump this frame
:get_autojump() -> bool              -- Current autojump state
:set_autojump(bool)                  -- Enable/disable autojump
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

## 3. Callback Registration

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
core.register_on_damage_sending(func(amount) -> bool)
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

Return `true` from a `register_on_damage_sending` handler to prevent the damage
from being sent to the server. The local player's HP is restored and no damage
effect is shown. Use `core.send_damage(amount)` to send damage explicitly
(bypasses this callback).

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
core.register_on_open_nodemeta_form(func(pos, formspec) -> string|true|nil)
```

- **`on_sending_inventory_fields`**: Called before sending inventory formspec fields to the server.
  Return `true` to cancel the submission.
- **`on_sending_nodemeta_fields`**: Called before sending nodemeta formspec fields.
  Return `true` to cancel the submission.
- **`on_open_nodemeta_form`**: Called when a nodemeta formspec is about to open.
  Return a string to show a modified formspec, `true` to block it, or `nil`/`false` to
  show the original. Callbacks form a chain — each receives the output of the previous one.

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

## 4. Chat Commands

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

## 5. Cheat System

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
| | EntityTracers | `enable_entity_tracers` | Entity tracer lines (Lua-drawn) |
| | PlayerHitboxes | `enable_player_esp` | Player wireframe hitboxes |
| | PlayerWallhack | `enable_player_wallhack` | Through-walls player ESP |
| | PlayerTracers | `enable_player_tracers` | Player tracer lines (Lua-drawn) |
| | NodeESP | `enable_node_esp` | Node bounding-box highlights |
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

### Quick Access Palette (the `~` menu)

The Quick Access Palette (default key `~`, `keymap_quick_select_menu`) is a
searchable list of cheats plus arbitrary entries generated by Lua. Client mods
can register **list providers** that produce entries, and **actions** that
entries can run when activated.

```lua
-- Register a provider: generates entries each time the palette is opened
core.register_quick_menu_provider(function()
	return {
		{ label = "Screenshot", action = function() core.make_screenshot() end },
		{ label = "Reach + FastDig", toggle = { "reach", "fastdig" } },
		{ label = "Toggle Xray", toggle = "xray" },
		{ label = "My Action", action_id = "my_action" },
	}
end)

-- Register an action that entries can reference by id
core.register_quick_menu_action("my_action", function()
	core.display_chat_message("Activated from the ~ menu")
end)

-- Remove a registered action
core.unregister_quick_menu_action("my_action")
```

#### Entry format

Each entry returned by a provider is a table with a `label` (required) and
exactly one activation behavior:

| Field | Type | Description |
|-------|------|-------------|
| `label` | string | Text shown in the palette (used for search + usage sorting) |
| `action` | function | Inline action called when the entry is activated |
| `action_id` | string | Id of a function registered with `core.register_quick_menu_action` |
| `toggle` | string or table | Cheat setting name(s) to flip when activated |
| `keywords` | string or table | Extra search terms matched by the palette search box |
| `description` | string | Short text shown dimmed on the right of the row |
| `is_enabled` | function | Optional; return a boolean shown as the `[x]/[ ]` state |
| `options` | table | Optional second-level submenu entries (see below) |

Cheats are always listed first (alphabetical), followed by provider entries.
When the palette search box has text, results are ranked by match quality
(substring > subsequence > keyword > submenu option label) and then by how
often they were used, and the matched characters are highlighted. Search is
**fuzzy**: e.g. `xry` finds **Xray**, `nfr` finds **NoFallDamage**. A query
that only matches a second-level option label still surfaces the parent entry.

Activating an entry closes the palette. Lua-provided actions are remembered so
a **"↻ Repeat: …"** row at the top of the palette re-runs the last one. When
the search box is empty, a **Recent** section (last toggled cheats/actions,
persisted across sessions) is shown first.

#### Second level (submenu options)

An entry can carry multiple options. Press **TAB** on a selected entry (or
click its trailing `▸`) to open a second level listing them; select one with
`↑/↓` and run it with `↵` (TAB/ESC returns to the entry list).

```lua
core.register_quick_menu_provider(function()
	return {
		{
			label = "Killaura",
			toggle = "killaura",
			options = {
				{ label = "Toggle", toggle = "killaura" },
				{ label = "Settings",
					action = function() core.show_cheat_settings_form("killaura") end },
			},
		},
	}
end)
```

Each option is itself an entry table (`label` + exactly one activation behavior
as above). Cheats listed in the palette always expose a standard option set
even without a provider: **Enable/Disable**, **Settings** (when the cheat
defines `cheat_settings` or `get_formspec`), **Favorite/Unfavorite**, and
**Slot...**. Options may nest — pressing TAB/`→` again descends another level;
`←`/ESC walks back up (the header shows the breadcrumb path).

#### Launcher modes and shortcuts

The palette doubles as a command launcher:

- Type **`.`** followed by a client chat command name (e.g. `.list`) to list
  matching commands from `core.registered_chatcommands`; `↵` runs it. Params
  typed after a space are passed to the command.
- Type **`/`** to send a server chat command (e.g. `/tp 1 2 3`); the single
  **Send** entry issues it.
- **Ctrl+V** pastes the clipboard into the search field.
- With an empty search, pressing a digit **1-9** toggles the cheat bound to
  that quick slot, and slot-bound cheats show a `[N]` badge on their row.
- `↑/↓` navigate, `←/→` walk the submenu stack, `↵` runs, TAB opens/backs out
  of a submenu, `~` closes.

Programmatic control:

```lua
core.quick_menu_open([search])  -- open the palette, optionally pre-filled
core.quick_menu_close()         -- close the palette if it is open
```

Providers are called with the current search text as their only argument when
the palette opens and on every search change, so they can tailor their entries
to the query.

#### Inventory tabs

Every tab registered with `core.inv_tabs.register_tab` (see the `inventory`
mod) is automatically listed in the `~` palette. Activating such an entry
opens the inventory at that tab. A "Player Inventory" entry opens the server's
own inventory (the `main` tab). This is implemented with a quick menu provider
in `clientmods/ANTILUA/inventory/invtabs.lua`, backed by:

```lua
core.inv_tabs.open(id)  -- open the inventory at the given tab (false for unknown ids)
core.open_inventory()   -- trigger the normal inventory open path (C++ binding)
```

The tabs are integrated with the host game's own tab system where present:
mineclone* survival tabs are extended at the top of the form, while the
mineclone* creative inventory (`size[13,11.43]`) renders the Antilua tabs as a
vertical text-button column on the left side (the native content is shifted
right to make room).

#### Clientmod one-shot actions

The `quickmenu` mod registers a provider exposing one-shot actions from other
ANTILUA mods (each entry only appears if its backing mod is loaded):

- **Waypoints/teleport**: Waypoint Here, Show Nearest Waypoint, Hide Waypoints,
  TP to Last Waypoint (client/server), Warp to Nearest Waypoint,
  Rhythm TP Forward, Cancel Rhythm TP, Find Nearest Rail Portal
- **Utilities**: Constraint Pos1/Pos2 Here, Reset Constraints,
  Make Block from Wielded, Eat Food Now, Clear All Particles,
  Select Best Tool for Pointed Node, Clear HUD Markers,
  Loot Nearby Containers (List)
- **Schembuilder**: Open Schematic Browser, Set Schem Pos1/Pos2 Here,
  Clear Schem Build, Undo Schem Placement, Resume Schem Build
- **Bots**: Stop All Bots
- **Dev/UI**: Open Lua IDE, Open Autocraft GUI
- **Info/stats**: Inspect Pointed Thing, Show Session Stats, Show Block Stats,
  Rearrange Cheat Panels, Nodelist show/hide HUD + add wielded/pointed node,
  Analyze Mapblock Age, Clear Age Markers, Logout BlockExchange,
  Save/Load Cheat Profile (Server)
- **Feature toggles** (settings otherwise only reachable via formspecs):
  Fly (Free Move), Show All Waypoints, Log Chat to File,
  Schem Build: Hollow, Schem Build: Wireframe Box, Auto-Take Entity Inv

These wrap the mods' existing chat commands / public functions (via
`core.registered_chatcommands`), so no per-mod changes are needed to add a new
palette entry.

#### Reload behavior

Registrations are tracked per mod. `core.reload_mod()` and DTE mod edits purge
the reloaded mod's stale providers/actions before re-executing `init.lua`, so
they are re-registered cleanly. `core.quick_menu_purge_mod(modname)` does the
same manually (returns the number of removed registrations). Providers
registered from asynchronous callbacks capture origin `"??"` and are not
auto-purged.

#### Introspection / activation

```lua
-- Returns the current resolved list: { {label=..., kind=..., ...}, ... }
-- kind is "cheat" (with `enabled`), "toggle" (with `toggle` list), or "action"
-- Entries with a second level carry an `options` array ({label=..., kind=...}).
local entries = core.get_quick_menu_entries()

-- Run the action for entry at 1-based index (same order as get_quick_menu_entries)
local ok = core.activate_quick_menu_entry(1)
```

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
| | MovementDisplay | `movement_display` | `event_logger` mod |
| | POIShowNames | `poi_shownames` | `poi` mod |
| **Player** | AutoRespawn | `autorespawn` | Engine (Lua builtin) |
| | InvSaver | `invsaver` | `invsaver` mod |
| | HeadSaver | `headsaver` | `wasplib` |
| | LockView | `lockview` | `wasplib` |
| | DeathWaypoints | `auto_death_waypoint` | `poi` mod |
| | AutoScreenshot | `auto_screenshot` | `poi` mod |
| | DeathTP | `death_tp` | `poi` mod |
| **Place** | MultiScaff (Scaffold) | `scaffold` | `place` mod (key Y) |
| | Reap | `farmtool_reap` | `farmtool` mod |
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

## 6. Custom Settings

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
| `enable_node_tracers` | `false` | Node tracer lines |
| `node_tracers_color` | `(255,255,0)` | Node tracer line color |
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

### Camera Roll

| Setting | Default | Description |
|---------|---------|-------------|
| `camera_roll_speed` | `90` | Degrees per second |
| `camera_roll_max` | `180` | Maximum roll angle (set to 360 for full barrel roll) |
| `camera_roll_auto_reset` | `true` | Auto-reset roll to 0 when idle |
| `camera_roll_auto_reset_delay` | `3.0` | Seconds of idle before reset starts |
| `camera_roll_auto_reset_duration` | `0.3` | Duration of smooth roll decay |
| `camera_roll_adaptive_mouse` | `both` | `both` or `pitch` — adapt mouse to roll |

### Pitch Wraparound

| Setting | Default | Description |
|---------|---------|-------------|
| `pitch_wraparound` | `false` | Allow pitch past ±90° for loopings |

### Auto Reconnect

| Setting | Default | Description |
|---------|---------|-------------|
| `auto_reconnect` | `false` | Auto-reconnect on disconnect |
| `auto_reconnect_delay` | `3.0` | Initial reconnect delay (seconds) |
| `auto_reconnect_max_backoff` | `60.0` | Maximum backoff between retries |
| `auto_reconnect_max` | `10` | Maximum reconnect attempts |

---

## 7. Key Bindings

| Key | Default | Action |
|-----|---------|--------|
| `keymap_toggle_cheat_menu` | `TAB` | Open/close cheat menu |
| `keymap_toggle_killaura` | `X` | Toggle killaura |
| `keymap_toggle_freecam` | `G` | Toggle freecam |
| `keymap_toggle_scaffold` | `Y` | Toggle scaffold assist |
| `keymap_enderchest` | `H` | Open ender chest |
| `keymap_camera_roll_left` | `Q` | Roll camera counter-clockwise |
| `keymap_camera_roll_right` | `E` | Roll camera clockwise |
| `keymap_select_up` | `Up` | Cheat menu up |
| `keymap_select_down` | `Down` | Cheat menu down |
| `keymap_select_left` | `Left` | Cheat menu back |
| `keymap_select_right` | `Right` | Cheat menu enter category |
| `keymap_select_confirm` | `F` | Toggle selected cheat |

---

## 8. Rendering: ESP and Tracers

Entity/Player ESP hitbox boxes and wallhack mode are rendered in C++ by the
`DrawTracersAndESP` pipeline step. Tracer lines (entity/player/node) are drawn
from Lua via `core.draw3d` by the wasplib `tracers.lua` cheats, which refresh
their lines every step while enabled.

### Settings

- `enable_entity_esp` — Draws wireframe hitboxes around all entities
- `enable_entity_tracers` — Draws lines from camera to each entity (Lua)
- `enable_entity_wallhack` — Through-walls entity boxes (ECFN_ALWAYS depth test; no color distinction)
- `enable_player_esp` — Draws wireframe hitboxes around other players
- `enable_player_tracers` — Draws lines from camera to each player (Lua)
- `enable_player_wallhack` — Through-walls player boxes (ECFN_ALWAYS depth test; no color distinction)
- `enable_node_esp` — Node bounding-box highlights (C++) using the `node_esp_nodes` filter list
- `enable_node_tracers` — Draws lines from camera to selected nodes (Lua)
- `node_tracers_color` — RGB tuple for node tracer line color
- `entity_esp_color` / `player_esp_color` — RGB tuple for ESP line color

### Implementation Notes

- Tracer lines are rendered by `core.draw3d:add_line` from the wasplib
  `EntityTracers` / `PlayerTracers` / `NodeTracers` cheats
  (`clientmods/ANTILUA/wasplib/tracers.lua`).
- The Lua tracer origin is `core.camera:get_pos() + look_dir * 0.2` (a small
  forward offset avoids near-plane clipping), mirroring the old C++ origin
  `camera_node_position + (look_dir * 0.2 * BS)`.
- ESP hitbox boxes use `draw3DBox`; wallhack re-renders occluded CAO meshes
  with depth overridden.
- `core.get_node_esp_positions()` returns the node positions matching the
  current Node ESP list (set via `core.set_node_esp_list`) within the loaded
  view range; it is used by the NodeTracers cheat. The node scan stays in C++
  so it stays fast.

---

## 9. Raw Packet API

See AGENTS.md for the full raw packet API documentation. Key functions:

```lua
core.send_raw_packet(command, payload)
core.register_on_receiving_raw_packet(func(command_id, payload) -> nil|true|string)
core.register_on_sending_raw_packet(func(command_id, payload) -> nil|true|string)
```

Constant tables `core.TOCLIENT` and `core.TOSERVER` map opcode names to
numeric IDs. Certain init-phase opcodes are blacklisted.

---

## 10. Client-Side Item Override

```lua
core.override_item(name, redefinition)
```

Modify item/node definitions client-side. The `name` and `type` fields in the
redefinition table are rejected (raises a Lua error). Mirrors the server-side
`minetest.override_item()`.

---

## 11. Schematic API (Client-Side)

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

## 12. Client Lua Pipe

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

# 13. Session Detach / Reattach

The client can detach (hide its window, run headlessly) and later reattach.

- **Detach**: `core.detach()` or the "Detach" button in the pause menu.
  The game loop continues (physics, network, Lua) but rendering is suspended.
  A session file is written to `$XDG_RUNTIME_DIR/antilua/session`.
- **Reattach**: Run `antilua --attach` from the terminal. Requires
  `pipe_lua_enable = true` — the reattach command is sent via the Lua pipe.
- **Start fresh**: `antilua --forcenew` bypasses the session check.

---

## 14. The `ws.*` Library (wasplib, ANTILUA modpack)

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

## 15. Globalhack System (wasplib)

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

## 16. Notification System (wasplib)

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

## 17. Constraint System (wasplib)

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

## 18. Particle System

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

## 19. Pathfinding

### `core.find_path(start, end)`

A* pathfinding on the client-side node map. Finds a walkable path between two
positions, accounting for dig time, headroom, and diagonal movement costs.

```lua
core.find_path(start_pos, end_pos) -> {pos,...}
    -- Returns an array of {x,y,z} waypoints in node coordinates.
    -- Returns an empty array if no path is found.
    -- Blocking call; may take hundreds of milliseconds on long paths.
    -- Use `runInThread` from the threading API to avoid lag.
```

Uses `Pathfind` (C++ class in `src/client/pathfind.h`). The pathfinder:
- Evaluates terrain cost based on the player's best available tool in inventory
- Penalises digging through non-air nodes
- Penalises unsteady footing (no walkable block below)
- Checks headroom clearance (2 blocks above)
- Handles diagonal, up, and down movement with appropriate costs

---

## 20. Task Markers & Tracers

Persistent colored visual markers rendered in-world. Implemented on top of
`DrawLuaShapes` — no separate render step needed.

### `core.add_task_node(pos, color)`

Add a colored wireframe box at a world position. The box is 1×1×1 nodes,
centered on `pos`.

```lua
core.add_task_node({x=10, y=20, z=30}, "#FF0000")
    -- pos: v3f position in BS units
    -- color: CSS color string (e.g. "#FF0000", "#00FF00FF") or SColor table
```

### `core.clear_task_node(pos) -> bool`

Remove a task node marker at the given position.

```lua
local ok = core.clear_task_node({x=10, y=20, z=30})
```

### `core.add_task_tracer(start_pos, end_pos, color)`

Add a colored line between two world positions.

```lua
core.add_task_tracer({x=0, y=0, z=0}, {x=10, y=20, z=30}, "#00FF00")
```

### `core.clear_task_tracer(start_pos, end_pos) -> bool`

Remove a task tracer line.

```lua
local ok = core.clear_task_tracer({x=0, y=0, z=0}, {x=10, y=20, z=30})
```

### Settings

The task marker API always renders; there is no gating setting for it.

### Cheat Theme

The cheat menu color theme can be switched via the `cheat_theme` setting.
Individual `theme_*` settings override specific colors within the theme.

```lua
core.settings:set("cheat_theme", "Matrix")  -- green-on-black
core.settings:set("cheat_theme", "Modern")  -- default dark blue-grey
core.settings:set("cheat_theme", "Legacy")
core.settings:set("cheat_theme", "Midnight")
core.settings:set("cheat_theme", "Moss")
core.settings:set("cheat_theme", "Ocean")
core.settings:set("cheat_theme", "Outdoors")
```

Available themes: `Modern`, `Matrix`, `Legacy`, `Midnight`, `Moss`,
`Ocean`, `Outdoors`.

| Setting | Type | Description |
|---------|------|-------------|
| `cheat_theme` | enum | Named color theme (Modern, Matrix, etc.) |
| `theme_bg` | string | Background color (hex `#RRGGBB`) |
| `theme_bg_alpha` | int | Background opacity (0-255) |
| `theme_active_bg` | string | Active/hover item background |
| `theme_active_bg_alpha` | int | Active item background opacity |
| `theme_text` | string | Text color |
| `theme_text_alpha` | int | Text opacity |
| `theme_selected_text` | string | Selected/highlighted text color |
| `theme_panel_bg` | string | Panel background |
| `theme_panel_bg_alpha` | int | Panel background opacity |
| `theme_title_bg` | string | Title bar background |
| `theme_title_bg_alpha` | int | Title bar opacity |
| `theme_border` | string | Border color |
| `theme_border_alpha` | int | Border opacity |
| `theme_item_bg` | string | Item list background |
| `theme_item_bg_alpha` | int | Item background opacity |
| `theme_tooltip_bg` | string | Tooltip background |

---

## 21. Extended Object & Entity API

These functions extend `core.*` with methods from DevClient's client-side
API. Some are registered under improved names with the original names
available as compatibility shims.

### Object Lookup

```lua
core.get_all_objects() -> {ObjectRef,...}
    -- Returns all active objects (entities, players) without radius filter.

core.get_active_object_by_id(id) -> ObjectRef|nil
    -- Get an active object by its numeric ID.
    -- Compat shim: core.get_active_object(id)
```

### World Interaction

```lua
core.start_dig(pos)                    -- Start digging at pos without completing
core.can_attack(object_id) -> bool     -- Check if an entity ID is valid for attacking
core.get_node_name(pos) -> string      -- Shorthand: get node name string at pos
core.all_loaded_nodes() -> {pos,...}   -- Table of all currently loaded node positions
core.nodes_at_block_pos(pos) -> {pos,...} -- Table of all node positions in a mapblock
core.get_node_esp_positions() -> {pos,...} -- Positions of nodes matching the Node ESP list
```

### Item Utilities

```lua
core.get_item_damage_against(slot_index, object_id) -> int
    -- Returns total damage group value of item in inventory slot vs nothing.
    -- Compat shim: core.get_inv_item_damage(slot_index, object_id)

core.get_item_dig_time(slot_index, nodepos) -> float
    -- Returns estimated dig time in seconds for item in slot against node at pos.
    -- Uses the engine's getDigParams().
    -- Compat shim: core.get_inv_item_break(slot_index, nodepos)
```

### Server Info

```lua
core.get_server_url() -> string|nil    -- "address:port" or nil (singleplayer)
core.get_description() -> string       -- Engine description string
core.update_infotexts()                -- Refresh infotext displays (stub)
```

### File Aliases

```lua
core.file_write(path, data)            -- Alias for core.write_file
core.file_append(path, data)           -- Alias for core.append_file
```

### Entity Creation Alias

```lua
core.add_active_object(pos, properties) -> ObjectRef
    -- Alias for core.create_client_entity
```

### Settings

```lua
core.set_fast_speed(speed)             -- Set movement_speed_fast
```

### Media

```lua
core.load_media(filename) -> string|nil
    -- Read a file from <userdata>/textures/custom_assets/<filename>
    -- Returns the file content as a string, or nil on error.
```

---

## 22. LocalPlayer & ClientObjectRef Extensions

### LocalPlayer (`core.localplayer:*`)

```lua
:set_lua_control(control_table)        -- Set player controls from Lua
    -- control_table fields (all optional, default keeps current value):
    --   up, down, left, right: float (0.0 to 1.0)
    --   jump, aux1, sneak, zoom, dig, place: bool
    --   pitch, yaw: float (degrees)

:hud_get_all() -> {[id]=hud_def,...}   -- Returns all HUD elements as a table
    -- Keys are numeric IDs, values are HUD definition tables.

:punch(object_id)                      -- Punch/send interact to a specific entity

:get_time_from_last_punch() -> float   -- Time in seconds since last punch (approx)
```

### ClientObjectRef (entity references from `core.get_objects_inside_radius`, etc.)

```lua
:set_pos(pos)                          -- Set entity position (client-side only)
:set_attachment(parent_id, bone, pos, rot, force_visible)
    -- Attach this object to a parent entity.
    -- parent_id: numeric entity ID
    -- bone: bone name string (empty string for no bone)
    -- pos: v3f attachment position
    -- rot: v3f rotation in degrees
    -- force_visible: bool

:get_id() -> int                       -- Get the numeric ID of this object
```

---

## 23. Strata Pathfinding Bot

The Strata mod (`clientmods/ANTILUA/strata/`) provides autonomous player
movement using A* pathfinding, block mining, and block placement. It
acts as a client-side bot that navigates to a target coordinate by
breaking through obstacles and placing blocks as needed.

### Cheat Setting

Set `strata = true` to enable. Accessible from the cheat menu under
"Player" category, or via:

```lua
core.settings:set_bool("strata", true)
```

### How It Works

1. **`core.find_path()`** computes an A* path from the player's current
   position to the target.
2. **`Strata.compute_actions_required_to_complete_path()`** converts the
   node path into executable actions: `walk`, `jump`, `fall`,
   `mine_block`, `place_block`.
3. Actions are visualized with **task nodes** (red for mining, green for
   placing) and **task tracers** (colored lines between waypoints) via
   `core.add_task_node()` and `core.add_task_tracer()`.
4. A `core.register_globalstep()` handler executes actions one at a time,
   using `core.localplayer:set_lua_control()` for movement and
   `core.interact()` for digging/placing.
5. On completion, a green node appears at the destination. On timeout
   (2 seconds per action), the path is recalculated.

### API

```lua
Strata.set_target(pos)       -- Set destination and start pathfinding
Strata.clear_actions()       -- Stop bot and clear all queued actions
Strata.clear_path_visuals()  -- Remove all task nodes and tracers
```

### Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `strata` | `false` | Enable Strata pathfinding bot |

### Dependencies

- `wasplib` — provides `ws.aim()`, `ws.select_best_tool()`,
  `ws.can_place_at()`, `ws.get_digtime()`
- Uses `core.find_path()`, `core.add_task_node/clear_task_node`,
  `core.add_task_tracer/clear_task_tracer`,
  `core.localplayer:set_lua_control()`, `core.interact()`,
  `core.get_inventory()`, `InventoryAction`

---

## 24. Draw3D API

Client-side 3D shape rendering. Shapes are rendered via a dedicated render
pipeline and persist until cleared. Each shape belongs to an optional group
(default `0`); `clear()` with a group ID removes only that group's shapes.

```lua
core.draw3d:add_sphere(pos, radius, color [, segments, group_id])
    -- pos: v3f center position
    -- radius: float
    -- color: CSS color string or {r,g,b,a} table
    -- segments: int (default 16), sphere tessellation
    -- group_id: int (default 0), grouping for bulk clear

core.draw3d:add_wiresphere(pos, radius, color [, segments, group_id])

core.draw3d:add_box(minp, maxp, color [, group_id])
    -- Axis-aligned filled box from minp to maxp

core.draw3d:add_wirebox(minp, maxp, color [, group_id])
    -- Wireframe (outline) box

core.draw3d:add_line(from, to, color [, group_id])
    -- Line between two positions

core.draw3d:add_circle(pos, radius, color [, segments, group_id])
    -- Horizontal circle at pos (in XZ plane)

core.draw3d:clear([group_id])
    -- Remove all shapes, or all shapes in a specific group
```

---

## 25. Sky API

Control sky, sun, moon, stars, fog, and cloud parameters client-side.

```lua
core.sky:set_sun_visible(bool)
core.sky:set_moon_visible(bool)
core.sky:set_stars_visible(bool)
core.sky:set_star_count(int)
core.sky:set_star_color("#RRGGBB")
core.sky:set_star_scale(float)
core.sky:set_sun_scale(float)
core.sky:set_moon_scale(float)
core.sky:set_body_orbit_tilt(float)      -- Earth axial tilt in degrees
core.sky:set_clouds_enabled(bool)
core.sky:set_fog_distance(float)          -- Far plane distance
core.sky:set_fog_start(float)             -- Fog start ratio (0.0-1.0)
core.sky:set_fog_color("#RRGGBB")

local brightness = core.sky:get_brightness()       -- float 0.0-1.0
local sun_dir   = core.sky:get_sun_direction()     -- {x,y,z} normalized
local moon_dir  = core.sky:get_moon_direction()    -- {x,y,z} normalized
local cloud_col = core.sky:get_cloud_color()       -- {r,g,b,a} table
```

---

## 26. Clouds API

Control cloud parameters client-side.

```lua
core.clouds:set_density(float)            -- 0.0-1.0 cloud coverage
core.clouds:set_height(float)             -- Cloud layer Y height
core.clouds:set_thickness(float)          -- Cloud layer thickness
core.clouds:set_speed({x, z})             -- Cloud movement vector

core.clouds:set_color_bright("#RRGGBB")
core.clouds:set_color_ambient("#RRGGBB")
core.clouds:set_color_shadow("#RRGGBB")

local c = core.clouds:get_color()                   -- {r,g,b,a} table
local inside = core.clouds:is_camera_inside()       -- bool
```

---

## 27. Minimap Marker API

Add colored world-position markers rendered on the minimap surface.

```lua
local id = core.ui.minimap:add_marker({
    pos   = { x = 0, y = 10, z = 0 },
    color = "#FF0000",        -- optional: CSS color string (default red)
})  -- returns numeric id

local ok = core.ui.minimap:remove_marker(id)    -- Remove by id
core.ui.minimap:clear_markers()                  -- Remove all markers

-- Also available on the minimap object:
core.ui.minimap:show() / :hide()
core.ui.minimap:get_pos() / :set_pos(pos)
core.ui.minimap:get_angle() / :set_angle(angle)
core.ui.minimap:get_mode() / :set_mode(mode)
core.ui.minimap:get_shape() / :set_shape(shape)
```

---

## 28. Camera Nametag API

Add world-space nametags rendered as projected 2D text.

```lua
local id = core.camera:add_nametag({
    pos      = { x = 0, y = 10, z = 0 },
    text     = "Hello World",
    color    = "#FFFFFF",        -- optional (default white)
    bgcolor  = "#000000",        -- optional (default transparent)
    size     = 24,               -- optional font size (default 16)
    scale_z  = true,             -- optional distance-based scaling
})

local ok = core.camera:remove_nametag(id)
core.camera:clear_nametags()

-- Also available on the camera object:
core.camera:get_pos() -> pos
core.camera:get_look_dir() -> {x,y,z}
core.camera:get_look_vertical() / :get_look_horizontal() -> degrees
core.camera:get_fov() -> float
core.camera:get_aspect_ratio() -> float
core.camera:set_camera_mode(mode) / :get_camera_mode() -> int
```

---

## 29. IPC API (Inter-Mod Communication)

A shared key-value store accessible from any client-side mod. Supports
compare-and-swap for synchronisation and polling for coordination.

```lua
core.ipc_get(key)                -- Read a value (any Lua type, nil if missing)
core.ipc_set(key, value)         -- Write a value (overwrites existing)
core.ipc_cas(key, old, new)      -- Atomic compare-and-swap (returns bool)
    -- Sets key to new only if current value == old (by reference).
    -- Returns true on success, false on mismatch.

core.ipc_poll(key, timeout_ms)   -- Block until key is set, then return value
    -- Polls every ~1ms for up to timeout_ms. Returns nil on timeout.
    -- Useful for synchronisation between mods.
```

---

License
-------

This documentation applies to Antilua, a fork of Luanti (formerly Minetest).
See `LICENSE.txt` in the repository root for the full license.
