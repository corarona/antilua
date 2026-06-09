# FishBot Improvements Plan

**Goal:** Address remaining fishbot issues: add tests, cobot conflict detection, graceful failure on unsupported games.

---

### Task 1: Write integration tests

**Files:**
- Create: `clientmods/df_test/test_fishbot.lua`
- Modify: `clientmods/df_test/init.lua`

Add tests for:
- `core.settings:get("fishbot")` — cheat setting exists with default
- `core.settings:get("fishbot.water_range")` — default setting exists
- `core.settings:get("fishbot.bobber_range")` — default setting exists
- `core.cheats["Bots"]["FishBot"]` exists in the cheat table
- The `fishbot` config table has expected fields (if accessible)

Add to init.lua: dofile + test function call.

---

### Task 2: Add cobot conflict detection

**Files:**
- Modify: `clientmods/DRAGONFIRE/fishbot/init.lua`

FishBot uses `ws.rg` directly (not `sbots.register_bot`) so it misses the sbots cobot conflict detection. Add a manual check in `on_start` that scans for other active bots:

```lua
on_start = function(self)
    -- Cobot check: prevent running alongside other bots
    for _, hack in ipairs(ws.registered_globalhacks) do
        -- ws.registered_globalhacks stores closures, need to check settings
    end
    ...
end
```

This is tricky because `ws.registered_globalhacks` stores closures, not def tables. A simpler approach: check known bot settings directly:

```lua
on_start = function(self)
    local bots = {"autominer", "WitherBot", "FarmBot", "listDigBot",
        "ObsBot", "PlBot", "CrystalBot", "MobsBot", "HostileMobs", "ItemBot"}
    for _, name in ipairs(bots) do
        if core.settings:get_bool(name) then
            ws.notify("Stop other bots first", ws.NOTIFY_WARNING)
            return false
        end
    end
    ...
end
```

---

### Task 3: Graceful failure on unsupported games

**Files:**
- Modify: `clientmods/DRAGONFIRE/fishbot/init.lua`

The current check `ws.game ~= "mineclone"` only warns but lets the cheat activate. It should return `false` to prevent activation:

```lua
if ws.game ~= "mineclone" then
    ws.notify("Fishbot only works on mineclone/ia", ws.NOTIFY_ERROR)
    return false
end
```

Note: This is already fixed in the quick cleanup commit — just documenting here for completeness.
