# Client Mod Bugfixes

**Goal:** Fix 8 confirmed bugs, resolve name collisions, and remove dead code across DragonfireClient client mods.

**Architecture:** Each fix is self-contained to a single file. No cross-cutting concerns. Straightforward one-line or few-line changes.

**Tech Stack:** Lua 5.1 (Luanti)

---

### Task 1: Fix Mv3d disabling wrong setting

**File:** `clientmods/DRAGONFIRE/basic_moves/autofly.lua`

- [ ] **Step 1: Fix the setting name**

Line 46 currently has:
```lua
minetest.settings:set_bool('afly3d', false)
```

Change to:
```lua
minetest.settings:set_bool('aflymv3d', false)
```

This was disabling the Fly3d cheat instead of Mv3d itself when Mv3d reached its destination.

- [ ] **Step 2: Verify syntax**

Run: `luac -p clientmods/DRAGONFIRE/basic_moves/autofly.lua`
Expected: OK

---

### Task 2: Fix FlyNRoof setting name typo

**File:** `clientmods/DRAGONFIRE/basic_moves/autofly.lua`

- [ ] **Step 1: Fix the typo**

Line 119 currently has:
```lua
minetest.settings:set_bool('alfynroof', false)
```

Change to:
```lua
minetest.settings:set_bool('aflynroof', false)
```

Missing `y` in setting name `alfynroof` vs `aflynroof`.

- [ ] **Step 2: Verify syntax**

Run: `luac -p clientmods/DRAGONFIRE/basic_moves/autofly.lua`
Expected: OK

---

### Task 3: Fix farmtool vector.new args swapped

**File:** `clientmods/DRAGONFIRE/farmtool/init.lua`

- [ ] **Step 1: Fix the Reap on_start**

Line 60 currently has:
```lua
if minetest.get_node_or_nil(vector.new(0, -1, 0), v) then
```

The second argument `v` is unused — `get_node_or_nil` only takes one position. Should be:
```lua
if minetest.get_node_or_nil(vector.offset(v, 0, -1, 0)) then
```

- [ ] **Step 2: Verify syntax**

Run: `luac -p clientmods/DRAGONFIRE/farmtool/init.lua`
Expected: OK

---

### Task 4: Fix farmtool v:add() vs vector.add()

**File:** `clientmods/DRAGONFIRE/farmtool/init.lua`

- [ ] **Step 1: Fix table method call**

Line 124 currently has:
```lua
local tp = v:add(vv)
```

`v` is a position table from `find_nodes_near`, not a vector object. Change to:
```lua
local tp = vector.add(v, vv)
```

Also line 128:
```lua
ws.place(vv, dirt)
```

`vv` is an offset vector. Should be:
```lua
ws.place(tp, dirt)
```

- [ ] **Step 2: Verify syntax**

Run: `luac -p clientmods/DRAGONFIRE/farmtool/init.lua`
Expected: OK

---

### Task 5: Fix fishbot nil bobber crash

**File:** `clientmods/DRAGONFIRE/fishbot/init.lua`

- [ ] **Step 1: Add nil guard after bobber lookup**

Lines 37-41 currently:
```lua
if not bpos then
	fb_state = 0
end
```

Fix by adding `return`:
```lua
if not bpos then
	fb_state = 0
	return
end
```

- [ ] **Step 2: Verify syntax**

Run: `luac -p clientmods/DRAGONFIRE/fishbot/init.lua`
Expected: OK

---

### Task 6: Fix litematica double deserialization

**File:** `clientmods/DRAGONFIRE/litematica/init.lua`

- [ ] **Step 1: Add return after version 4/5 block**

After the version 4/5 branch calls `deserialize_workaround`, it falls through to line 192 which calls it again on the full content. Add `return` to prevent the second call:

```lua
	elseif version == 4 or version == 5 then
		content = content:sub(header_len + 1)
		nodes = deserialize_workaround(content)
		return nodes   -- <-- add this line
	end
	nodes = deserialize_workaround(content)
```

- [ ] **Step 2: Verify syntax**

Run: `luac -p clientmods/DRAGONFIRE/litematica/init.lua`
Expected: OK

---

### Task 7: Fix litematica entry.node → entry.name

**File:** `clientmods/DRAGONFIRE/litematica/init.lua`

- [ ] **Step 1: Fix property name**

Line 220 currently has:
```lua
if ws.place(pos, entry.node) then
```

Change to:
```lua
if ws.place(pos, entry.name) then
```

The deserialized schematic stores node names as `entry.name` not `entry.node`.

- [ ] **Step 2: Verify syntax**

Run: `luac -p clientmods/DRAGONFIRE/litematica/init.lua`
Expected: OK

---

### Task 8: Fix litematica PlaceLiteM position comparison

**File:** `clientmods/DRAGONFIRE/litematica/init.lua`

- [ ] **Step 1: Fix the on_step comparison**

Replace the existing `PlaceLiteM.on_step` body with:

```lua
	on_step = function(self, dtime)
		local pp = minetest.localplayer:get_pos()
		pp = vector.round(pp)
		for _, entry in ipairs(place_nodes) do
			if math.abs(entry.x - pp.x) <= 4
			and math.abs(entry.y - pp.y) <= 4
			and math.abs(entry.z - pp.z) <= 4 then
				local pos = vector.new(entry.x, entry.y, entry.z)
				if ws.can_place_at(pos) and ws.place(pos, entry.name) then
					table.remove(place_nodes, _)
				end
			end
		end
	end,
```

- [ ] **Step 2: Verify syntax**

Run: `luac -p clientmods/DRAGONFIRE/litematica/init.lua`
Expected: OK

---

### Task 9: Fix PlaceOn name collision

**Files:**
- `clientmods/DRAGONFIRE/place/init.lua`
- `clientmods/DRAGONFIRE/place/greenup.lua`

- [ ] **Step 1: Remove the dead first PlaceOn registration**

In `place/init.lua`, remove the entire `ws.rg('PlaceOn', ...)` block (the first one, around lines 102-115). The greenup.lua version overwrites it anyway.

- [ ] **Step 2: Verify syntax**

Run: `luac -p clientmods/DRAGONFIRE/place/init.lua && luac -p clientmods/DRAGONFIRE/place/greenup.lua`
Expected: OK

---

### Task 10: Remove dead code across mods

**Files:**
- `clientmods/DRAGONFIRE/basic_moves/init.lua`
- `clientmods/DRAGONFIRE/basic_moves/autofly.lua`
- `clientmods/DRAGONFIRE/basic_moves/flight_hud.lua`
- `clientmods/DRAGONFIRE/litematica/init.lua`

- [ ] **Step 1: Remove dead code from basic_moves/init.lua**

Remove `local nether_rings = {166, 420, 1337, 2666, 3860}` and the empty `local function nearest_portal(pos) if pos.y > 27000 then end end`.

- [ ] **Step 2: Remove dead code from autofly.lua**

Remove `local max_speed = vector.new(4,26,4)` and the unused `autofly.warp` function (search for callers first). Remove any commented-out `--ws.aim(...)` lines.

- [ ] **Step 3: Remove dead code from flight_hud.lua**

Remove unused `bar_up` and `bar_down` local variables.

- [ ] **Step 4: Remove dead code from litematica/init.lua**

Remove `local litefile`, `local modstorage`, and `node_names`/`texture_names` if unreferenced. Remove commented-out metadata handling sections.

- [ ] **Step 5: Verify all syntax**

Run:
```bash
for f in clientmods/DRAGONFIRE/basic_moves/init.lua clientmods/DRAGONFIRE/basic_moves/autofly.lua clientmods/DRAGONFIRE/basic_moves/flight_hud.lua clientmods/DRAGONFIRE/litematica/init.lua; do luac -p "$f" && echo "OK: $f"; done
```
Expected: All OK

---

### Task 11: Verify tests

- [ ] **Step 1: Build and run integration tests**

Run:
```bash
cmake --build build -j3 2>&1 | tail -3
```
Expected: Build succeeds

Run:
```bash
./util/ci/run_df_tests.sh 2>&1 | grep -E "Passed|Failed|ERROR" | tail -5
```
Expected: No new test failures
