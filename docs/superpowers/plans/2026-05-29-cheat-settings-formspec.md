# Cheat Settings: Formspec-Only Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace C++ inline cheat settings panel with the existing Lua formspec system

**Architecture:** Remove `CheatSettingWidget` struct, `openCheatSettings()` method, and all inline-settings fields/logic from `cheatMenu.cpp`/`.h`. Clicking a cheat's gear icon calls `ScriptApiCheats::show_cheat_settings()` which triggers `core.show_cheat_settings_form()` in `builtin/client/cheats.lua` — already handles all types + custom formspecs.

**Tech Stack:** C++17, Lua 5.1, IrrlichtMt GUI

---

### Task 1: Remove CheatSettingWidget and unused panel fields

**Files:**
- Modify: `src/gui/cheatMenu.h`

- [ ] **Step 1: Remove the CheatSettingWidget struct**

```cpp
// DELETE entire struct (lines 46-51)
struct CheatSettingWidget {
	std::string key;
	std::string type; // "bool", "number", "string"
	std::string value;
	std::string full_setting;
};
```

- [ ] **Step 2: Remove unused fields from CheatPanel struct**

```cpp
// DELETE from CheatPanel (lines 57, 58, 68, 69, 70)
	int selected_setting = 0;
	std::vector<CheatSettingWidget> settings;

// DELETE from CheatPanel (lines 69-71)
	int hover_setting = -1;
	int show_settings_for = -1; // cheat index with expanded settings, -1 = none
	std::vector<CheatSettingWidget> expanded_settings; // settings for the expanded cheat
```

Resulting CheatPanel should be:

```cpp
struct CheatPanel {
	std::string id;
	int selected_category = 0;
	int selected_cheat = 0;
	s32 x = 0, y = 0, w = 220, h = 0;
	s32 title_h = 30;
	bool pinned = false;
	bool keyboard_focus = false;
	bool hover_close = false;
	bool hover_title = false;
	bool hover_pin = false;
	bool hover_focus = false;
	int hover_item = -1;
};
```

- [ ] **Step 3: Remove openCheatSettings from private method declarations**

```cpp
// DELETE from class CheatMenu (line 95)
	void openCheatSettings(ScriptApiCheatsCheat *cheat, CheatPanel *parent);
```

- [ ] **Step 4: Run build to verify header compiles**

```bash
cmake --build build -j3 2>&1 | head -40
```

Expected: compile errors in `cheatMenu.cpp` referencing removed fields (expected — we'll fix those in next tasks)

---

### Task 2: Remove expanded settings rendering from drawPanel

**Files:**
- Modify: `src/gui/cheatMenu.cpp`

- [ ] **Step 1: Remove show_settings_for height calculation in drawPanel**

```cpp
// OLD (lines 143-146):
	} else if (isCatPanel(panel)) {
		h += (s32)script->m_cheat_categories[panel.selected_category]->m_cheats.size() * (m_entry_height + m_gap);
		if (panel.show_settings_for >= 0)
			h += (s32)panel.expanded_settings.size() * (m_entry_height + m_gap);
	} else if (isSetPanel(panel)) {
		h += (s32)panel.settings.size() * (m_entry_height + m_gap);
	}

// NEW:
	} else if (isCatPanel(panel)) {
		h += (s32)script->m_cheat_categories[panel.selected_category]->m_cheats.size() * (m_entry_height + m_gap);
	}
```

- [ ] **Step 2: Remove isSetPanel case from title text**

```cpp
// OLD (line 169):
	else if (isSetPanel(panel)) title = panel.id.substr(5) + " Settings";

// NEW:
	// (remove the entire else if line — title stays empty for set panels, but they won't exist)
```

Keep it simple:
```cpp
// OLD (lines 167-169):
	if (isMainPanel(panel)) title = "Cheat Menu";
	else if (isCatPanel(panel)) title = script->m_cheat_categories[panel.selected_category]->m_name;
	else if (isSetPanel(panel)) title = panel.id.substr(5) + " Settings";

// NEW:
	if (isMainPanel(panel)) title = "Cheat Menu";
	else if (isCatPanel(panel)) title = script->m_cheat_categories[panel.selected_category]->m_name;
```

- [ ] **Step 3: Remove hover_setting reset in cat panel draw**

```cpp
// OLD (line 223):
		panel.hover_setting = -1;

// NEW:
		// (delete this line)
```

- [ ] **Step 4: Remove the has_settings check and gear icon draw**

The gear icon (lines 251-261) should remain — it's the UI affordance for opening the settings formspec. But it no longer needs `show_settings_for` highlight state. Simplify:

```cpp
// OLD (lines 251-261):
				// Settings button
				if (has_set) {
					s32 sbx = x + w - 18;
					bool hov = point_in_rect(mouse_pos.X, mouse_pos.Y, sbx, iy, 16, m_entry_height);
					if (hov) panel.hover_setting = chi;
					video::SColor sbtn = (chi == panel.show_settings_for) ? video::SColor(200, 80, 120, 120) :
						(hov ? video::SColor(200, 100, 120, 80) : video::SColor(180, 60, 60, 70));
					driver->draw2DRectangle(sbtn, core::rect<s32>(sbx, iy, sbx + 16, iy + m_entry_height));
					drawText(m_font, "\u2699", sbx + 3, iy + (m_entry_height - m_fontsize.Y) / 2,
						video::SColor(255, 200, 200, 100));
				}

// NEW:
				// Settings gear icon (opens formspec on click)
				if (has_set) {
					s32 sbx = x + w - 18;
					bool hov = point_in_rect(mouse_pos.X, mouse_pos.Y, sbx, iy, 16, m_entry_height);
					video::SColor sbtn = hov ? video::SColor(200, 100, 120, 80) : video::SColor(180, 60, 60, 70);
					driver->draw2DRectangle(sbtn, core::rect<s32>(sbx, iy, sbx + 16, iy + m_entry_height));
					drawText(m_font, "\u2699", sbx + 3, iy + (m_entry_height - m_fontsize.Y) / 2,
						video::SColor(255, 200, 200, 100));
				}
```

- [ ] **Step 5: Remove expanded settings rendering block**

```cpp
// DELETE entirely (lines 265-314):
				// Expand settings inline when show_settings_for matches
				if (chi == panel.show_settings_for && has_set) {
					// Load settings data if not already loaded
					if (panel.expanded_settings.empty()) {
						lua_State *L2 = m_client->getScript()->getLuaState();
						lua_getglobal(L2, "core");
						lua_getfield(L2, -1, "cheat_defs");
						lua_getfield(L2, -1, cheat->m_setting.c_str());
						if (lua_istable(L2, -1)) {
							lua_getfield(L2, -1, "cheat_settings");
							if (lua_istable(L2, -1)) {
								lua_pushnil(L2);
								while (lua_next(L2, -2)) {
									std::string sk = lua_tostring(L2, -2);
									if (lua_istable(L2, -1)) {
										CheatSettingWidget sw;
										sw.key = sk;
										sw.full_setting = cheat->m_setting + "." + sk;
										lua_getfield(L2, -1, "type");
										if (lua_isstring(L2, -1)) sw.type = lua_tostring(L2, -1);
										lua_pop(L2, 1);
										panel.expanded_settings.push_back(sw);
									}
									lua_pop(L2, 1);
								}
							}
							lua_pop(L2, 1);
						}
						lua_pop(L2, 3);
					}
					// Draw settings
					s32 si = 0;
					for (auto &sw : panel.expanded_settings) {
						s32 sx = x + 15;
						video::SColor s_bg = (si == panel.selected_setting) ? m_active_bg_color : video::SColor(180, 50, 50, 65);
						driver->draw2DRectangle(s_bg, core::rect<s32>(sx, iy, x + w - 1, iy + m_entry_height));
						if (point_in_rect(mouse_pos.X, mouse_pos.Y, sx, iy, w - 15, m_entry_height))
							panel.hover_setting = -(chi * 100 + si + 1);
						if (sw.type == "bool") {
							bool val = g_settings->getBool(sw.full_setting);
							std::string stxt = std::string("  ") + (val ? "[x]" : "[ ]") + " " + sw.key;
							drawText(m_font, stxt, sx + 5, iy + (m_entry_height - m_fontsize.Y) / 2, m_font_color);
						} else {
							std::string val = g_settings->get(sw.full_setting);
							drawText(m_font, "  " + sw.key + ": " + val, sx + 5, iy + (m_entry_height - m_fontsize.Y) / 2, m_font_color);
						}
						iy += m_entry_height + m_gap;
						si++;
					}
				}
```

- [ ] **Step 6: Remove the isSetPanel draw branch**

```cpp
// DELETE entirely (lines 319-340):
	} else if (isSetPanel(panel)) {
		panel.hover_item = -1;
		int si = 0;
		for (auto &s : panel.settings) {
			video::SColor sbg = (si == panel.selected_setting) ? m_active_bg_color : m_bg_color;
			driver->draw2DRectangle(sbg, core::rect<s32>(x, iy, x + w, iy + m_entry_height));
			if (point_in_rect(mouse_pos.X, mouse_pos.Y, x, iy, w, m_entry_height))
				panel.hover_item = si;
			if (s.type == "bool") {
				bool val = g_settings->getBool(s.full_setting);
				std::string txt = std::string("[") + (val ? "x" : " ") + "] " + s.key;
				panel.hover_item = si;
				drawText(m_font, txt, x + 5, iy + (m_entry_height - m_fontsize.Y) / 2, m_font_color);
			} else {
				std::string val = g_settings->get(s.full_setting);
				drawText(m_font, s.key + ": " + val, x + 5, iy + (m_entry_height - m_fontsize.Y) / 2, m_font_color);
			}
			iy += m_entry_height + m_gap;
			si++;
		}
	}
```

- [ ] **Step 7: Run build**

```bash
cmake --build build -j3 2>&1 | head -40
```

Expected: fewer errors but still some in handleMouse and other functions

---

### Task 3: Change gear icon click to open formspec in handleMouse

**Files:**
- Modify: `src/gui/cheatMenu.cpp`

- [ ] **Step 1: Replace gear icon click handler to call show_cheat_settings**

```cpp
// OLD (lines 488-504):
					// Check cheat row click
					if (point_in_rect(pos.X, pos.Y, x, iy, w, m_entry_height)) {
						s32 sbx = x + w - 18;
						if (point_in_rect(pos.X, pos.Y, sbx, iy, 16, m_entry_height)) {
							if (panel.show_settings_for == chi) {
								panel.show_settings_for = -1;
								panel.expanded_settings.clear();
							} else {
								panel.show_settings_for = chi;
								panel.expanded_settings.clear();
							}
						} else {
							panel.selected_cheat = chi;
							script->toggle_cheat(cheat);
						}
						return;
					}

// NEW:
					// Check cheat row click
					if (point_in_rect(pos.X, pos.Y, x, iy, w, m_entry_height)) {
						s32 sbx = x + w - 18;
						if (point_in_rect(pos.X, pos.Y, sbx, iy, 16, m_entry_height)) {
							script->show_cheat_settings(cheat->m_setting);
						} else {
							panel.selected_cheat = chi;
							script->toggle_cheat(cheat);
						}
						return;
					}
```

- [ ] **Step 2: Remove expanded settings mouse handling block**

```cpp
// DELETE entirely (lines 471-487):
					// Check expanded settings area first (appears below the cheat row)
					if (chi == panel.show_settings_for) {
						int si = 0;
						for (auto &sw : panel.expanded_settings) {
							s32 sx = x + 15;
							if (point_in_rect(pos.X, pos.Y, sx, iy, w - 15, m_entry_height)) {
								panel.selected_setting = si;
								if (sw.type == "bool") {
									bool val = g_settings->getBool(sw.full_setting);
									g_settings->setBool(sw.full_setting, !val);
								}
								return;
							}
							iy += m_entry_height + m_gap;
							si++;
						}
					}
```

- [ ] **Step 3: Remove the isSetPanel mouse handling branch**

```cpp
// DELETE entirely (lines 509-523):
		} else if (isSetPanel(panel)) {
			int si = 0;
			for (auto &s : panel.settings) {
				if (point_in_rect(pos.X, pos.Y, x, iy, w, m_entry_height)) {
					panel.selected_setting = si;
					if (s.type == "bool") {
						bool val = g_settings->getBool(s.full_setting);
						g_settings->setBool(s.full_setting, !val);
					}
					return;
				}
				iy += m_entry_height + m_gap;
				si++;
			}
		}
```

- [ ] **Step 4: Run build**

```bash
cmake --build build -j3 2>&1 | head -40
```

Expected: should compile cleanly or very close (still need to remove openCheatSettings)

---

### Task 4: Remove openCheatSettings method

**Files:**
- Modify: `src/gui/cheatMenu.cpp`

- [ ] **Step 1: Delete the entire openCheatSettings method**

```cpp
// DELETE entirely (lines 527-578):
void CheatMenu::openCheatSettings(ScriptApiCheatsCheat *cheat, CheatPanel *parent)
{
	std::string sid = "_set_" + cheat->m_name;
	for (auto &p : m_panels)
		if (p.id == sid) return;

	lua_State *L = m_client->getScript()->getLuaState();
	lua_getglobal(L, "core");
	lua_getfield(L, -1, "cheat_defs");
	lua_getfield(L, -1, cheat->m_setting.c_str());
	bool has_settings = false;
	if (lua_istable(L, -1)) {
		lua_getfield(L, -1, "cheat_settings");
		has_settings = lua_istable(L, -1) || lua_isfunction(L, -1);
		lua_pop(L, 1);
	}
	lua_pop(L, 3);

	if (!has_settings) return;

	CheatPanel sp;
	sp.id = sid;
	sp.x = parent->x + parent->w + 10;
	sp.y = parent->y;
	loadPanelPosition(sp);

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "cheat_defs");
	lua_getfield(L, -1, cheat->m_setting.c_str());
	if (lua_istable(L, -1)) {
		lua_getfield(L, -1, "cheat_settings");
		if (lua_istable(L, -1)) {
			lua_pushnil(L);
			while (lua_next(L, -2)) {
				std::string key = lua_tostring(L, -2);
				if (lua_istable(L, -1)) {
					CheatSettingWidget w;
					w.key = key;
					w.full_setting = cheat->m_setting + "." + key;
					lua_getfield(L, -1, "type");
					if (lua_isstring(L, -1)) w.type = lua_tostring(L, -1);
					lua_pop(L, 1);
					sp.settings.push_back(w);
				}
				lua_pop(L, 1);
			}
		}
		lua_pop(L, 1);
	}
	lua_pop(L, 3);
	m_panels.push_back(sp);
}
```

- [ ] **Step 2: Run build**

```bash
cmake --build build -j3 2>&1 | head -40
```

Expected: may still have errors from selectUp/selectDown/selectRight/selectLeft (next task)

---

### Task 5: Remove isSetPanel keyboard navigation

**Files:**
- Modify: `src/gui/cheatMenu.cpp`

- [ ] **Step 1: Remove isSetPanel branch from selectUp**

```cpp
// OLD (lines 634-646):
	if (isCatPanel(*panel)) {
		int max = (int)script->m_cheat_categories[panel->selected_category]->m_cheats.size() - 1;
		panel->selected_cheat--;
		if (panel->selected_cheat < 0) panel->selected_cheat = max;
	} else if (isSetPanel(*panel)) {
		int max = (int)panel->settings.size() - 1;
		panel->selected_setting--;
		if (panel->selected_setting < 0) panel->selected_setting = max;
	} else if (isMainPanel(*panel)) {
		int max = (int)script->m_cheat_categories.size() - 1;
		panel->selected_category--;
		if (panel->selected_category < 0) panel->selected_category = max;
	}

// NEW:
	if (isCatPanel(*panel)) {
		int max = (int)script->m_cheat_categories[panel->selected_category]->m_cheats.size() - 1;
		panel->selected_cheat--;
		if (panel->selected_cheat < 0) panel->selected_cheat = max;
	} else if (isMainPanel(*panel)) {
		int max = (int)script->m_cheat_categories.size() - 1;
		panel->selected_category--;
		if (panel->selected_category < 0) panel->selected_category = max;
	}
```

- [ ] **Step 2: Remove isSetPanel branch from selectDown**

```cpp
// OLD (lines 657-669):
	if (isCatPanel(*panel)) {
		int max = (int)script->m_cheat_categories[panel->selected_category]->m_cheats.size() - 1;
		panel->selected_cheat++;
		if (panel->selected_cheat > max) panel->selected_cheat = 0;
	} else if (isSetPanel(*panel)) {
		int max = (int)panel->settings.size() - 1;
		panel->selected_setting++;
		if (panel->selected_setting > max) panel->selected_setting = 0;
	} else if (isMainPanel(*panel)) {
		int max = (int)script->m_cheat_categories.size() - 1;
		panel->selected_category++;
		if (panel->selected_category > max) panel->selected_category = 0;
	}

// NEW:
	if (isCatPanel(*panel)) {
		int max = (int)script->m_cheat_categories[panel->selected_category]->m_cheats.size() - 1;
		panel->selected_cheat++;
		if (panel->selected_cheat > max) panel->selected_cheat = 0;
	} else if (isMainPanel(*panel)) {
		int max = (int)script->m_cheat_categories.size() - 1;
		panel->selected_category++;
		if (panel->selected_category > max) panel->selected_category = 0;
	}
```

- [ ] **Step 3: Remove expanded_settings toggle from selectRight**

```cpp
// OLD (lines 698-706):
	} else if (isCatPanel(*panel)) {
		if (panel->selected_cheat == panel->show_settings_for) {
			panel->show_settings_for = -1;
			panel->expanded_settings.clear();
		} else {
			panel->show_settings_for = panel->selected_cheat;
			panel->expanded_settings.clear();
		}
	}

// NEW:
	} else if (isCatPanel(*panel)) {
		// gear icon → formspec, no inline expand
	}
```

- [ ] **Step 4: Remove isSetPanel check from selectLeft**

```cpp
// OLD (line 714):
			if (isSetPanel(p) || isCatPanel(p)) {

// NEW:
			if (isCatPanel(p)) {
```

- [ ] **Step 5: Remove isSetPanel from the close/delete logic in handleMouse and drawPanels**

Search for any remaining `isSetPanel` references and remove them.

```cpp
// OLD (line 451, in handleMouse main panel category click):
					for (s32 ei = (s32)m_panels.size() - 1; ei >= 0; ei--) {
						if (isCatPanel(m_panels[ei]) || isSetPanel(m_panels[ei]))
							m_panels.erase(m_panels.begin() + ei);
					}

// NEW:
					for (s32 ei = (s32)m_panels.size() - 1; ei >= 0; ei--) {
						if (isCatPanel(m_panels[ei]))
							m_panels.erase(m_panels.begin() + ei);
					}
```

```cpp
// OLD (line 688, in selectRight main panel right-arrow):
			for (s32 ei = (s32)m_panels.size() - 1; ei >= 0; ei--)
				if (isCatPanel(m_panels[ei]) || isSetPanel(m_panels[ei]))
					m_panels.erase(m_panels.begin() + ei);

// NEW:
			for (s32 ei = (s32)m_panels.size() - 1; ei >= 0; ei--)
				if (isCatPanel(m_panels[ei]))
					m_panels.erase(m_panels.begin() + ei);
```

- [ ] **Step 6: Build and verify it compiles**

```bash
cmake --build build -j3 2>&1 | head -40
```

Expected: clean compile, no errors

---

### Task 6: Add test for show_cheat_settings_form

**Files:**
- Modify: `clientmods/al_test/test_cheats.lua`
- Test: run with `./util/ci/run_al_tests.sh`

- [ ] **Step 1: Add test verifying show_cheat_settings_form can be called**

```lua
-- In test_cheats.lua, after existing tests:

	T.run("show_cheat_settings_form works for scaffold settings", function()
		-- Should not crash
		core.show_cheat_settings_form("scaffold")
		T.assert(true, "show_cheat_settings_form completed without error")
	end)

	T.run("show_cheat_settings_form handles unknown setting gracefully", function()
		-- Should not crash for nonexistent setting
		core.show_cheat_settings_form("nonexistent_setting_xyz")
		T.assert(true, "show_cheat_settings_form on unknown setting completed without error")
	end)
```

- [ ] **Step 2: Run integration tests**

```bash
./util/ci/run_al_tests.sh
```

Expected: all tests pass

---

### Task 7: Final verification

**Files:**
- Run: build + tests

- [ ] **Step 1: Clean rebuild**

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DRUN_IN_PLACE=TRUE -DBUILD_SERVER=OFF
cmake --build build -j3
```

Expected: clean compile

- [ ] **Step 2: Run tests**

```bash
./util/ci/run_al_tests.sh
```

Expected: all tests pass, no regressions
