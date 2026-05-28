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
#include <cstdlib>

static bool point_in_rect(s32 px, s32 py, s32 x, s32 y, s32 w, s32 h)
{
	return px >= x && px < x + w && py >= y && py < y + h;
}

FontMode CheatMenu::fontStringToEnum(std::string str)
{
	if (str == "FM_Standard") return FM_Standard;
	if (str == "FM_Mono") return FM_Mono;
	if (str == "FM_Fallback") return _FM_Fallback;
	if (str == "FM_MaxMode") return FM_MaxMode;
	if (str == "FM_Unspecified") return FM_Unspecified;
	return FM_Standard;
}

CheatMenu::CheatMenu(Client *client) : m_client(client)
{
	FontMode fontMode = fontStringToEnum(g_settings->get("cheat_menu_font"));

	auto bg = g_settings->getV3F("cheat_menu_bg_color").value_or(v3f());
	auto abg = g_settings->getV3F("cheat_menu_active_bg_color").value_or(v3f());
	auto fc = g_settings->getV3F("cheat_menu_font_color").value_or(v3f());
	auto sfc = g_settings->getV3F("cheat_menu_selected_font_color").value_or(v3f());
	auto pbg = g_settings->getV3F("cheat_menu_panel_bg").value_or(v3f(30, 30, 45));
	auto tbg = g_settings->getV3F("cheat_menu_title_bg").value_or(v3f(50, 50, 75));
	auto bdr = g_settings->getV3F("cheat_menu_border").value_or(v3f(70, 70, 100));
	auto ibg = g_settings->getV3F("cheat_menu_item_bg").value_or(v3f(55, 55, 75));

	m_bg_color = video::SColor(g_settings->getU32("cheat_menu_bg_color_alpha"), bg.X, bg.Y, bg.Z);
	m_active_bg_color = video::SColor(g_settings->getU32("cheat_menu_active_bg_color_alpha"), abg.X, abg.Y, abg.Z);
	m_font_color = video::SColor(g_settings->getU32("cheat_menu_font_color_alpha"), fc.X, fc.Y, fc.Z);
	m_selected_font_color = video::SColor(g_settings->getU32("cheat_menu_selected_font_color_alpha"), sfc.X, sfc.Y, sfc.Z);

	m_panel_bg = video::SColor(230, pbg.X, pbg.Y, pbg.Z);
	m_title_bg = video::SColor(230, tbg.X, tbg.Y, tbg.Z);
	m_border_color = video::SColor(230, bdr.X, bdr.Y, bdr.Z);
	m_item_bg = video::SColor(200, ibg.X, ibg.Y, ibg.Z);

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

static void drawRoundedRect(video::IVideoDriver *driver, s32 x, s32 y, s32 w, s32 h,
		video::SColor fill, video::SColor bg, s32 r = 4)
{
	// Body with corners cut
	s32 r2 = r * 2;
	driver->draw2DRectangle(fill, core::rect<s32>(x + r, y, x + w - r, y + h));
	driver->draw2DRectangle(fill, core::rect<s32>(x, y + r, x + r, y + h - r));
	driver->draw2DRectangle(fill, core::rect<s32>(x + w - r, y + r, x + w, y + h - r));
	// Corner masking
	for (s32 i = 0; i < r; i++) {
		for (s32 j = 0; j < r; j++) {
			if ((i + 1) * (i + 1) + (j + 1) * (j + 1) > r * r) {
				s32 px = 1, py = 1;
				// TL
				driver->draw2DRectangle(bg, core::rect<s32>(x + i, y + j, x + i + px, y + j + py));
				// TR
				driver->draw2DRectangle(bg, core::rect<s32>(x + w - i - px, y + j, x + w - i, y + j + py));
				// BL
				driver->draw2DRectangle(bg, core::rect<s32>(x + i, y + h - j - py, x + i + px, y + h - j));
				// BR
				driver->draw2DRectangle(bg, core::rect<s32>(x + w - i - px, y + h - j - py, x + w - i, y + h - j));
			}
		}
	}
}

static void drawRoundedBorder(video::IVideoDriver *driver, s32 x, s32 y, s32 w, s32 h,
		video::SColor color, s32 r = 4)
{
	// Top
	driver->draw2DRectangle(color, core::rect<s32>(x + r, y, x + w - r, y + 1));
	// Bottom
	driver->draw2DRectangle(color, core::rect<s32>(x + r, y + h - 1, x + w - r, y + h));
	// Left
	driver->draw2DRectangle(color, core::rect<s32>(x, y + r, x + 1, y + h - r));
	// Right
	driver->draw2DRectangle(color, core::rect<s32>(x + w - 1, y + r, x + w, y + h - r));
}

static void drawText(gui::IGUIFont *font, const std::string &text, s32 x, s32 y, const video::SColor &color)
{
	s32 fw = font->getDimension(utf8_to_wide(text).c_str()).Width;
	s32 fh = font->getDimension(L"M").Height;
	core::rect<s32> r(x, y, x + fw, y + fh);
	font->draw(utf8_to_wide(text).c_str(), r, color, false, false);
}

static bool isMainPanel(const CheatPanel &p) { return p.id == "_categories"; }
static bool isCatPanel(const CheatPanel &p) { return p.id.find("_cat_") == 0; }
static bool isSetPanel(const CheatPanel &p) { return p.id.find("_set_") == 0; }

void CheatMenu::drawPanel(video::IVideoDriver *driver, CheatPanel &panel, v2s32 mouse_pos)
{
	CHEAT_MENU_GET_SCRIPTPTR

	auto ss = driver->getScreenSize();
	s32 &x = panel.x, &y = panel.y;
	s32 w = panel.w;

	// Calculate height
	s32 h = panel.title_h;
	if (isMainPanel(panel)) {
		h += (s32)script->m_cheat_categories.size() * (m_entry_height + m_gap);
	} else if (isCatPanel(panel)) {
		h += (s32)script->m_cheat_categories[panel.selected_category]->m_cheats.size() * (m_entry_height + m_gap);
		if (panel.show_settings_for >= 0)
			h += (s32)panel.expanded_settings.size() * (m_entry_height + m_gap);
	} else if (isSetPanel(panel)) {
		h += (s32)panel.settings.size() * (m_entry_height + m_gap);
	}
	panel.h = h;

	// Clamp to screen
	if (x + w > (s32)ss.Width) x = ss.Width - w;
	if (y + h > (s32)ss.Height) y = ss.Height - h;
	if (x < 0) x = 0;
	if (y < 0) y = 0;

	// Panel background
	drawRoundedRect(driver, x, y, w, h, m_panel_bg, driver->getScreenSize().Width > 0 ? video::SColor(0, 0, 0, 0) : m_panel_bg);
	// Rounded border on top
	drawRoundedBorder(driver, x, y, w, h, m_border_color);
	// Title bar (stays within rounded top)
	driver->draw2DRectangle(m_title_bg, core::rect<s32>(x + 4, y + 1, x + w - 4, y + panel.title_h));

	// Title text
	std::string title;
	if (isMainPanel(panel)) title = "Cheat Menu";
	else if (isCatPanel(panel)) title = script->m_cheat_categories[panel.selected_category]->m_name;
	else if (isSetPanel(panel)) title = panel.id.substr(5) + " Settings";
	drawText(m_font, title, x + 5, y + (panel.title_h - m_fontsize.Y) / 2, m_font_color);

	// Close button (X) — only for non-main panels
	if (!isMainPanel(panel)) {
		s32 cx = x + w - 18;
		panel.hover_close = point_in_rect(mouse_pos.X, mouse_pos.Y, cx, y, 16, panel.title_h);
		driver->draw2DRectangle(panel.hover_close ? video::SColor(220, 180, 50, 50) : video::SColor(180, 80, 40, 40),
			core::rect<s32>(cx, y, cx + 16, y + panel.title_h));
		drawText(m_font, "\u2715", cx + 3, y + 4, video::SColor(255, 255, 255, 255));
	}

	// Pin button
	s32 pin_x = x + w - 56;
	panel.hover_pin = point_in_rect(mouse_pos.X, mouse_pos.Y, pin_x, y, 16, panel.title_h);
	driver->draw2DRectangle(panel.hover_pin ? video::SColor(200, 100, 100, 100) : video::SColor(180, 60, 60, 80),
		core::rect<s32>(pin_x, y, pin_x + 16, y + panel.title_h));
	drawText(m_font, panel.pinned ? "P" : "p", pin_x + 3, y + 4,
		panel.pinned ? video::SColor(255, 255, 200, 50) : m_font_color);

	// Focus button
	s32 fw = 16;
	s32 fx = pin_x - fw;
	panel.hover_focus = point_in_rect(mouse_pos.X, mouse_pos.Y, fx, y, fw, panel.title_h);
	driver->draw2DRectangle(panel.hover_focus ? video::SColor(200, 100, 100, 100) : video::SColor(180, 60, 60, 80),
		core::rect<s32>(fx, y, fx + fw, y + panel.title_h));
	drawText(m_font, panel.keyboard_focus ? "K" : "k", fx + 3, y + 4,
		panel.keyboard_focus ? video::SColor(255, 100, 255, 100) : m_font_color);

	// Reset position button
	s32 rsx = fx - 16;
	driver->draw2DRectangle(video::SColor(180, 60, 60, 80), core::rect<s32>(rsx, y, rsx + 16, y + panel.title_h));
	drawText(m_font, "R", rsx + 3, y + 4, m_font_color);

	panel.hover_title = point_in_rect(mouse_pos.X, mouse_pos.Y, x, y, w, panel.title_h);

	int iy = y + panel.title_h + m_gap;

	if (isMainPanel(panel)) {
		panel.hover_item = -1;
		int ci = 0;
		for (auto &cat : script->m_cheat_categories) {
			bool sel = (ci == panel.selected_category);
			video::SColor bg = sel ? m_active_bg_color : ((ci % 2 == 0) ? m_item_bg : m_bg_color);
			driver->draw2DRectangle(bg, core::rect<s32>(x + 1, iy, x + w - 1, iy + m_entry_height));
			if (point_in_rect(mouse_pos.X, mouse_pos.Y, x, iy, w, m_entry_height))
				panel.hover_item = ci;
			drawText(m_font, "> " + cat->m_name, x + 5, iy + (m_entry_height - m_fontsize.Y) / 2,
				sel ? m_selected_font_color : m_font_color);
			iy += m_entry_height + m_gap;
			ci++;
		}
	} else if (isCatPanel(panel)) {
		panel.hover_item = -1;
		panel.hover_setting = -1;
		int chi = 0;
		if (panel.selected_category >= 0 && (size_t)panel.selected_category < script->m_cheat_categories.size()) {
			for (auto &cheat : script->m_cheat_categories[panel.selected_category]->m_cheats) {
				bool enabled = cheat->is_enabled();
				bool has_set = false;
				lua_State *L = m_client->getScript()->getLuaState();
				lua_getglobal(L, "core");
				lua_getfield(L, -1, "cheat_defs");
				lua_getfield(L, -1, cheat->m_setting.c_str());
				if (lua_istable(L, -1)) {
					lua_getfield(L, -1, "cheat_settings");
					has_set = lua_istable(L, -1) || lua_isfunction(L, -1);
					lua_pop(L, 1);
				}
				lua_pop(L, 3);

				video::SColor cbg = enabled ? video::SColor(200, 40, 60, 40) : video::SColor(180, 50, 50, 55);
				driver->draw2DRectangle(cbg, core::rect<s32>(x + 1, iy, x + w - 1, iy + m_entry_height));
				if (point_in_rect(mouse_pos.X, mouse_pos.Y, x, iy, w, m_entry_height))
					panel.hover_item = chi;

				std::string txt = enabled ? "[x] " : "[ ] ";
				txt += cheat->m_name;

				drawText(m_font, txt, x + 5, iy + (m_entry_height - m_fontsize.Y) / 2,
					(chi == panel.selected_cheat) ? m_selected_font_color : m_font_color);

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

				iy += m_entry_height + m_gap;

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

				chi++;
			}
		}
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
				panel.hover_item = si; // first clickable element
				drawText(m_font, txt, x + 5, iy + (m_entry_height - m_fontsize.Y) / 2, m_font_color);
			} else {
				std::string val = g_settings->get(s.full_setting);
				drawText(m_font, s.key + ": " + val, x + 5, iy + (m_entry_height - m_fontsize.Y) / 2, m_font_color);
			}
			iy += m_entry_height + m_gap;
			si++;
		}
	}
}

void CheatMenu::drawPanels(video::IVideoDriver *driver, v2s32 mouse_pos, bool show_debug)
{
	CHEAT_MENU_GET_SCRIPTPTR

	// Ensure main menu panel exists
	if (m_panels.empty()) {
		CheatPanel cp;
		cp.id = "_categories";
		cp.x = 10; cp.y = 60;
		loadPanelPosition(cp);
		m_panels.push_back(cp);
	}

	for (auto &panel : m_panels)
		drawPanel(driver, panel, mouse_pos);
}

void CheatMenu::drawPinned(video::IVideoDriver *driver, v2s32 mouse_pos)
{
	for (auto &panel : m_panels) {
		if (panel.pinned)
			drawPanel(driver, panel, mouse_pos);
	}
}

void CheatMenu::handleMouse(v2s32 pos, bool left_down)
{
	bool was = m_mouse_left_prev;
	bool clicked = !was && left_down;
	bool released = was && !left_down;
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

	for (size_t pi = 0; pi < m_panels.size(); pi++) {
		auto &panel = m_panels[pi];
		s32 x = panel.x, y = panel.y, w = panel.w, h = panel.h;

		if (!point_in_rect(pos.X, pos.Y, x, y, w, h))
			continue;

		// Title bar clicks
		if (point_in_rect(pos.X, pos.Y, x, y, w, panel.title_h)) {
			// Close button (non-main panels)
			if (!isMainPanel(panel)) {
				s32 cx = x + w - 18;
				if (point_in_rect(pos.X, pos.Y, cx, y, 16, panel.title_h)) {
					g_settings->set("cheat_panel_" + panel.id, "");
					m_panels.erase(m_panels.begin() + (s32)pi);
					return;
				}
			}
			// Pin button
			s32 pin_x = x + w - 56;
			if (point_in_rect(pos.X, pos.Y, pin_x, y, 16, panel.title_h)) {
				panel.pinned = !panel.pinned;
				savePanelPositions();
				return;
			}
			// Focus button
			s32 fx = pin_x - 16;
			if (point_in_rect(pos.X, pos.Y, fx, y, 16, panel.title_h)) {
				for (auto &p : m_panels) p.keyboard_focus = false;
				panel.keyboard_focus = true;
				return;
			}
			// Reset button
			s32 rsx = fx - 16;
			if (point_in_rect(pos.X, pos.Y, rsx, y, 16, panel.title_h)) {
				panel.x = 10 + (s32)pi * 30;
				panel.y = 60 + (s32)pi * 30;
				savePanelPositions();
				return;
			}
			// Start drag — enter detached mode
			m_drag_panel = (s32)pi;
			m_drag_off_x = pos.X - panel.x;
			m_drag_off_y = pos.Y - panel.y;
			m_panel_detached = true;
			return;
		}

		// Item area
		int iy = y + panel.title_h + m_gap;

		if (isMainPanel(panel)) {
			CHEAT_MENU_GET_SCRIPTPTR
			int ci = 0;
			for (auto &cat : script->m_cheat_categories) {
				if (point_in_rect(pos.X, pos.Y, x, iy, w, m_entry_height)) {
					std::string cid = "_cat_" + std::to_string(ci);
					// Mouse click always replaces existing child panels (non-detached behavior)
					for (s32 ei = (s32)m_panels.size() - 1; ei >= 0; ei--) {
						if (isCatPanel(m_panels[ei]) || isSetPanel(m_panels[ei]))
							m_panels.erase(m_panels.begin() + ei);
					}
					CheatPanel cp;
					cp.id = cid;
					cp.selected_category = ci;
					cp.x = panel.x + panel.w + 10;
					cp.y = panel.y;
					loadPanelPosition(cp);
					m_panels.push_back(cp);
					return;
				}
				iy += m_entry_height + m_gap;
				ci++;
			}
		} else if (isCatPanel(panel)) {
			CHEAT_MENU_GET_SCRIPTPTR
			int chi = 0;
			if (panel.selected_category >= 0 && (size_t)panel.selected_category < script->m_cheat_categories.size()) {
				for (auto &cheat : script->m_cheat_categories[panel.selected_category]->m_cheats) {
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
					iy += m_entry_height + m_gap;
					chi++;
				}
			}
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
	}
}

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

void CheatMenu::onLayerClosed()
{
	m_drag_panel = -1;
}

void CheatMenu::drawHUD(video::IVideoDriver *driver, double dtime)
{
	CHEAT_MENU_GET_SCRIPTPTR
	m_rainbow_offset += dtime;
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
	// Find focused panel
	CheatPanel *panel = nullptr;
	for (auto &p : m_panels) if (p.keyboard_focus) { panel = &p; break; }
	if (!panel && !m_panels.empty()) panel = &m_panels[0];
	if (!panel) return;

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
}

void CheatMenu::selectDown()
{
	CHEAT_MENU_GET_SCRIPTPTR
	CheatPanel *panel = nullptr;
	for (auto &p : m_panels) if (p.keyboard_focus) { panel = &p; break; }
	if (!panel && !m_panels.empty()) panel = &m_panels[0];
	if (!panel) return;

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
}

void CheatMenu::selectRight()
{
	CHEAT_MENU_GET_SCRIPTPTR
	CheatPanel *panel = nullptr;
	for (auto &p : m_panels) if (p.keyboard_focus) { panel = &p; break; }
	if (!panel && !m_panels.empty()) panel = &m_panels[0];
	if (!panel) return;

	if (isMainPanel(*panel)) {
		// Open a child panel for the selected category
		std::string cid = "_cat_" + std::to_string(panel->selected_category);
		if (m_panel_detached) {
			for (auto &p : m_panels)
				if (p.id == cid) return;
		} else {
			for (s32 ei = (s32)m_panels.size() - 1; ei >= 0; ei--)
				if (isCatPanel(m_panels[ei]) || isSetPanel(m_panels[ei]))
					m_panels.erase(m_panels.begin() + ei);
		}
		CheatPanel cp;
		cp.id = cid;
		cp.selected_category = panel->selected_category;
		cp.x = panel->x + panel->w + 10;
		cp.y = panel->y;
		loadPanelPosition(cp);
		m_panels.push_back(cp);
	} else if (isCatPanel(*panel)) {
		if (panel->selected_cheat == panel->show_settings_for) {
			panel->show_settings_for = -1;
			panel->expanded_settings.clear();
		} else {
			panel->show_settings_for = panel->selected_cheat;
			panel->expanded_settings.clear();
		}
	}
}

void CheatMenu::selectLeft()
{
	for (size_t i = 0; i < m_panels.size(); i++) {
		auto &p = m_panels[i];
		if (p.keyboard_focus || (i == 0 && m_panels.size() > 1)) {
			if (isSetPanel(p) || isCatPanel(p)) {
				m_panels.erase(m_panels.begin() + (s32)i);
				return;
			}
		}
	}
}

void CheatMenu::selectConfirm()
{
	CHEAT_MENU_GET_SCRIPTPTR
	CheatPanel *panel = nullptr;
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

void CheatMenu::loadPanelPosition(CheatPanel &panel)
{
	std::string key = "cheat_panel_" + panel.id;
	std::string val;
	if (!g_settings->getNoEx(key, val) || val.empty())
		return;
	auto comma = val.find(',');
	if (comma == std::string::npos) return;
	panel.x = atoi(val.substr(0, comma).c_str());
	auto comma2 = val.find(',', comma + 1);
	if (comma2 == std::string::npos) {
		panel.y = atoi(val.substr(comma + 1).c_str());
	} else {
		panel.y = atoi(val.substr(comma + 1, comma2 - comma - 1).c_str());
		if (val.substr(comma2 + 1) == "pinned")
			panel.pinned = true;
	}
}

void CheatMenu::savePanelPositions()
{
	for (auto &panel : m_panels) {
		std::string key = "cheat_panel_" + panel.id;
		std::string val = std::to_string(panel.x) + "," + std::to_string(panel.y);
		if (panel.pinned) val += ",pinned";
		g_settings->set(key, val);
	}
}
