# Litematica Improvements Design

**Goal:** Add client-side MTS schematic parsing via C++ binding, add auto-place mode with inventory check, replace notifications with `ws.notify()`, fix bugs.

---

## Components

### Component 1: `core.parse_mts()` — client-side C++ binding

**Files:**
- Modify: `src/script/lua_api/l_client.h` — add declaration
- Modify: `src/script/lua_api/l_client.cpp` — add implementation and register

Add a new Lua function callable from client mods:

```lua
local schematic = core.parse_mts(mts_binary_string)
-- Returns:
-- {
--   size = {x = 5, y = 3, z = 5},
--   yslice_prob = {127, 127, 127},  -- per-layer probabilities (0-127)
--   nodes = {
--     {x = 0, y = 0, z = 0, name = "mcl_core:dirt", param1 = 0, param2 = 0},
--     ...
--   }
-- }
```

**C++ implementation** to add to `l_client.cpp`:

```cpp
#include "mg_schematic.h"  // for MTSCHEM_* constants
#include "util/serialize.h"  // for readU16/readU32

int ModApiClient::l_parse_mts(lua_State *L)
{
    size_t len;
    const char *data = luaL_checklstring(L, 1, &len);
    std::istringstream is(std::string(data, len));

    // Read + validate signature
    u32 sig = readU32(is);
    if (sig != MTSCHEM_FILE_SIGNATURE)
        throw LuaError("Not a valid MTS file (bad signature)");

    u16 version = readU16(is);
    if (version < 1 || version > MTSCHEM_FILE_VER_HIGHEST_READ)
        throw LuaError("Unsupported MTS version");

    u16 size_x = readU16(is);
    u16 size_y = readU16(is);
    u16 size_z = readU16(is);
    u32 node_count = (u32)size_x * size_y * size_z;

    // Y-slice probabilities
    std::vector<u8> slice_probs;
    if (version >= 3) {
        slice_probs.resize(size_y);
        is.read((char *)slice_probs.data(), size_y);
    }

    // Node name table
    u16 name_count = readU16(is);
    std::vector<std::string> names(name_count);
    for (u16 i = 0; i < name_count; i++) {
        u16 name_len = readU16(is);
        names[i].resize(name_len);
        is.read(&names[i][0], name_len);
    }

    // Decompress bulk data
    std::vector<u8> bulk;
    if (!decompress(bulk, is))
        throw LuaError("Failed to decompress MTS bulk data");

    // Parse bulk: content_ids (u16), param1 (u8), param2 (u8) per node
    u32 content_size = node_count * 2;
    const u8 *bp = bulk.data();
    std::vector<u16> content_ids(node_count);
    for (u32 i = 0; i < node_count; i++)
        content_ids[i] = readU16(bp + i * 2);

    const u8 *param1s = bp + content_size;
    const u8 *param2s = param1s + node_count;

    // Build Lua result table
    lua_newtable(L);

    lua_newtable(L);
    lua_pushinteger(L, size_x); lua_setfield(L, -2, "x");
    lua_pushinteger(L, size_y); lua_setfield(L, -2, "y");
    lua_pushinteger(L, size_z); lua_setfield(L, -2, "z");
    lua_setfield(L, -2, "size");

    lua_newtable(L);
    for (u16 y = 0; y < size_y && y < slice_probs.size(); y++) {
        lua_pushinteger(L, slice_probs[y]);
        lua_rawseti(L, -2, y + 1);
    }
    lua_setfield(L, -2, "yslice_prob");

    lua_newtable(L);
    u32 idx = 1;
    for (u16 z = 0; z < size_z; z++) {
        for (u16 y = 0; y < size_y; y++) {
            for (u16 x = 0; x < size_x; x++) {
                u32 i = z * size_y * size_x + y * size_x + x;
                u16 cid = content_ids[i];
                if (cid >= names.size())
                    continue;
                lua_newtable(L);
                lua_pushinteger(L, x); lua_setfield(L, -2, "x");
                lua_pushinteger(L, y); lua_setfield(L, -2, "y");
                lua_pushinteger(L, z); lua_setfield(L, -2, "z");
                lua_pushstring(L, names[cid].c_str()); lua_setfield(L, -2, "name");
                lua_pushinteger(L, param1s[i]); lua_setfield(L, -2, "param1");
                lua_pushinteger(L, param2s[i]); lua_setfield(L, -2, "param2");
                lua_rawseti(L, -2, idx);
                idx++;
            }
        }
    }
    lua_setfield(L, -2, "nodes");
    return 1;
}
```

Register in `ModApiClient::Initialize()`:
```cpp
API_FCT(parse_mts);
```

---

### Component 2: litematica fixes and improvements

**Files:**
- Modify: `clientmods/DRAGONFIRE/litematica/init.lua`
- Modify: `clientmods/DRAGONFIRE/litematica/settingtypes.txt`

**2a: Fix texture nil crash**

Guard against nil/empty `tt`:
```lua
local function get_texture_by_name(name)
    local def = core.get_node_def(name)
    if not def then return "unknown_node.png" end
    local tt = def.tiles or def.overlay_tiles or def.special_tiles
    if not tt or #tt == 0 then return "unknown_node.png" end
    local tex = tt[1]
    if type(tex) == "table" and tex.name then
        return tex.name
    end
    return tex or "unknown_node.png"
end
```

**2b: Replace notifications with ws.notify()**

- `print(count)` in `/liteload` → `ws.notify("Loaded " .. count .. " nodes", ws.NOTIFY_INFO)`
- `print("pos1 set")` → `ws.notify("pos1 set", ws.NOTIFY_INFO)`
- `print("pos2 set")` → `ws.notify("pos2 set", ws.NOTIFY_INFO)`
- `core.display_chat_message("Saved to ...")` → `ws.notify("Saved to litematica_output", ws.NOTIFY_INFO)`

**2c: Add placelitem.range setting**

```lua
cheat_settings = {
    range = { type = "number", default = 4, min = 1, max = 20 },
    require_item = { type = "bool", default = false },
},
```

Replace hardcoded `<= 4` with:
```lua
local range = tonumber(core.settings:get("placelitem.range")) or 4
```

**2d: Add placelitem.require_item mode**

When enabled, only place nodes the player has in inventory:

```lua
local check_inv = core.settings:get_bool("placelitem.require_item", false)

-- Inside the placement loop:
if ws.can_place_at(pos) then
    if check_inv then
        local had_item = ws.switch_to_item(entry.name)
        if not had_item then
            goto continue  -- LuaJIT goto, or use if/end
        end
    end
    ws.place(pos, entry.name)
    table.remove(place_nodes, i)
end
::continue::
```

**2e: Update `/liteload` to accept MTS via base64 setting**

The `/liteload` command already loads from `litematica_output` (via `$`). Users can store base64-encoded MTS data in that setting. Add a wrapper that decodes and parses:

```lua
core.register_chatcommand("liteload", {
    desc = "Load schematic. Use '$' for litematica_output setting. MTS data via 'mts:...' or base64 in setting.",
    func = function(param)
        local value
        if param == "$" then
            value = core.settings:get("litematica_output")
        else
            value = param
        end
        if not value or value == "" then
            return false, "Need an argument"
        end
        -- Try MTS format (base64)
        local raw = core.decode_base64(value)
        if raw then
            local ok, schematic = pcall(core.parse_mts, raw)
            if ok and schematic and schematic.nodes then
                place_nodes = {}
                for _, node in ipairs(schematic.nodes) do
                    add_node(node, node)
                    table.insert(place_nodes, node)
                end
                ws.notify("Loaded " .. #place_nodes .. " nodes from MTS", ws.NOTIFY_INFO)
                return true
            end
        end
        -- Fall back to WorldEdit string format
        local pos = vector.round(core.localplayer:get_pos())
        local count = litematica_deserialize(pos, value)
        ws.notify("Loaded " .. (count or 0) .. " nodes", ws.NOTIFY_INFO)
        return true
    end,
})
```

Usage:
```
# Store MTS file as base64 in setting
/liteload $  → reads from litematica_output (supports both formats)
```

---

### Component 3: settingtypes.txt

```
placelitem (PlaceLiteM active) bool false
placelitem.range (Placement range) int 4 1 20
placelitem.require_item (Only place if in inventory) bool false
litematica_output (Schematic data) string
```

Remove: `litematica_file`, `litematica_node_names`, `litematica_texture_names`.

---

### Component 4: integration tests

**Files:**
- Create: `clientmods/al_test/test_litematica.lua`
- Modify: `clientmods/al_test/init.lua`

Tests:
- `core.parse_mts` exists and is a function
- `placelitem` cheat setting exists
- `placelitem.range` default is 4
- `placelitem.require_item` default is false
- `/liteload` chat command registered
- `/litepos1` chat command registered
- `/litepos2` chat command registered
- `/litesave` chat command registered

---

### Files changed

| File | Change |
|------|--------|
| `src/script/lua_api/l_client.h` | Add `l_parse_mts` declaration |
| `src/script/lua_api/l_client.cpp` | Implement + register `core.parse_mts()` |
| `litematica/init.lua` | Fixes, range setting, require_item, ws.notify, MTS loading |
| `litematica/settingtypes.txt` | Add placelitem settings, remove unused |
| `litematica/README.md` | Document new features |
| `help/readmes.lua` | Sync |
| `clientmods/al_test/test_litematica.lua` | New tests |
| `clientmods/al_test/init.lua` | Add dofile + test call |
