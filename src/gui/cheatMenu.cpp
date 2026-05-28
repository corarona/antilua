/*
Dragonfire
Copyright (C) 2020 Elias Fleckenstein <eliasfleckenstein@web.de>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

#include "script/scripting_client.h"
#include "client/client.h"
#include "client/fontengine.h"
#include "cheatMenu.h"
#include "settings.h"
#include <cstddef>
#include <algorithm>

FontMode CheatMenu::fontStringToEnum(std::string str)
{
	if (str == "FM_Standard")
		return FM_Standard;
	else if (str == "FM_Mono")
		return FM_Mono;
	else if (str == "FM_Fallback")
		return _FM_Fallback;
	else if (str == "FM_MaxMode")
		return FM_MaxMode;
	else if (str == "FM_Unspecified")
		return FM_Unspecified;
	else
		return FM_Standard;
}

CheatMenu::CheatMenu(Client *client) : m_client(client)
{
	FontMode fontMode = fontStringToEnum(g_settings->get("cheat_menu_font"));

	auto bg_color = g_settings->getV3F("cheat_menu_bg_color").value_or(v3f());
	auto active_bg_color = g_settings->getV3F("cheat_menu_active_bg_color").value_or(v3f());
	auto font_color = g_settings->getV3F("cheat_menu_font_color").value_or(v3f());
	auto selected_font_color = g_settings->getV3F("cheat_menu_selected_font_color").value_or(v3f());

	m_bg_color = video::SColor(g_settings->getU32("cheat_menu_bg_color_alpha"),
			bg_color.X, bg_color.Y, bg_color.Z);

	m_active_bg_color = video::SColor(
			g_settings->getU32("cheat_menu_active_bg_color_alpha"),
			active_bg_color.X, active_bg_color.Y, active_bg_color.Z);

	m_font_color = video::SColor(g_settings->getU32("cheat_menu_font_color_alpha"),
			font_color.X, font_color.Y, font_color.Z);

	m_selected_font_color = video::SColor(
			g_settings->getU32("cheat_menu_selected_font_color_alpha"),
			selected_font_color.X, selected_font_color.Y,
			selected_font_color.Z);

	m_head_height = g_settings->getU32("cheat_menu_head_height");
	m_entry_height = g_settings->getU32("cheat_menu_entry_height");
	m_entry_width = g_settings->getU32("cheat_menu_entry_width");

	m_font = g_fontengine->getFont(FONT_SIZE_UNSPECIFIED, fontMode);

	if (!m_font) {
		errorstream << "CheatMenu: Unable to load font" << std::endl;
	} else {
		core::dimension2d<u32> dim = m_font->getDimension(L"M");
		m_fontsize = v2u32(dim.Width, dim.Height);
		m_font->grab();
	}
	m_fontsize.X = MYMAX(m_fontsize.X, 1);
	m_fontsize.Y = MYMAX(m_fontsize.Y, 1);

	loadPanelPositions();
}

static bool point_in_rect(s32 px, s32 py, s32 x, s32 y, s32 w, s32 h)
{
	return px >= x && px < x + w && py >= y && py < y + h;
}

void CheatMenu::buildCategoryPanel(CheatPanel &panel)
{
	CHEAT_MENU_GET_SCRIPTPTR

	panel.settings.clear();
	panel.id = "_categories";
	panel.cheat_layer = m_cheat_layer;
}

void CheatMenu::buildSettingsPanel(CheatPanel &panel, ScriptApiCheatsCheat *cheat)
{
	panel.settings.clear();
	panel.id = "_settings_" + cheat->m_setting;

	if (cheat->m_setting.empty())
		return;

		lua_State *L = m_client->getScript()->getLuaState();
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
					if (lua_isstring(L, -1))
						w.type = lua_tostring(L, -1);
					lua_pop(L, 1);
					w.value = g_settings->get(w.full_setting);
					panel.settings.push_back(w);
				}
				lua_pop(L, 1);
			}
		}
		lua_pop(L, 1);
	}
	lua_pop(L, 3);
}

void CheatMenu::drawPanel(video::IVideoDriver *driver, CheatPanel &panel, v2s32 mouse_pos)
{
	CHEAT_MENU_GET_SCRIPTPTR

	core::dimension2d<u32> ss = driver->getScreenSize();
	int x = panel.x, y = panel.y;
	int w = panel.w;

	// Calculate panel height based on content
	int h = panel.title_h;
	if (panel.id == "_categories") {
		if (panel.cheat_layer)
			h = panel.title_h + (1 + (int)script->m_cheat_categories.size()) * (m_entry_height + m_gap);
		else
			h = panel.title_h + (1 + (int)script->m_cheat_categories.size()) * (m_entry_height + m_gap);
		if (panel.cheat_layer) {
			size_t cc = script->m_cheat_categories[panel.selected_category]->m_cheats.size();
			h += (int)cc * (m_entry_height + m_gap);
		}
	} else if (panel.id.find("_settings_") == 0) {
		h = panel.title_h + (int)panel.settings.size() * (m_entry_height + m_gap);
		// title, pin, focus, reset
	}
	panel.h = h;

	// Clamp to screen
	if (x + w > (s32)ss.Width) x = ss.Width - w;
	if (y + h > (s32)ss.Height) y = ss.Height - h;
	if (x < 0) x = 0;
	if (y < 0) y = 0;
	panel.x = x; panel.y = y;

	// Background
	driver->draw2DRectangle(video::SColor(220, 30, 30, 40),
		core::rect<s32>(x, y, x + w, y + h));

	// Title bar
	driver->draw2DRectangle(video::SColor(220, 50, 50, 70),
		core::rect<s32>(x, y, x + w, y + panel.title_h));

	// Title text
	std::string title = (panel.id == "_categories") ? "Cheat Menu" : panel.id;
	if (panel.id.find("_settings_") == 0)
		title = "Settings: " + panel.id.substr(9);
	core::rect<s32> tb(x + 5, y + (panel.title_h - m_fontsize.Y) / 2,
		x + 5 + m_fontsize.X * title.size(), y + (panel.title_h + m_fontsize.Y) / 2);
	m_font->draw(utf8_to_wide(title).c_str(), tb, m_font_color, false, false);

	// Pin button
	s32 pin_x = x + w - 40;
	panel.hover_pin = point_in_rect(mouse_pos.X, mouse_pos.Y, pin_x, y, 18, panel.title_h);
	driver->draw2DRectangle(panel.hover_pin ? video::SColor(200, 100, 100, 100) : video::SColor(180, 60, 60, 80),
		core::rect<s32>(pin_x, y, pin_x + 18, y + panel.title_h));
	m_font->draw(panel.pinned ? L"\uF0C2" : L"\uF08A",
		core::rect<s32>(pin_x + 2, y + 4, pin_x + 18, y + panel.title_h),
		panel.pinned ? video::SColor(255, 255, 200, 50) : m_font_color);

	// Keyboard focus button
	s32 focus_x = x + w - 20;
	panel.hover_focus = point_in_rect(mouse_pos.X, mouse_pos.Y, focus_x, y, 18, panel.title_h);
	driver->draw2DRectangle(panel.hover_focus ? video::SColor(200, 100, 100, 100) : video::SColor(180, 60, 60, 80),
		core::rect<s32>(focus_x, y, focus_x + 18, y + panel.title_h));
	m_font->draw(panel.keyboard_focus ? L"\u2328" : L"\u2327",
		core::rect<s32>(focus_x + 2, y + 4, focus_x + 18, y + panel.title_h),
		panel.keyboard_focus ? video::SColor(255, 100, 255, 100) : m_font_color);

	// Reset button
	s32 rst_x = x + w - 60;
	driver->draw2DRectangle(video::SColor(180, 60, 60, 80),
		core::rect<s32>(rst_x, y, rst_x + 18, y + panel.title_h));
	m_font->draw(L"\u21BA",
		core::rect<s32>(rst_x + 2, y + 4, rst_x + 18, y + panel.title_h), m_font_color);

	// Check what is hovered
	panel.hover_title = point_in_rect(mouse_pos.X, mouse_pos.Y, x, y, w, panel.title_h);
	panel.hover_item = -1;

	if (panel.id == "_categories") {
		int item_y = y + panel.title_h + m_gap;
		int ci = 0;
		for (auto &cat : script->m_cheat_categories) {
			bool sel = (ci == panel.selected_category);
			video::SColor bg = sel ? m_active_bg_color : m_bg_color;
			driver->draw2DRectangle(bg,
				core::rect<s32>(x, item_y, x + w, item_y + m_entry_height));
			if (point_in_rect(mouse_pos.X, mouse_pos.Y, x, item_y, w, m_entry_height))
				panel.hover_item = ci;
			core::rect<s32> fb(x + 5, item_y + (m_entry_height - m_fontsize.Y) / 2,
				x + 5 + m_fontsize.X * cat->m_name.size(), item_y + (m_entry_height + m_fontsize.Y) / 2);
			m_font->draw(utf8_to_wide(cat->m_name).c_str(), fb,
				sel ? m_selected_font_color : m_font_color, false, false);
			item_y += m_entry_height + m_gap;
			ci++;

			if (sel && panel.cheat_layer) {
				int chi = 0;
				for (auto &cheat : cat->m_cheats) {
					bool csel = (chi == panel.selected_cheat);
					video::SColor cbg = cheat->is_enabled() ? m_active_bg_color : video::SColor(180, 40, 40, 50);
					driver->draw2DRectangle(cbg,
						core::rect<s32>(x + 10, item_y, x + w, item_y + m_entry_height));
					if (point_in_rect(mouse_pos.X, mouse_pos.Y, x + 10, item_y, w - 10, m_entry_height))
						panel.hover_item = -(ci * 100 + chi + 1);
					std::string txt = cheat->m_name;
					if (!cheat->m_setting.empty())
						txt = (cheat->is_enabled() ? "[x] " : "[ ] ") + txt;
					core::rect<s32> fb2(x + 15, item_y + (m_entry_height - m_fontsize.Y) / 2,
						x + 15 + m_fontsize.X * txt.size(), item_y + (m_entry_height + m_fontsize.Y) / 2);
					m_font->draw(utf8_to_wide(txt).c_str(), fb2,
						csel ? m_selected_font_color : m_font_color, false, false);
					item_y += m_entry_height + m_gap;
					chi++;
				}
			}
		}
	} else if (panel.id.find("_settings_") == 0) {
		int item_y = y + panel.title_h + m_gap;
		for (size_t i = 0; i < panel.settings.size(); i++) {
			auto &s = panel.settings[i];
			driver->draw2DRectangle(m_bg_color,
				core::rect<s32>(x, item_y, x + w, item_y + m_entry_height));
			if (point_in_rect(mouse_pos.X, mouse_pos.Y, x, item_y, w, m_entry_height))
				panel.hover_item = (int)i;
			core::rect<s32> fb(x + 5, item_y + (m_entry_height - m_fontsize.Y) / 2,
				x + 5 + m_fontsize.X * s.key.size(), item_y + (m_entry_height + m_fontsize.Y) / 2);
			m_font->draw(utf8_to_wide(s.key).c_str(), fb, m_font_color, false, false);
			item_y += m_entry_height + m_gap;
		}
	}
}

void CheatMenu::drawPanels(video::IVideoDriver *driver, v2s32 mouse_pos, bool show_debug)
{
	CHEAT_MENU_GET_SCRIPTPTR

	// Ensure category panel exists
	if (m_panels.empty()) {
		CheatPanel cp;
		cp.x = 10; cp.y = 60;
		buildCategoryPanel(cp);
		m_panels.push_back(cp);
	}

	for (auto &panel : m_panels) {
		if (panel.id == "_categories" || panel.id.find("_settings_") == 0) {
			drawPanel(driver, panel, mouse_pos);
		}
	}
}

void CheatMenu::drawPinned(video::IVideoDriver *driver, v2s32 mouse_pos)
{
	for (auto &panel : m_panels) {
		if (panel.pinned && panel.id != "_categories" && panel.id.find("_settings_") == 0) {
			drawPanel(driver, panel, mouse_pos);
		}
	}
}

void CheatMenu::handleMouse(v2s32 pos, bool left_down)
{
	bool was_down = m_mouse_left_prev;
	bool clicked = !was_down && left_down;
	bool released = was_down && !left_down;
	m_mouse_left_prev = left_down;
	m_prev_mouse_x = pos.X;
	m_prev_mouse_y = pos.Y;

	// Dragging
	if (m_drag_panel >= 0 && (size_t)m_drag_panel < m_panels.size()) {
		if (released) {
			m_drag_panel = -1;
			savePanelPositions();
		} else if (left_down) {
			m_panels[m_drag_panel].x = pos.X - m_drag_off_x;
			m_panels[m_drag_panel].y = pos.Y - m_drag_off_y;
		}
		return;
	}

	if (!clicked)
		return;

	// Check clicks on panels
	for (size_t i = 0; i < m_panels.size(); i++) {
		auto &panel = m_panels[i];
		int x = panel.x, y = panel.y, w = panel.w, h = panel.h;

		if (!point_in_rect(pos.X, pos.Y, x, y, w, h))
			continue;

		// Title bar
		if (point_in_rect(pos.X, pos.Y, x, y, w, panel.title_h)) {
			// Pin button
			if (point_in_rect(pos.X, pos.Y, x + w - 40, y, 18, panel.title_h)) {
				panel.pinned = !panel.pinned;
				savePanelPositions();
				return;
			}
			// Focus button
			if (point_in_rect(pos.X, pos.Y, x + w - 20, y, 18, panel.title_h)) {
				for (auto &p : m_panels)
					p.keyboard_focus = false;
				panel.keyboard_focus = true;
				return;
			}
			// Reset button
			if (point_in_rect(pos.X, pos.Y, x + w - 60, y, 18, panel.title_h)) {
				panel.x = 10 + (int)i * 30;
				panel.y = 60 + (int)i * 30;
				savePanelPositions();
				return;
			}
			// Start drag
			m_drag_panel = (int)i;
			m_drag_off_x = pos.X - panel.x;
			m_drag_off_y = pos.Y - panel.y;
			return;
		}

		// Items area for category panel
		if (panel.id == "_categories") {
			CHEAT_MENU_GET_SCRIPTPTR
			int item_y = y + panel.title_h + m_gap;
			int ci = 0;
			for (auto &cat : script->m_cheat_categories) {
				if (point_in_rect(pos.X, pos.Y, x, item_y, w, m_entry_height)) {
					if (panel.cheat_layer && ci == panel.selected_category) {
						panel.cheat_layer = false;
					} else {
						panel.selected_category = ci;
						panel.cheat_layer = false;
					}
					return;
				}
				item_y += m_entry_height + m_gap;
				if (ci == panel.selected_category && panel.cheat_layer) {
					int chi = 0;
					for (auto &cheat : cat->m_cheats) {
						if (point_in_rect(pos.X, pos.Y, x + 10, item_y, w - 10, m_entry_height)) {
							if (panel.selected_cheat == chi) {
								// Toggle cheat
								ScriptApiCheatsCheat *c = script->m_cheat_categories[panel.selected_category]->m_cheats[chi];
								script->toggle_cheat(c);
							} else {
								panel.selected_cheat = chi;
							}
							return;
						}
						item_y += m_entry_height + m_gap;
						chi++;
					}
				}
				ci++;
			}
		}
	}
}

void CheatMenu::onLayerClosed()
{
	m_drag_panel = -1;
}

void CheatMenu::drawHUD(video::IVideoDriver *driver, double dtime)
{
	CHEAT_MENU_GET_SCRIPTPTR

	m_rainbow_offset += dtime;
	m_rainbow_offset = fmod(m_rainbow_offset, 6.0f);

	std::vector<std::string> enabled_cheats;
	int cheat_count = 0;

	for (auto category = script->m_cheat_categories.begin();
			category != script->m_cheat_categories.end(); category++) {
		for (auto cheat = (*category)->m_cheats.begin();
				cheat != (*category)->m_cheats.end(); cheat++) {
			if ((*cheat)->is_enabled()) {
				enabled_cheats.push_back((*cheat)->m_name);
				cheat_count++;
			}
		}
	}

	if (enabled_cheats.empty())
		return;

	std::vector<video::SColor> colors;

	for (int i = 0; i < cheat_count; i++) {
		video::SColor color = video::SColor(255, 0, 0, 0);
		f32 h = (f32)i * 2.0f / (f32)cheat_count - m_rainbow_offset;
		if (h < 0)
			h = 6.0f + h;
		f32 x = (1 - fabs(fmod(h, 2.0f) - 1.0f)) * 255.0f;
		switch ((int)h) {
		case 0:
			color = video::SColor(255, 255, x, 0);
			break;
		case 1:
			color = video::SColor(255, x, 255, 0);
			break;
		case 2:
			color = video::SColor(255, 0, 255, x);
			break;
		case 3:
			color = video::SColor(255, 0, x, 255);
			break;
		case 4:
			color = video::SColor(255, x, 0, 255);
			break;
		case 5:
			color = video::SColor(255, 255, 0, x);
			break;
		}
		colors.push_back(color);
	}

	core::dimension2d<u32> screensize = driver->getScreenSize();
	u32 y = 5;

	int i = 0;
	for (std::string cheat : enabled_cheats) {
		core::dimension2d<u32> dim =
				m_font->getDimension(utf8_to_wide(cheat).c_str());
		u32 x = screensize.Width - 5 - dim.Width;

		core::rect<s32> fontbounds(x, y, x + dim.Width, y + dim.Height);
		m_font->draw(cheat.c_str(), fontbounds, colors[i], false, false);

		y += dim.Height;
		i++;
	}
}

void CheatMenu::selectUp()
{
	CHEAT_MENU_GET_SCRIPTPTR

	// Find the keyboard-focused panel
	CheatPanel *panel = nullptr;
	for (auto &p : m_panels) {
		if (p.keyboard_focus) { panel = &p; break; }
	}
	if (!panel && !m_panels.empty()) panel = &m_panels[0];
	if (!panel) return;

	int max = (panel->cheat_layer ? script->m_cheat_categories[panel->selected_category]
					->m_cheats.size()
			 : script->m_cheat_categories.size()) - 1;
	int *selected = panel->cheat_layer ? &panel->selected_cheat : &panel->selected_category;
	--*selected;
	if (*selected < 0)
		*selected = max;
}

void CheatMenu::selectDown()
{
	CHEAT_MENU_GET_SCRIPTPTR

	CheatPanel *panel = nullptr;
	for (auto &p : m_panels) {
		if (p.keyboard_focus) { panel = &p; break; }
	}
	if (!panel && !m_panels.empty()) panel = &m_panels[0];
	if (!panel) return;

	int max = (panel->cheat_layer ? script->m_cheat_categories[panel->selected_category]
					->m_cheats.size()
			 : script->m_cheat_categories.size()) - 1;
	int *selected = panel->cheat_layer ? &panel->selected_cheat : &panel->selected_category;
	++*selected;
	if (*selected > max)
		*selected = 0;
}

void CheatMenu::selectRight()
{
	CHEAT_MENU_GET_SCRIPTPTR

	CheatPanel *panel = nullptr;
	for (auto &p : m_panels) {
		if (p.keyboard_focus) { panel = &p; break; }
	}
	if (!panel && !m_panels.empty()) panel = &m_panels[0];
	if (!panel) return;

	if (panel->cheat_layer) {
		// Show settings panel for this cheat
		ScriptApiCheatsCheat *cheat = script->m_cheat_categories[panel->selected_category]
				->m_cheats[panel->selected_cheat];
		// Check if it has cheat_settings by looking at cheat_defs
	lua_State *L = m_client->getScript()->getLuaState();
		bool has_settings = false;
		lua_getglobal(L, "core");
		lua_getfield(L, -1, "cheat_defs");
		lua_getfield(L, -1, cheat->m_setting.c_str());
		if (lua_istable(L, -1)) {
			lua_getfield(L, -1, "cheat_settings");
			if (lua_istable(L, -1) || lua_isfunction(L, -1)) {
				has_settings = true;
			}
			lua_pop(L, 1);
		}
		lua_pop(L, 3);
		if (has_settings) {
			CheatPanel sp;
			sp.x = panel->x + panel->w + 10;
			sp.y = panel->y;
			sp.id = "_settings_" + cheat->m_setting;
			buildSettingsPanel(sp, cheat);
			m_panels.push_back(sp);
		}
		return;
	}
	panel->cheat_layer = true;
	panel->selected_cheat = 0;
}

void CheatMenu::selectLeft()
{
	for (auto &p : m_panels) {
		if (p.keyboard_focus) {
			if (p.id.find("_settings_") == 0) {
				// Close this settings panel
				m_panels.erase(std::remove_if(m_panels.begin(), m_panels.end(),
					[&](const CheatPanel &cp) { return cp.id == p.id; }), m_panels.end());
				return;
			}
			if (p.cheat_layer) {
				p.cheat_layer = false;
				return;
			}
		}
	}
}

void CheatMenu::selectConfirm()
{
	CHEAT_MENU_GET_SCRIPTPTR

	CheatPanel *panel = nullptr;
	for (auto &p : m_panels) {
		if (p.keyboard_focus) { panel = &p; break; }
	}
	if (!panel && !m_panels.empty()) panel = &m_panels[0];
	if (!panel) return;

	if (panel->cheat_layer) {
		if (panel->id == "_categories") {
			ScriptApiCheatsCheat *cheat = script->m_cheat_categories[panel->selected_category]
					->m_cheats[panel->selected_cheat];
			bool was = cheat->is_enabled();
			script->toggle_cheat(cheat);
			infostream << "CheatMenu: confirm on \"" << cheat->m_name
				<< "\" was=" << was << " now=" << cheat->is_enabled()
				<< std::endl;
		}
	} else
		selectRight();
}

void CheatMenu::savePanelPositions()
{
	for (auto &panel : m_panels) {
		std::string key = "cheat_panel_" + panel.id;
		std::string val = std::to_string(panel.x) + "," + std::to_string(panel.y);
		if (panel.pinned)
			val += ",pinned";
		g_settings->set(key, val);
	}
}

void CheatMenu::loadPanelPositions()
{
	// Panels are created on demand; positions are restored in buildCategoryPanel/settings
}
