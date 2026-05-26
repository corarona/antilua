DragonfireClient CSM API Reference
===================================

This document describes all client-side modding (CSM) API features added by
DragonfireClient — features not present in upstream Luanti. These extend the
`core.*` API, add new Lua callbacks, a cheat menu system, settings, rendering
extensions, and the `ws.*` utility library (wasplib).

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
9. The `ws.*` Library (wasplib)
10. Globalhack System
11. Particle System

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
```

### Player

```lua
core.get_objects_inside_radius(pos, radius) -> {ObjectRef,...}
core.get_inventory(location) -> Inventory     -- "current_player" or nodemeta:"x,y,z"
core.get_item_def(itemstring) -> table
core.get_node_def(nodename) -> table
core.drop_selected_item()
core.set_keypress(key_setting, pressed)       -- Simulate keypress
core.make_screenshot()
core.send_respawn()
core.disconnect()
core.send_damage(damage)                      -- Damage yourself
```

### Item Utilities

```lua
core.find_item(item, min_i, max_i) -> idx     -- Find item in inventory
core.switch_to_item(item) -> bool             -- Switch hotbar to matching item
core.parse_pos(param) -> pos                  -- Parse coords with ~ support
core.parse_relative_pos(param) -> pos         -- Parse relative coords
core.get_nearby_objects(radius) -> {ObjectRef,...}
```

### Info

```lua
core.get_server_info() -> { address, ip, port, protocol_version }
core.get_privilege_list() -> { privname = true, ... }
core.get_csm_restrictions() -> flags
core.gettext(text) -> string
core.get_language() -> string
```

---

2. ClientObjectRef
==================

Returned by `core.get_objects_inside_radius()`, `core.localplayer:get_object()`,
and `core.get_nearby_objects()`.

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

```lua
:get_pos() -> pos
:get_velocity() -> v3f
:get_acceleration() -> v3f
:get_rotation() -> v3f
:is_player() -> bool
:is_local_player() -> bool
:get_name() -> string
:get_nametag() -> string            -- Deprecated
:get_item_textures() -> string      -- Deprecated
:get_properties() -> table
:set_properties(table)              -- Client-side only
:get_hp() -> int
:punch()                            -- Attack entity
:rightclick()
:remove()
```

---

3. Callback Registration
========================

All callbacks available to client-side mods:

```lua
core.register_globalstep(func(dtime))
core.register_on_mods_loaded(func())
core.register_on_shutdown(func())
core.register_on_receiving_chat_message(func(msg) -> bool)
core.register_on_sending_chat_message(func(msg) -> bool)
core.register_on_chatcommand(func(msg))
core.register_on_damage_taken(func(amount))
core.register_on_hp_modification(func(new_hp))
core.register_on_death(func())
core.register_on_dignode(func(pos, node))
core.register_on_punchnode(func(pos, node))
core.register_on_placenode(func(pointed, item))
core.register_on_item_use(func(item, pointed))
core.register_on_formspec_input(func(formname, fields))
core.register_on_receiving_inventory_form(func(formname, formspec))
core.register_on_sending_inventory_fields(func(formname, fields))
core.register_on_sending_nodemeta_fields(func(pos, formname, fields))
core.register_on_open_nodemeta_form(func(pos))
core.register_on_inventory_open(func(inventory))
core.register_on_recieve_physics_override(func(override))
core.register_on_play_sound(func(spec))
core.register_on_spawn_particle(func(particle))
core.register_on_receive_particlespawner(func(spawner))
core.register_on_object_add(func(id))
core.register_on_object_hp_change(func(id))
core.register_on_object_properties_change(func(id))
core.register_on_detached_inventory_update(func(inventory))
core.register_on_modchannel_message(func(channel, sender, message))
core.register_on_modchannel_signal(func(channel, signal))
```

Return `true` from a `register_on_receiving_chat_message` handler to suppress
the message.

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
core.cheats["Combat"]["AntiKnockback"]  = "antiknockback"
core.cheats["Movement"]["JetPack"]      = "jetpack"
core.cheats["Render"]["Xray"]           = "xray"
core.cheats["Interact"]["FastDig"]      = "fastdig"
core.cheats["Player"]["Reach"]          = "reach"
core.cheats["Exploit"]["EntitySpeed"]   = "entity_speed"
```

### Registration

```lua
core.register_cheat(cheatname, category, func_or_setting)
```

When called from a Lua mod, the third parameter is the setting name (a string)
or a function. The cheat menu displays the category/name and toggles the
corresponding setting.

### Built-in Cheat Categories & Cheats

| Category | Cheat | Setting | Effect |
|----------|-------|---------|--------|
| **Combat** | AntiKnockback | `antiknockback` | No knockback |
| | AttachmentFloat | `float_above_parent` | Float above mounts |
| **Movement** | Freecam | `freecam` | Detached camera |
| | AutoForward | `continuous_forward` | Auto-run |
| | PitchMove | `pitch_move` | Move in look direction |
| | AutoJump | `autojump` | Auto-jump obstacles |
| | Jesus | `jesus` | Walk on water |
| | NoSlow | `no_slow` | No movement slowdown |
| | JetPack | `jetpack` | Fly with jump key |
| | AntiSlip | `antislip` | No ice slipping |
| | AirJump | `airjump` | Jump in mid-air |
| | Spider | `spider` | Climb walls |
| **Render** | Xray | `xray` | See through terrain |
| | Fullbright | `fullbright` | Always max light |
| | HUDBypass | `hud_flags_bypass` | Ignore server HUD flags |
| | NoHurtCam | `no_hurt_cam` | No damage screen shake |
| | BrightNight | `no_night` | Always daytime |
| | Coords | `coords` | Position HUD |
| | CheatHUD | `cheat_hud` | Active cheats overlay |
| | EntityESP | `enable_entity_esp` | Entity bounding boxes |
| | EntityTracers | `enable_entity_tracers` | Entity tracer lines |
| | PlayerESP | `enable_player_esp` | Player bounding boxes |
| | PlayerTracers | `enable_player_tracers` | Player tracer lines |
| | NodeESP | `enable_node_esp` | *planned* |
| | NodeTracers | `enable_node_tracers` | *planned* |
| **Interact** | FastDig | `fastdig` | Faster digging |
| | FastPlace | `fastplace` | Faster placement |
| | AutoDig | `autodig` | Auto-dig nearest |
| | AutoPlace | `autoplace` | Auto-place blocks |
| | InstantBreak | `instant_break` | One-hit break |
| | FastHit | `spamclick` | Auto-click |
| | AutoHit | `autohit` | Auto-hit entities |
| **Player** | NoFallDamage | `prevent_natural_damage` | No environmental damage |
| | NoForceRotate | `no_force_rotate` | No forced rotation |
| | Reach | `reach` | Extended interaction range |
| | PointLiquids | `point_liquids` | Select liquid nodes |
| | PrivBypass | `priv_bypass` | Bypass privilege checks |
| | AutoRespawn | `autorespawn` | Auto-respawn on death |
| | ThroughWalls | `dont_point_nodes` | Don't auto-point nodes |
| **Exploit** | EntitySpeed | `entity_speed` | Entities at player speed |

Cheats can be toggled via the cheat menu (default `F8`) or by setting the
corresponding setting to `"true"` / `"false"`.

---

6. Custom Settings
==================

These settings exist only in DragonfireClient. Set via `core.settings:set()`,
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
| `no_night` | `false` | Always daytime |
| `coords` | `false` | Show position HUD |
| `point_liquids` | `false` | Point/select liquids |
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
| `enable_entity_esp` | `false` | Entity bounding boxes |
| `enable_entity_tracers` | `false` | Entity tracer lines |
| `enable_player_esp` | `false` | Player bounding boxes |
| `enable_player_tracers` | `false` | Player tracer lines |
| `node_esp_nodes` | `""` | Node ESP filter list |
| `entity_esp_color` | `(255,255,255)` | ESP line color |
| `player_esp_color` | `(255,255,255)` | Player ESP color |

### Cheat Menu Styling

| Setting | Default | Description |
|---------|---------|-------------|
| `cheat_menu_font` | `""` | Font face |
| `cheat_menu_bg_color` | `#222222` | Background color |
| `cheat_menu_bg_color_alpha` | `200` | Background opacity |
| `cheat_menu_active_bg_color` | `#444444` | Active item bg |
| `cheat_menu_active_bg_color_alpha` | `200` | Active item opacity |
| `cheat_menu_font_color` | `#ffffff` | Font color |
| `cheat_menu_font_color_alpha` | `255` | Font opacity |
| `cheat_menu_selected_font_color` | `#ffcc00` | Selected item color |
| `cheat_menu_selected_font_color_alpha` | `255` | Selected opacity |
| `cheat_menu_head_height` | `30` | Header height |
| `cheat_menu_entry_height` | `25` | Entry height |
| `cheat_menu_entry_width` | `25` | Entry width |

---

7. Key Bindings
===============

| Key | Default | Action |
|-----|---------|--------|
| `keymap_toggle_cheat_menu` | `F8` | Open/close cheat menu |
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

- `enable_entity_esp` — Draws bounding boxes around all entities
- `enable_entity_tracers` — Draws lines from camera to each entity
- `enable_player_esp` — Draws bounding boxes around other players
- `enable_player_tracers` — Draws lines from camera to each player
- `entity_esp_color` / `player_esp_color` — RGB triple for line color

### Implementation Notes

- The tracer origin is `camera_node_position + (look_dir * 0.2 * BS)`,
  NOT `camera:getPosition()` (which maps incorrectly in view space).
- Boxes use `draw3DBox` and lines use `draw3DLine`.
- Node ESP/Tracers (`enable_node_esp`, `enable_node_tracers`) are declared
  but not yet implemented in the C++ render pipeline.

---

9. The `ws.*` Library (wasplib)
================================

The `ws` global namespace is provided by the `wasplib` mod (part of the
`DRAGONFIRE` modpack). Load order: settings → coord → inventory → tools →
world → combat → waypoints.

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
```

### Tools (`ws.tools.*`)

```lua
ws.get_digtime(nodename)                 -- Best dig time for node
ws.select_best_tool(pos_or_nodename)     -- Switch to best tool
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

10. Globalhack System
=====================

The globalhack system provides a framework for toggleable cheat features that
run every globalstep. It is part of wasplib.

### Core

```lua
ws.registered_globalhacks = {}            -- All registered hack functions
```

### Templates

```lua
ws.globalhacktemplate(setting, func, funcstart, funcstop, daughters, delay)
    -- Creates a handler function that:
    --   * Checks `minetest.settings:get_bool(setting)` each step
    --   * Calls funcstart() on activation (if it returns false)
    --   * Calls func(dtime) each step while active
    --   * Calls funcstop() on deactivation
    --   * Toggles daughter settings via ws.set_bool_bulk
    --   * Rate-limited by `delay` (default 0.2s)

ws.register_globalhack(func)
    -- Appends func to ws.registered_globalhacks

ws.register_globalhacktemplate(name, category, setting, func, funcstart, funcstop, daughters, delay)
    -- Combinator: creates template + registers hack + registers cheat
    -- (via minetest.register_cheat and the cheat menu)

ws.rg = ws.register_globalhacktemplate  -- Shorthand

ws.step_globalhacks(dtime)
    -- Iterates ws.registered_globalhacks, called from
    -- minetest.register_globalstep

ws.on_connect(func)
    -- Defers func until core.localplayer is available
    -- (polls via minetest.after)
```

### Example

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

---

11. Particle System
===================

Client-side particle API (no server required):

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
    playername = nil,
    glow = 0,
})

core.add_particlespawner({
    amount = 1,
    time = 0,
    minpos = {x=0, y=0, z=0},
    maxpos = {x=0, y=0, z=0},
    minvel = {x=0, y=0, z=0},
    maxvel = {x=0, y=0, z=0},
    minacc = {x=0, y=0, z=0},
    maxacc = {x=0, y=0, z=0},
    minexptime = 1,
    maxexptime = 1,
    minsize = 1,
    maxsize = 1,
    collisiondetection = false,
    collision_removal = false,
    object_collision = false,
    vertical = false,
    texture = "particle.png",
    playername = nil,
    glow = 0,
}) -> id

core.delete_particlespawner(id)
```

---

License
-------

This documentation applies to DragonfireClient, a fork of Luanti (formerly
Minetest). See `LICENSE.txt` in the repository root for the full license.
