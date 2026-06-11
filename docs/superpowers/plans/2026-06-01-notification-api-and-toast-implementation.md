# Notification API & Toast Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement centralized `ws.notify()` API in wasplib, C++ ToastManager for visual overlays, and migrate cheat feedback to the new system.

**Architecture:** Lua-side notification API (`ws.notify`) sends to both chat and toast. C++ ToastManager (owned by `Client`) renders stacked fading toasts at configurable position. Cheat lifecycle hooks in `ws.globalhacktemplate` auto-generate toggle notifications. Return value convention for `on_start` changes to `false, "reason"` for failure.

**Tech Stack:** Lua 5.1 (Luanti), C++17, IrrlichtMt (video driver + GUI), CMake

---

### Task 1: Create Lua notification API

**Files:**
- Create: `clientmods/DRAGONFIRE/wasplib/notification.lua`
- Modify: `clientmods/DRAGONFIRE/wasplib/init.lua`

- [ ] **Step 1: Write notification.lua**

```lua
-- wasplib notification API
-- Centralized notification system for cheat feedback and user messages

ws.NOTIFY_INFO = "info"
ws.NOTIFY_SUCCESS = "success"
ws.NOTIFY_WARNING = "warning"
ws.NOTIFY_ERROR = "error"

local notify_chat_prefixes = {
	[ws.NOTIFY_INFO] = "[*] ",
	[ws.NOTIFY_SUCCESS] = "[+] ",
	[ws.NOTIFY_WARNING] = "[?] ",
	[ws.NOTIFY_ERROR] = "[!] ",
}

local notify_toast_types = {
	[ws.NOTIFY_INFO] = "info",
	[ws.NOTIFY_SUCCESS] = "success",
	[ws.NOTIFY_WARNING] = "warning",
	[ws.NOTIFY_ERROR] = "error",
}

local default_handler

default_handler = function(text, ntype, opts)
	ntype = ntype or ws.NOTIFY_INFO
	opts = opts or {}

	-- Send to chat
	core.display_chat_message((notify_chat_prefixes[ntype] or "[*] ") .. text)

	-- Send to toast if available and not suppressed
	if opts.toast ~= false and core.show_toast then
		core.show_toast(text, notify_toast_types[ntype] or "info")
	end
end

local current_handler = default_handler

--- Send a notification to chat and optionally as a toast.
-- @param text   The notification text
-- @param ntype  Type: "info" (default), "success", "warning", "error"
-- @param opts   Optional table: { toast = true } (set toast=false for chat-only)
function ws.notify(text, ntype, opts)
	current_handler(text, ntype, opts)
end

--- Convenience notification for cheat toggle events.
function ws.notify_cheat(cheat_name, enabled)
	if enabled then
		ws.notify(cheat_name .. " enabled", ws.NOTIFY_SUCCESS)
	else
		ws.notify(cheat_name .. " disabled", ws.NOTIFY_INFO)
	end
end

--- Override the notification handler (for testing or customization).
-- Pass nil to restore the default handler.
function ws.set_notify_handler(handler)
	if handler then
		current_handler = handler
	else
		current_handler = default_handler
	end
end
```

- [ ] **Step 2: Add dofile to init.lua**

Add after line 21 (`dofile(minetest.get_modpath("wasplib") .. "/compat.lua")`):

```lua
dofile(minetest.get_modpath("wasplib") .. "/notification.lua")
```

- [ ] **Step 3: Run integration tests to verify no regressions**

Run: `./util/ci/run_al_tests.sh`
Expected: All existing tests PASS (no behavior change yet, notification.lua is loaded but unused)

---

### Task 2: Update cheat lifecycle in init.lua

**Files:**
- Modify: `clientmods/DRAGONFIRE/wasplib/init.lua`

- [ ] **Step 1: Update ws.globalhacktemplate() with new lifecycle**

Replace the existing `ws.globalhacktemplate(def)` function body:

```lua
function ws.globalhacktemplate(def)
	local setting = def.setting
	return function(dtime)
		if not minetest.localplayer then return end
		if minetest.settings:get_bool(setting) then
			if tps_client and tps_client.ping and tps_client.ping > 1000 then return end
			if nextact[setting] and nextact[setting] > os.clock() then return end
			nextact[setting] = os.clock() + (def.delay or 0.2)
			if not ghwason[setting] then
				local ok, msg = def.on_start(def)
				if ok ~= false then
					ws.notify_cheat(def.name, true)
					ws.set_bool_bulk(def.daughters, true)
					ghwason[setting] = true
				else
					ws.notify(msg or (def.name .. " failed to activate"), "error")
					minetest.settings:set_bool(setting, false)
				end
			else
				def.on_step(def, dtime)
			end
		elseif ghwason[setting] then
			ghwason[setting] = false
			ws.set_bool_bulk(def.daughters, false)
			ws.notify_cheat(def.name, false)
			def.on_stop(def)
		end
	end
end
```

- [ ] **Step 2: Run integration tests to verify lifecycle**

Run: `./util/ci/run_al_tests.sh`
Expected: All tests PASS including lifecycle tests (notification calls will invoke default handler which calls `core.display_chat_message` — no crash)

---

### Task 3: Create C++ ToastManager header

**Files:**
- Create: `src/gui/toastManager.h`

- [ ] **Step 1: Write toastManager.h**

```cpp
// DragonfireClient
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "irrlichttypes.h"
#include <IGUIFont.h>
#include <string>
#include <vector>

namespace video
{
class IVideoDriver;
}

enum class ToastType
{
	INFO,
	SUCCESS,
	WARNING,
	ERROR
};

struct Toast
{
	std::wstring text;
	ToastType type;
	float elapsed = 0.0f;
};

class ToastManager
{
public:
	ToastManager();
	~ToastManager() = default;

	void addToast(const std::wstring &text, ToastType type);
	void draw(video::IVideoDriver *driver, float dtime);

	void setOrigin(s32 x, s32 y);
	void setMaxToasts(int n);
	void clear();

	bool hasToasts() const { return !m_toasts.empty(); }

	static ToastType stringToType(const std::string &s);

private:
	void update(float dtime);
	video::SColor getBackgroundColor(ToastType type) const;
	video::SColor getTextColor(ToastType type) const;

	std::vector<Toast> m_toasts;
	gui::IGUIFont *m_font = nullptr;
	s32 m_origin_x = -1;  // -1 means center horizontally
	s32 m_origin_y = 10;
	int m_max_toasts = 5;
	s32 m_toast_width = 380;
	s32 m_toast_height = 28;
	s32 m_padding = 6;
	float m_duration = 3.0f;
	float m_fade_start = 2.0f;
};
```

---

### Task 4: Create C++ ToastManager implementation

**Files:**
- Create: `src/gui/toastManager.cpp`

- [ ] **Step 1: Write toastManager.cpp**

```cpp
// DragonfireClient
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "gui/toastManager.h"
#include "fontengine.h"
#include <IVideoDriver.h>
#include <cmath>

ToastManager::ToastManager()
{
	m_font = g_fontengine->getFont();
}

ToastType ToastManager::stringToType(const std::string &s)
{
	if (s == "success")
		return ToastType::SUCCESS;
	if (s == "warning")
		return ToastType::WARNING;
	if (s == "error")
		return ToastType::ERROR;
	return ToastType::INFO;
}

void ToastManager::addToast(const std::wstring &text, ToastType type)
{
	m_toasts.push_back({text, type, 0.0f});

	// Remove oldest if over capacity
	while ((int)m_toasts.size() > m_max_toasts)
		m_toasts.erase(m_toasts.begin());
}

void ToastManager::setOrigin(s32 x, s32 y)
{
	m_origin_x = x;
	m_origin_y = y;
}

void ToastManager::setMaxToasts(int n)
{
	m_max_toasts = n < 1 ? 1 : n;
}

void ToastManager::clear()
{
	m_toasts.clear();
}

void ToastManager::update(float dtime)
{
	for (auto it = m_toasts.begin(); it != m_toasts.end(); )
	{
		it->elapsed += dtime;
		if (it->elapsed >= m_duration)
			it = m_toasts.erase(it);
		else
			++it;
	}
}

video::SColor ToastManager::getBackgroundColor(ToastType type) const
{
	switch (type)
	{
	case ToastType::SUCCESS:
		return video::SColor(200, 20, 60, 30);
	case ToastType::WARNING:
		return video::SColor(200, 60, 40, 10);
	case ToastType::ERROR:
		return video::SColor(200, 60, 20, 20);
	case ToastType::INFO:
	default:
		return video::SColor(200, 30, 40, 60);
	}
}

video::SColor ToastManager::getTextColor(ToastType type) const
{
	return video::SColor(255, 255, 255, 255);
}

void ToastManager::draw(video::IVideoDriver *driver, float dtime)
{
	if (m_toasts.empty())
		return;

	update(dtime);

	if (m_toasts.empty())
		return;

	v2u32 screen = driver->getScreenSize();

	// Compute origin X: center if -1
	s32 origin_x = m_origin_x;
	if (origin_x < 0)
		origin_x = (s32)screen.X / 2 - m_toast_width / 2;

	s32 y = m_origin_y;

	for (auto &toast : m_toasts)
	{
		// Compute alpha fade
		s32 alpha = 255;
		if (toast.elapsed >= m_fade_start && m_duration > m_fade_start)
		{
			float fade_progress = (toast.elapsed - m_fade_start) / (m_duration - m_fade_start);
			alpha = (s32)(255.0f * (1.0f - fade_progress * fade_progress));
			if (alpha < 0)
				alpha = 0;
		}

		video::SColor bg = getBackgroundColor(toast.type);
		bg.setAlpha((u32)(bg.getAlpha() * alpha / 255));

		core::rect<s32> bg_rect(origin_x, y, origin_x + m_toast_width, y + m_toast_height);
		driver->draw2DRectangle(bg, bg_rect, nullptr);

		video::SColor text_col = getTextColor(toast.type);
		text_col.setAlpha((u32)alpha);

		core::rect<s32> text_rect(
			origin_x + 8, y + 2,
			origin_x + m_toast_width - 8, y + m_toast_height - 2);

		if (m_font)
			m_font->draw(toast.text.c_str(), text_rect, text_col, false, true);

		y += m_toast_height + m_padding;
	}
}
```

---

### Task 5: Integrate ToastManager into Client

**Files:**
- Modify: `src/client/client.h`

- [ ] **Step 1: Add forward declaration and member**

After line 48 (`class RenderingEngine;`), add:
```cpp
class ToastManager;
```

After line 610 (`std::unique_ptr<ModChannelMgr> m_modchannel_mgr;`), add:
```cpp
	// DragonfireClient: toast notifications
	std::unique_ptr<ToastManager> m_toast_manager;
```

Add public getter after line 433 (`bool joinModChannel(...)`):
```cpp
	ToastManager *getToastManager();
```

- [ ] **Step 2: Add getter implementation in client.cpp**

Find client.cpp and add:
```cpp
#include "gui/toastManager.h"

ToastManager *Client::getToastManager()
{
	if (!m_toast_manager)
		m_toast_manager = std::make_unique<ToastManager>();
	return m_toast_manager.get();
}
```

---

### Task 6: Integrate ToastManager into Game::drawScene()

**Files:**
- Modify: `src/client/game.cpp`

- [ ] **Step 1: Add draw call after damage flash**

After line 3872 and before `this->driver->endScene();`:

```cpp
	/*
		Toast notifications
	*/
	if (this->client->getToastManager() && this->client->getToastManager()->hasToasts())
		this->client->getToastManager()->draw(this->driver, this->runData.time_from_last_punch);
```

---

### Task 7: Add Lua binding for core.show_toast

**Files:**
- Modify: `src/script/lua_api/l_client.cpp`

- [ ] **Step 1: Add l_show_toast function**

Before `ModApiClient::Initialize`, add:

```cpp
// show_toast(text, type)
int ModApiClient::l_show_toast(lua_State *L)
{
	std::string text = luaL_checkstring(L, 1);
	std::string type = luaL_optstring(L, 2, "info");

	auto *tm = getClient(L)->getToastManager();
	if (tm) {
		tm->addToast(utf8_to_wide(text), ToastManager::stringToType(type));
	}
	return 0;
}
```

- [ ] **Step 2: Register in Initialize()**

After `API_FCT(display_chat_message);` line 693, add:
```cpp
	API_FCT(show_toast);
```

- [ ] **Step 3: Add function declaration in l_client.h**

Check `l_client.h` and add:
```cpp
static int l_show_toast(lua_State *L);
```

---

### Task 8: Update CMakeLists.txt

**Files:**
- Modify: `src/gui/CMakeLists.txt`

- [ ] **Step 1: Add toastManager.cpp to gui_SRCS**

After line 5 (`${CMAKE_CURRENT_SOURCE_DIR}/cheatMenu.cpp`), add:
```
	${CMAKE_CURRENT_SOURCE_DIR}/toastManager.cpp
```

---

### Task 9: Build and verify compilation

- [ ] **Step 1: Build the project**

Run: `cmake --build build -j3`
Expected: Compiles without errors

- [ ] **Step 2: Run integration tests**

Run: `./util/ci/run_al_tests.sh`
Expected: All tests PASS

---

### Task 10: Migrate autofly.lua — return value convention

**Files:**
- Modify: `clientmods/DRAGONFIRE/basic_moves/autofly.lua`

- [ ] **Step 1: Change on_start return value**

Find the on_start function for Fly3d that currently does:
```lua
on_start = function()
	if not poi.last_pos then ws.dcm('Select a poi first.'); return true end
```
Change to:
```lua
on_start = function()
	if not poi.last_pos then return false, 'Select a poi first.' end
```

Check for any other `ws.dcm()` calls in on_start/on_stop in this file and remove redundant toggle feedback.

---

### Task 11: Migrate place/init.lua — remove redundant ws.dcm + convert errors

**Files:**
- Modify: `clientmods/DRAGONFIRE/place/init.lua`

- [ ] **Step 1: Remove toggle feedback ws.dcm calls and convert on_start errors**

Remove all `ws.dcm("...started")` and `ws.dcm("...stopped")` calls — the lifecycle hook now handles toggle notifications.

Convert `ws.dcm('error message'); return true` to `return false, 'error message'` in on_start handlers.

---

### Task 12: Migrate place/walls.lua — remove redundant ws.dcm

**Files:**
- Modify: `clientmods/DRAGONFIRE/place/walls.lua`

- [ ] **Step 1: Remove toggle feedback ws.dcm calls**

Remove `ws.dcm("Ceilingscaff started. ...")` in on_start handler.

---

### Task 13: Migrate farmtool/init.lua — convert ws.dcm to ws.notify

**Files:**
- Modify: `clientmods/DRAGONFIRE/farmtool/init.lua`

- [ ] **Step 1: Convert ws.dcm calls**

- `ws.dcm("No seed wielded.")` → `ws.notify("No seed wielded.", ws.NOTIFY_WARNING)`
- `ws.dcm("Sowing started with "..s)` → `ws.notify("Sowing started with " .. s, ws.NOTIFY_INFO, {toast=false})`

---

### Task 14: Migrate fishbot/init.lua — convert ws.dcm to ws.notify

**Files:**
- Modify: `clientmods/DRAGONFIRE/fishbot/init.lua`

- [ ] **Step 1: Convert ws.dcm calls**

- `ws.dcm("Fishbot only works on mineclone/ia")` → `ws.notify("Fishbot only works on mineclone/ia", ws.NOTIFY_ERROR)`
- `ws.dcm("Put a fishing rod in the hotbar")` → `ws.notify("Put a fishing rod in the hotbar", ws.NOTIFY_WARNING)`

---

### Task 15: Migrate mclminer/init.lua — convert ws.dcm to ws.notify

**Files:**
- Modify: `clientmods/DRAGONFIRE/mclminer/init.lua`

- [ ] **Step 1: Convert LAVAAA message**

- `ws.dcm("LAVAAA")` → `ws.notify("LAVAAA", ws.NOTIFY_WARNING)`

---

### Task 16: Migrate invsaver/init.lua — convert ws.dcm to ws.notify

**Files:**
- Modify: `clientmods/DRAGONFIRE/invsaver/init.lua`

- [ ] **Step 1: Convert death warning**

- `ws.dcm("almost dead - saving shit to ec")` → `ws.notify("Almost dead - saving to ender chest", ws.NOTIFY_WARNING)`

---

### Task 17: Migrate sbots/init.lua — convert ws.dcm to ws.notify

**Files:**
- Modify: `clientmods/DRAGONFIRE/sbots/init.lua`

- [ ] **Step 1: Convert bot conflict message**

- `ws.dcm("Another bot is active.")` → `ws.notify("Another bot is active.", ws.NOTIFY_WARNING)`

---

### Task 18: Migrate wasplib/integrations.lua + dig/sponge.lua + nlist/init.lua + poi/init.lua + devtools/init.lua — chat command feedback

**Files:**
- Modify: `clientmods/DRAGONFIRE/wasplib/integrations.lua`
- Modify: `clientmods/DRAGONFIRE/dig/sponge.lua`
- Modify: `clientmods/DRAGONFIRE/nlist/init.lua`
- Modify: `clientmods/DRAGONFIRE/poi/init.lua`
- Modify: `clientmods/DRAGONFIRE/devtools/init.lua`

- [ ] **Step 1: Convert constraint feedback (integrations.lua)**

- `ws.dcm("constraint pos1 set to "..pstr)` → `ws.notify("Constraint pos1 set to " .. pstr, ws.NOTIFY_INFO, {toast=false})`
- `ws.dcm("constraint pos2 set to "..pstr)` → `ws.notify("Constraint pos2 set to " .. pstr, ws.NOTIFY_INFO, {toast=false})`

- [ ] **Step 2: Convert digcyl command feedback (sponge.lua)**

- `ws.dcm("digcyl center set to "..p)` → `ws.notify("Digcyl center set to " .. p, ws.NOTIFY_INFO, {toast=false})`
- `ws.dcm("digcyl center set to player pos")` → `ws.notify("Digcyl center set to player pos", ws.NOTIFY_INFO, {toast=false})`
- `ws.dcm("digcyl radius set to "..r)` → `ws.notify("Digcyl radius set to " .. r, ws.NOTIFY_INFO, {toast=false})`

- [ ] **Step 3: Convert nodelist feedback (nlist/init.lua)**

- `ws.dcm(node..' added to '..list)` → `ws.notify(node .. " added to " .. list, ws.NOTIFY_INFO, {toast=false})`
- `ws.dcm(node..' removed from '..list)` → `ws.notify(node .. " removed from " .. list, ws.NOTIFY_INFO, {toast=false})`

- [ ] **Step 4: Convert POI feedback (poi/init.lua)**

Convert all `ws.dcm(...)` calls to `ws.notify(..., {toast=false})` with appropriate types (ERROR for errors, INFO for success)

- [ ] **Step 5: Convert devtools feedback (devtools/init.lua)**

- `ws.dcm("Airpocket found at "..s)` → `ws.notify("Airpocket found at " .. s, ws.NOTIFY_INFO, {toast=false})`
- `minetest.display_chat_message(dump(arg))` calls → keep as-is (debug output, not feedback)

---

### Task 19: Write integration tests

**Files:**
- Modify: `clientmods/al_test/test_df_mods.lua`

- [ ] **Step 1: Add notification API tests**

Add tests for:
- `ws.notify()` calls default handler without error
- `ws.set_notify_handler()` override works
- `ws.notify_cheat()` produces correct type
- `ws.notify()` with `{toast=false}` doesn't call `core.show_toast`
- Lifecycle with `return false, "reason"` produces error notification

```lua
-- Test notification API (requires wasplib)
if ws and ws.notify then
	local test_notify = function(name, fn)
		core.al_test_assert(name, fn)
	end

	test_notify("ws.notify() calls handler", function()
		local called = false
		ws.set_notify_handler(function(text, ntype, opts)
			called = true
		end)
		ws.notify("test")
		ws.set_notify_handler(nil)
		return called
	end)

	test_notify("ws.notify_cheat(true) uses success type", function()
		local result_type = nil
		ws.set_notify_handler(function(text, ntype, opts)
			result_type = ntype
		end)
		ws.notify_cheat("TestCheat", true)
		ws.set_notify_handler(nil)
		return result_type == ws.NOTIFY_SUCCESS
	end)

	test_notify("ws.notify_cheat(false) uses info type", function()
		local result_type = nil
		ws.set_notify_handler(function(text, ntype, opts)
			result_type = ntype
		end)
		ws.notify_cheat("TestCheat", false)
		ws.set_notify_handler(nil)
		return result_type == ws.NOTIFY_INFO
	end)

	test_notify("ws.notify() with explicit type", function()
		local result_type = nil
		ws.set_notify_handler(function(text, ntype, opts)
			result_type = ntype
		end)
		ws.notify("test", ws.NOTIFY_ERROR)
		ws.set_notify_handler(nil)
		return result_type == ws.NOTIFY_ERROR
	end)
end
```

---

### Task 20: Final build and test

- [ ] **Step 1: Full build**

Run: `cmake --build build -j3`
Expected: Compiles with no errors

- [ ] **Step 2: Run integration tests**

Run: `./util/ci/run_al_tests.sh`
Expected: All tests PASS

- [ ] **Step 3: Run C++ unit tests**

Run: `./bin/luanti --run-unittests`
Expected: All unit tests PASS

---

## Summary of all file changes

### New files (4)
- `clientmods/DRAGONFIRE/wasplib/notification.lua` — Lua notification API
- `src/gui/toastManager.h` — ToastManager C++ header
- `src/gui/toastManager.cpp` — ToastManager C++ implementation

### Modified files (17+)
- `clientmods/DRAGONFIRE/wasplib/init.lua` — load notification.lua, new lifecycle
- `src/client/client.h` — ToastManager member + getter
- `src/client/client.cpp` — getter implementation
- `src/client/game.cpp` — draw call
- `src/script/lua_api/l_client.cpp` — show_toast binding
- `src/script/lua_api/l_client.h` — declaration
- `src/gui/CMakeLists.txt` — add toastManager.cpp
- `clientmods/DRAGONFIRE/wasplib/integrations.lua` — migrate ws.dcm
- `clientmods/DRAGONFIRE/basic_moves/autofly.lua` — return value convention
- `clientmods/DRAGONFIRE/place/init.lua` — remove redundant ws.dcm
- `clientmods/DRAGONFIRE/place/walls.lua` — remove redundant ws.dcm
- `clientmods/DRAGONFIRE/farmtool/init.lua` — migrate ws.dcm
- `clientmods/DRAGONFIRE/fishbot/init.lua` — migrate ws.dcm
- `clientmods/DRAGONFIRE/mclminer/init.lua` — migrate ws.dcm
- `clientmods/DRAGONFIRE/invsaver/init.lua` — migrate ws.dcm
- `clientmods/DRAGONFIRE/sbots/init.lua` — migrate ws.dcm
- `clientmods/DRAGONFIRE/dig/sponge.lua` — migrate ws.dcm
- `clientmods/DRAGONFIRE/nlist/init.lua` — migrate ws.dcm
- `clientmods/DRAGONFIRE/poi/init.lua` — migrate ws.dcm
- `clientmods/DRAGONFIRE/devtools/init.lua` — migrate ws.dcm
- `clientmods/al_test/test_df_mods.lua` — notification API tests
