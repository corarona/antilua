/*
Antilua
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
#include "porting.h"
#include "cheatMenu.h"
#include "settings.h"
#include "util/string.h"
#include <algorithm>
#include <set>

CheatMenu *g_cheat_menu = nullptr;
bool g_cheat_layer_active = false;
bool g_show_minimal_debug = false;

static bool isCatPanel(const OverlayPanel &p) { return p.id.find("_cat_") == 0; }

static video::SColor parseHexColor(const std::string &hex, u32 alpha = 255)
{
	if (hex.empty())
		return video::SColor(alpha, 0, 0, 0);
	size_t pos = (hex[0] == '#') ? 1 : 0;
	if (hex.size() - pos < 6)
		return video::SColor(alpha, 0, 0, 0);
	u32 val = std::stoul(hex.substr(pos, 6), nullptr, 16);
	return video::SColor(alpha, (val >> 16) & 0xFF, (val >> 8) & 0xFF, val & 0xFF);
}

CheatMenu::CheatMenu(Client *client) : PanelOverlay(), m_client(client)
{
	FontMode fontMode = fontStringToEnum(g_settings->get("cheat_menu_font"));

	m_bg_color = parseHexColor(g_settings->get("theme_bg"), g_settings->getU32("theme_bg_alpha"));
	m_active_bg_color = parseHexColor(g_settings->get("theme_active_bg"), 210);
	m_font_color = parseHexColor(g_settings->get("theme_text"), g_settings->getU32("theme_text_alpha"));
	m_selected_font_color = parseHexColor(g_settings->get("theme_selected_text"));
	m_panel_bg = parseHexColor(g_settings->get("theme_panel_bg"), 230);
	m_title_bg = parseHexColor(g_settings->get("theme_title_bg"), 230);
	m_border_color = parseHexColor(g_settings->get("theme_border"), 230);
	m_item_bg = parseHexColor(g_settings->get("theme_item_bg"), 200);

	m_head_height = g_settings->getU32("cheat_menu_head_height");
	m_entry_height = g_settings->getU32("cheat_menu_entry_height");
	m_entry_width = g_settings->getU32("cheat_menu_entry_width");

	m_font = g_fontengine->getFont(FONT_SIZE_UNSPECIFIED, fontMode);
	if (m_font) {
		core::dimension2d<u32> dim = m_font->getDimension(L"M");
		m_fontsize = v2u32(dim.Width, dim.Height);
		m_font->grab();
	}
	m_fontsize.X = MYMAX(m_fontsize.X, 1);
	m_fontsize.Y = MYMAX(m_fontsize.Y, 1);
}

void CheatMenu::createCategoryPanels()
{
	CHEAT_MENU_GET_SCRIPTPTR
	m_panels.clear();
	for (size_t i = 0; i < script->m_cheat_categories.size(); i++) {
		OverlayPanel cp;
		cp.id = "_cat_" + std::to_string(i);
		cp.title = script->m_cheat_categories[i]->m_name;
		cp.selected_category = (int)i;
		cp.w = m_entry_width > 0 ? m_entry_width : 220;
		m_panels.push_back(cp);
	}
}

s32 CheatMenu::getPanelContentHeight(const OverlayPanel &panel)
{
	if (!isCatPanel(panel))
		return 0;
	ClientScripting *script = m_client->getScript();
	if (!script || !script->m_cheats_loaded)
		return 0;
	if (panel.selected_category >= 0 && (size_t)panel.selected_category < script->m_cheat_categories.size())
		return (s32)script->m_cheat_categories[panel.selected_category]->m_cheats.size() * (m_entry_height + m_gap);
	return 0;
}

void CheatMenu::drawPanelContent(video::IVideoDriver *driver,
	OverlayPanel &panel, s32 content_x, s32 content_y,
	s32 content_w, s32 content_h, v2s32 mouse_pos)
{
	if (!isCatPanel(panel))
		return;
	CHEAT_MENU_GET_SCRIPTPTR

	int chi = 0;
	if (panel.selected_category >= 0 && (size_t)panel.selected_category < script->m_cheat_categories.size()) {
		s32 iy = content_y;
		for (auto &cheat : script->m_cheat_categories[panel.selected_category]->m_cheats) {
			if (pointInRect(mouse_pos.X, mouse_pos.Y, content_x, iy, content_w, m_entry_height))
				panel.selected_cheat = chi;

			bool enabled = cheat->is_enabled();
			bool has_set = false;
			std::string tooltip_desc;
			lua_State *L = m_client->getScript()->getLuaState();
			lua_getglobal(L, "core");
			lua_getfield(L, -1, "cheat_defs");
			lua_getfield(L, -1, cheat->m_setting.c_str());
			if (lua_istable(L, -1)) {
				lua_getfield(L, -1, "cheat_settings");
				has_set = lua_istable(L, -1) || lua_isfunction(L, -1);
				lua_pop(L, 1);
				lua_getfield(L, -1, "description");
				if (lua_isstring(L, -1)) tooltip_desc = lua_tostring(L, -1);
				lua_pop(L, 1);
			}
			lua_pop(L, 3);

			if (pointInRect(mouse_pos.X, mouse_pos.Y, content_x, iy, content_w, m_entry_height) && !tooltip_desc.empty()) {
				m_tooltip_text = tooltip_desc;
				m_tooltip_x = mouse_pos.X;
				m_tooltip_y = mouse_pos.Y;
				if (m_hover_start == 0) m_hover_start = porting::getTimeMs();
			}

			video::SColor cbg = enabled ? m_active_bg_color : m_item_bg;
			driver->draw2DRectangle(cbg, core::rect<s32>(content_x + 1, iy, content_x + content_w - 1, iy + m_entry_height));

			std::string txt = enabled ? "[x] " : "[ ] ";
			txt += cheat->m_name;
			drawText(txt, content_x + 5, iy + (m_entry_height - m_fontsize.Y) / 2,
				(chi == panel.selected_cheat) ? m_selected_font_color : m_font_color);

			if (has_set) {
				s32 sbx = content_x + content_w - 18;
				bool hov = pointInRect(mouse_pos.X, mouse_pos.Y, sbx, iy, 16, m_entry_height);
				video::SColor sbtn = hov ? m_active_bg_color : m_item_bg;
				driver->draw2DRectangle(sbtn, core::rect<s32>(sbx, iy, sbx + 16, iy + m_entry_height));
				drawText("\u2699", sbx + 3, iy + (m_entry_height - m_fontsize.Y) / 2,
					m_selected_font_color);
			}

			iy += m_entry_height + m_gap;
			chi++;
		}
	}

	if (m_hover_start > 0.0) {
		bool hovering = false;
		for (auto &p : m_panels) {
			if (!isCatPanel(p)) continue;
			if (p.selected_category < 0 || (size_t)p.selected_category >= script->m_cheat_categories.size())
				continue;
			s32 iy2 = p.y + p.title_h + m_gap;
			for ([[maybe_unused]] auto &ch : script->m_cheat_categories[p.selected_category]->m_cheats) {
				if (pointInRect(mouse_pos.X, mouse_pos.Y, p.x, iy2, p.w, m_entry_height)) {
					hovering = true; break;
				}
				iy2 += m_entry_height + m_gap;
			}
			if (hovering) break;
		}
		if (!hovering) {
			m_hover_start = 0;
			m_tooltip_text.clear();
		}
	}

	if (m_hover_start > 0 && !m_tooltip_text.empty()) {
		u64 elapsed = porting::getTimeMs() - m_hover_start;
		if (elapsed > 500) {
			s32 tw = 280;
			auto lines = m_tooltip_text;
			std::string wrapped;
			while (lines.size() > 40) {
				size_t brk = lines.find_last_of(' ', 40);
				if (brk == std::string::npos) brk = 40;
				wrapped += lines.substr(0, brk) + "\n";
				lines = lines.substr(brk + 1);
			}
			wrapped += lines;

			s32 tx = m_tooltip_x + 12;
			s32 ty = m_tooltip_y - 10;
			s32 th = 10 + (s32)std::count(wrapped.begin(), wrapped.end(), '\n') * (m_fontsize.Y + 2) + 10;
			if (tx + tw > (s32)driver->getScreenSize().Width) tx = m_tooltip_x - tw - 10;
			if (ty + th > (s32)driver->getScreenSize().Height) ty = m_tooltip_y - th - 10;
			if (ty < 0) ty = m_tooltip_y + 10;

			driver->draw2DRectangle(m_panel_bg,
				core::rect<s32>(tx, ty, tx + tw, ty + th));
			drawText(wrapped, tx + 8, ty + 8, m_font_color);
		}
	}
}

void CheatMenu::handlePanelContentClick(size_t panel_idx, v2s32 pos, s32 cx, s32 cy, s32 cw)
{
	if (panel_idx >= m_panels.size())
		return;
	auto &panel = m_panels[panel_idx];
	if (!isCatPanel(panel))
		return;
	CHEAT_MENU_GET_SCRIPTPTR

	s32 iy = cy;
	int chi = 0;
	if (panel.selected_category >= 0 && (size_t)panel.selected_category < script->m_cheat_categories.size()) {
		for (auto &cheat : script->m_cheat_categories[panel.selected_category]->m_cheats) {
			if (pointInRect(pos.X, pos.Y, panel.x, iy, panel.w, m_entry_height)) {
				s32 sbx = panel.x + panel.w - 18;
				if (pointInRect(pos.X, pos.Y, sbx, iy, 16, m_entry_height)) {
					script->show_cheat_settings(cheat->m_setting);
				} else {
					panel.selected_cheat = chi;
					script->toggle_cheat(cheat);
				}
				return;
			}
			iy += m_entry_height + m_gap;
			chi++;
		}
	}
}

void CheatMenu::onLayerClosed()
{
	m_drag_panel = -1;
	m_categories_initialized = false;
	savePanelPositions();

	// Purge stale saved positions for category panels that no longer exist
	{
		std::set<std::string> valid_ids;
		for (auto &panel : m_panels) {
			if (isCatPanel(panel))
				valid_ids.insert(panel.id);
		}
		auto names = g_settings->getNames();
		for (const auto &name : names) {
			if (name.compare(0, 10, "panel_pos_") == 0) {
				std::string id = name.substr(10);
				if (id.compare(0, 5, "_cat_") == 0 && !valid_ids.count(id))
					g_settings->remove(name);
			}
		}
	}

	for (s32 i = (s32)m_panels.size() - 1; i >= 0; i--)
		if (isCatPanel(m_panels[i]) && !m_panels[i].pinned)
			m_panels.erase(m_panels.begin() + i);
}

void CheatMenu::drawHUD(video::IVideoDriver *driver, double dtime)
{
	CHEAT_MENU_GET_SCRIPTPTR
	float speed = g_settings->getFloat("cheat_hud.speed", 0.0f, 10.0f);
	if (speed <= 0) speed = 1.0f;
	m_rainbow_offset += dtime * speed;
	m_rainbow_offset = fmod(m_rainbow_offset, 6.0f);

	std::vector<std::string> enabled;
	for (auto &cat : script->m_cheat_categories)
		for (auto &cheat : cat->m_cheats)
			if (cheat->is_enabled())
				enabled.push_back(cheat->m_name);

	if (enabled.empty()) return;

	auto ss = driver->getScreenSize();
	u32 y = 5;
	int i = 0;
	for (auto &name : enabled) {
		f32 h = (f32)i * 2.0f / (f32)enabled.size() - m_rainbow_offset;
		if (h < 0) h = 6.0f + h;
		f32 xv = (1 - fabs(fmod(h, 2.0f) - 1.0f)) * 255.0f;
		video::SColor col;
		switch ((int)h) {
			case 0: col = video::SColor(255, 255, xv, 0); break;
			case 1: col = video::SColor(255, xv, 255, 0); break;
			case 2: col = video::SColor(255, 0, 255, xv); break;
			case 3: col = video::SColor(255, 0, xv, 255); break;
			case 4: col = video::SColor(255, xv, 0, 255); break;
			case 5: col = video::SColor(255, 255, 0, xv); break;
			default: col = video::SColor(255, 255, 255, 255);
		}
		auto dim = m_font->getDimension(utf8_to_wide(name).c_str());
		u32 xx = ss.Width - 5 - dim.Width;
		core::rect<s32> fb(xx, y, xx + dim.Width, y + dim.Height);
		m_font->draw(name.c_str(), fb, col, false, false);
		y += dim.Height;
		i++;
	}
}

void CheatMenu::selectUp()
{
	CHEAT_MENU_GET_SCRIPTPTR
	OverlayPanel *panel = nullptr;
	for (auto &p : m_panels) if (p.keyboard_focus) { panel = &p; break; }
	if (!panel && !m_panels.empty()) panel = &m_panels[0];
	if (!panel) return;

	if (isCatPanel(*panel)) {
		int max = (int)script->m_cheat_categories[panel->selected_category]->m_cheats.size() - 1;
		panel->selected_cheat--;
		if (panel->selected_cheat < 0) panel->selected_cheat = max;
	}
}

void CheatMenu::selectDown()
{
	CHEAT_MENU_GET_SCRIPTPTR
	OverlayPanel *panel = nullptr;
	for (auto &p : m_panels) if (p.keyboard_focus) { panel = &p; break; }
	if (!panel && !m_panels.empty()) panel = &m_panels[0];
	if (!panel) return;

	if (isCatPanel(*panel)) {
		int max = (int)script->m_cheat_categories[panel->selected_category]->m_cheats.size() - 1;
		panel->selected_cheat++;
		if (panel->selected_cheat > max) panel->selected_cheat = 0;
	}
}

void CheatMenu::selectRight()
{
	if (m_panels.empty()) return;
	int focused = -1;
	for (size_t i = 0; i < m_panels.size(); i++) {
		if (m_panels[i].keyboard_focus) { focused = (int)i; break; }
	}
	if (focused >= 0) m_panels[focused].keyboard_focus = false;
	int next = (focused + 1) % (int)m_panels.size();
	m_panels[next].keyboard_focus = true;
}

void CheatMenu::selectLeft()
{
	if (m_panels.empty()) return;
	int focused = -1;
	for (size_t i = 0; i < m_panels.size(); i++) {
		if (m_panels[i].keyboard_focus) { focused = (int)i; break; }
	}
	if (focused >= 0) m_panels[focused].keyboard_focus = false;
	int prev = (focused - 1 + (int)m_panels.size()) % (int)m_panels.size();
	m_panels[prev].keyboard_focus = true;
}

void CheatMenu::selectConfirm()
{
	CHEAT_MENU_GET_SCRIPTPTR
	OverlayPanel *panel = nullptr;
	for (auto &p : m_panels) if (p.keyboard_focus) { panel = &p; break; }
	if (!panel && !m_panels.empty()) panel = &m_panels[0];
	if (!panel) return;

	if (isCatPanel(*panel)) {
		if (panel->selected_category >= 0 && (size_t)panel->selected_category < script->m_cheat_categories.size()) {
			auto &cat = script->m_cheat_categories[panel->selected_category];
			if (panel->selected_cheat >= 0 && (size_t)panel->selected_cheat < cat->m_cheats.size()) {
				auto *cheat = cat->m_cheats[panel->selected_cheat];
				script->toggle_cheat(cheat);
			}
		}
	}
}
