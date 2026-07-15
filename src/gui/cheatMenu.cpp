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
#include "client/renderingengine.h"
#include "client/renderingengine.h"
#include "client/inputhandler.h"
#include <algorithm>
#include <cmath>
#include <set>
#include <sstream>

CheatMenu *g_cheat_menu = nullptr;
bool g_cheat_layer_active = false;
bool g_quick_palette_active = false;
bool g_show_minimal_debug = false;

static bool isCatPanel(const OverlayPanel &p) { return p.id.find("_cat_") == 0; }
static bool isFavPanel(const OverlayPanel &p) { return p.id == "_fav_0"; }
static bool isSuperPanel(const OverlayPanel &p) { return p.id == "_super_0"; }
bool CheatMenu::isRecentPanel(const OverlayPanel &p) { return p.id == "_recent_0"; }

static std::set<std::string> getFavoritesSet()
{
	std::set<std::string> result;
	std::string val;
	if (g_settings->getNoEx("cheat_menu_favorites", val) && !val.empty()) {
		std::istringstream ss(val);
		std::string item;
		while (std::getline(ss, item, ','))
			if (!item.empty())
				result.insert(item);
	}
	return result;
}

static bool matchesSearch(const std::string &name, const std::string &search)
{
	if (search.empty())
		return true;
	std::string n = name;
	std::string s = search;
	std::transform(n.begin(), n.end(), n.begin(), ::tolower);
	std::transform(s.begin(), s.end(), s.begin(), ::tolower);
	return n.find(s) != std::string::npos;
}

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
	m_active_bg_color = parseHexColor(g_settings->get("theme_active_bg"), g_settings->getU32("theme_active_bg_alpha"));
	m_font_color = parseHexColor(g_settings->get("theme_text"), g_settings->getU32("theme_text_alpha"));
	m_selected_font_color = parseHexColor(g_settings->get("theme_selected_text"));
	m_panel_bg = parseHexColor(g_settings->get("theme_panel_bg"), g_settings->getU32("theme_panel_bg_alpha"));
	m_title_bg = parseHexColor(g_settings->get("theme_title_bg"), g_settings->getU32("theme_title_bg_alpha"));
	m_border_color = parseHexColor(g_settings->get("theme_border"), g_settings->getU32("theme_border_alpha"));
	m_item_bg = parseHexColor(g_settings->get("theme_item_bg"), g_settings->getU32("theme_item_bg_alpha"));
	m_tooltip_bg = parseHexColor(g_settings->get("theme_tooltip_bg"), g_settings->getU32("theme_panel_bg_alpha"));

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

void CheatMenu::addRecentCheat(const std::string &setting)
{
	// Move to front if already present
	auto it = std::find(m_recent_cheats.begin(), m_recent_cheats.end(), setting);
	if (it != m_recent_cheats.end())
		m_recent_cheats.erase(it);
	m_recent_cheats.insert(m_recent_cheats.begin(), setting);
	if (m_recent_cheats.size() > MAX_RECENT)
		m_recent_cheats.resize(MAX_RECENT);
	saveRecentCheats();
}

void CheatMenu::createRecentPanel()
{
	if (m_recent_cheats.empty())
		return;
	OverlayPanel rp;
	rp.id = "_recent_0";
	rp.title = "Recent";
	rp.w = m_entry_width > 0 ? m_entry_width : 220;
	rp.title_h = m_head_height;
	m_panels.push_back(rp);
}

void CheatMenu::loadRecentCheats()
{
	m_recent_cheats.clear();
	std::string val;
	if (!g_settings->getNoEx("cheat_menu_recent", val) || val.empty())
		return;
	std::istringstream ss(val);
	std::string item;
	while (std::getline(ss, item, ','))
		if (!item.empty())
			m_recent_cheats.push_back(item);
}

void CheatMenu::saveRecentCheats()
{
	std::string val;
	for (size_t i = 0; i < m_recent_cheats.size(); i++) {
		if (i > 0) val += ",";
		val += m_recent_cheats[i];
	}
	g_settings->set("cheat_menu_recent", val);
}

bool CheatMenu::hasActiveConflict(ScriptApiCheatsCheat *cheat) const
{
	if (cheat->m_conflicts_with.empty())
		return false;
	for (auto &setting : cheat->m_conflicts_with) {
		try {
			if (g_settings->getBool(setting))
				return true;
		} catch (SettingNotFoundException &) {}
	}
	return false;
}

int CheatMenu::getSlotForSetting(const std::string &setting) const
{
	if (setting.empty())
		return 0;
	for (int i = 1; i <= 9; i++) {
		if (g_settings->get("cheat_slot_" + std::to_string(i)) == setting)
			return i;
	}
	return 0;
}

void CheatMenu::refreshProfileList()
{
	m_profile_names.clear();
	lua_State *L = m_client->getScript()->getLuaState();
	lua_getglobal(L, "core");
	lua_getfield(L, -1, "list_cheat_profiles");
	if (lua_pcall(L, 0, 1, 0) == 0 && lua_istable(L, -1)) {
		lua_pushnil(L);
		while (lua_next(L, -2)) {
			if (lua_isstring(L, -1))
				m_profile_names.emplace_back(lua_tostring(L, -1));
			lua_pop(L, 1);
		}
	}
	lua_pop(L, 2);
}

void CheatMenu::loadProfile(size_t idx)
{
	if (idx >= m_profile_names.size())
		return;
	lua_State *L = m_client->getScript()->getLuaState();
	lua_getglobal(L, "core");
	lua_getfield(L, -1, "load_cheat_profile");
	lua_pushstring(L, m_profile_names[idx].c_str());
	lua_pcall(L, 1, 0, 0);
	lua_pop(L, 1);
}

void CheatMenu::drawProfilesPopup(video::IVideoDriver *driver)
{
	if (!m_profiles_active)
		return;

	s32 entry_h = 30;
	s32 gap = 2;
	int num_items = (int)m_profile_names.size() + 2; // profiles + Save + Manage
	s32 pw = 200;
	s32 ph = num_items * entry_h + (num_items - 1) * gap + 6;

	s32 px = m_profiles_pos.X;
	s32 py = m_profiles_pos.Y;

	auto ss = driver->getScreenSize();
	if (px + pw > (s32)ss.Width) px = ss.Width - pw;
	if (py + ph > (s32)ss.Height) py = ss.Height - ph;

	drawRoundedRect(driver, px, py, pw, ph, m_panel_bg, m_bg_color);
	drawRoundedBorder(driver, px, py, pw, ph, m_border_color);

	s32 iy = py + 3;
	int idx = 0;
	for (auto &name : m_profile_names) {
		bool sel = (idx == m_profiles_selected);
		driver->draw2DRectangle(sel ? m_active_bg_color : m_panel_bg,
			core::rect<s32>(px + 1, iy, px + pw - 1, iy + entry_h));
		drawText(name, px + 6, iy + (entry_h - m_fontsize.Y) / 2,
			sel ? m_selected_font_color : m_font_color);
		iy += entry_h + gap;
		idx++;
	}

	// Save current
	bool sel_save = (idx == m_profiles_selected);
	driver->draw2DRectangle(sel_save ? m_active_bg_color : m_panel_bg,
		core::rect<s32>(px + 1, iy, px + pw - 1, iy + entry_h));
	drawText("Save current...", px + 6, iy + (entry_h - m_fontsize.Y) / 2,
		sel_save ? m_selected_font_color : m_font_color);
	iy += entry_h + gap;
	idx++;

	// Manage
	bool sel_mgmt = (idx == m_profiles_selected);
	driver->draw2DRectangle(sel_mgmt ? m_active_bg_color : m_panel_bg,
		core::rect<s32>(px + 1, iy, px + pw - 1, iy + entry_h));
	drawText("Manage...", px + 6, iy + (entry_h - m_fontsize.Y) / 2,
		sel_mgmt ? m_selected_font_color : m_font_color);
}

void CheatMenu::dismissContextMenu()
{
	m_ctx.active = false;
	m_ctx.cheat_setting.clear();
	m_ctx.ctx_panel_idx = -1;
}

void CheatMenu::drawContextMenu(video::IVideoDriver *driver)
{
	if (!m_ctx.active)
		return;

	s32 entry_h = 30;
	s32 gap = 2;

	if (m_ctx.ctx_panel_idx >= 0) {
		// Panel-level context menu
		m_ctx.w = 180;
		m_ctx.h = 2 * entry_h + gap + 6;
		auto ss = driver->getScreenSize();
		if (m_ctx.x + m_ctx.w > (s32)ss.Width) m_ctx.x = ss.Width - m_ctx.w;
		if (m_ctx.y + m_ctx.h > (s32)ss.Height) m_ctx.y = ss.Height - m_ctx.h;
		drawRoundedRect(driver, m_ctx.x, m_ctx.y, m_ctx.w, m_ctx.h, m_panel_bg, m_bg_color);
		drawRoundedBorder(driver, m_ctx.x, m_ctx.y, m_ctx.w, m_ctx.h, m_border_color);
		s32 iy = m_ctx.y + 3;
		auto di = [&](const std::string &t, int idx) {
			bool sel = (idx == m_ctx.selected);
			driver->draw2DRectangle(sel ? m_active_bg_color : m_panel_bg,
				core::rect<s32>(m_ctx.x + 1, iy, m_ctx.x + m_ctx.w - 1, iy + entry_h));
			drawText(t, m_ctx.x + 6, iy + (entry_h - m_fontsize.Y) / 2,
				sel ? m_selected_font_color : m_font_color);
			iy += entry_h + gap;
		};
		di("Enable all", 0);
		di("Disable all", 1);
		return;
	}

	// Cheat-level context menu
	enum { OPT_TOGGLE = 0, OPT_SETTINGS = 1, OPT_FAVORITE = 2, OPT_SLOT = 3 };
	int num = 1; // always toggle
	if (m_ctx.has_settings) num++;
	num++; // always favorite
	int cur_slot = getSlotForSetting(m_ctx.cheat_setting);
	if (cur_slot) num++; // unbind
	else num++; // bind

	m_ctx.w = 180;
	m_ctx.h = num * entry_h + (num - 1) * gap + 6;

	auto ss = driver->getScreenSize();
	if (m_ctx.x + m_ctx.w > (s32)ss.Width) m_ctx.x = ss.Width - m_ctx.w;
	if (m_ctx.y + m_ctx.h > (s32)ss.Height) m_ctx.y = ss.Height - m_ctx.h;

	drawRoundedRect(driver, m_ctx.x, m_ctx.y, m_ctx.w, m_ctx.h, m_panel_bg, m_bg_color);
	drawRoundedBorder(driver, m_ctx.x, m_ctx.y, m_ctx.w, m_ctx.h, m_border_color);

	s32 iy = m_ctx.y + 3;
	auto draw_item = [&](const std::string &text, int idx) {
		bool sel = (idx == m_ctx.selected);
		driver->draw2DRectangle(sel ? m_active_bg_color : m_panel_bg,
			core::rect<s32>(m_ctx.x + 1, iy, m_ctx.x + m_ctx.w - 1, iy + entry_h));
		drawText(text, m_ctx.x + 6, iy + (entry_h - m_fontsize.Y) / 2,
			sel ? m_selected_font_color : m_font_color);
		iy += entry_h + gap;
	};

	draw_item(m_ctx.is_enabled ? "Disable" : "Enable", OPT_TOGGLE);
	if (m_ctx.has_settings)
		draw_item("Settings", OPT_SETTINGS);
	draw_item(m_ctx.is_favorite ? "Unfavorite" : "Favorite", OPT_FAVORITE);
	if (!m_ctx.cheat_setting.empty()) {
		if (cur_slot)
			draw_item("Slot " + std::to_string(cur_slot), OPT_SLOT);
		else
			draw_item("Slot...", OPT_SLOT);
	}
}

bool CheatMenu::handleContextMenuItemClick(v2s32 pos)
{
	if (!m_ctx.active)
		return false;
	if (!pointInRect(pos.X, pos.Y, m_ctx.x, m_ctx.y, m_ctx.w, m_ctx.h))
		return false;

	s32 entry_h = 30;
	s32 gap = 2;
	s32 iy = m_ctx.y + 3;

	auto check_item = [&](const std::string &text, int opt) -> bool {
		if (pointInRect(pos.X, pos.Y, m_ctx.x + 1, iy, m_ctx.w - 2, entry_h)) {
			m_ctx.selected = opt;
			execContextMenu();
			return true;
		}
		iy += entry_h + gap;
		return false;
	};

	// Toggle (always first, opt 0)
	if (check_item(m_ctx.is_enabled ? "Disable" : "Enable", 0)) return true;

	// Settings (only if has_settings) -> opt 1
	if (m_ctx.has_settings && check_item("Settings", 1)) return true;

	// Favorite -> opt 2
	if (check_item(m_ctx.is_favorite ? "Unfavorite" : "Favorite", 2)) return true;

	// Slot -> opt 3 (only for setting-based cheats)
	if (!m_ctx.cheat_setting.empty() && check_item(m_ctx.cheat_setting.empty() ? "Slot..." : ("Slot " + std::to_string(getSlotForSetting(m_ctx.cheat_setting))), 3)) return true;

	dismissContextMenu();
	return false;
}

void CheatMenu::handleRightClick(v2s32 pos)
{
	if (!g_cheat_layer_active) {
		dismissContextMenu();
		return;
	}

	// Check if click is on the context menu itself
	if (m_ctx.active) {
		handleContextMenuItemClick(pos);
		return;
	}

	// Find which cheat was right-clicked
	for (size_t pi = 0; pi < m_panels.size(); pi++) {
		auto &panel = m_panels[pi];
		if (!pointInRect(pos.X, pos.Y, panel.x, panel.y, panel.w, panel.h))
			continue;

		// Check title bar FIRST (works even for collapsed panels)
		if (pointInRect(pos.X, pos.Y, panel.x, panel.y, panel.w, panel.title_h)) {
			if (isCatPanel(panel)) {
				// Category panel title: enable/disable all
				m_ctx.active = true;
				m_ctx.x = pos.X;
				m_ctx.y = pos.Y;
				m_ctx.selected = 0;
				m_ctx.ctx_panel_idx = (int)pi;
				m_ctx.cheat_setting.clear();
				return;
			}
			if (isSuperPanel(panel)) {
				dismissContextMenu();
				return;
			}
			return;
		}

		if (panel.collapsed)
			continue;
		if (!pointInRect(pos.X, pos.Y, panel.x, panel.y, panel.w, panel.h))
			continue;

		s32 cx = panel.x, cy = panel.y + panel.title_h + m_gap;
		s32 cw = panel.w;

		// Determine how many entries in this panel to iterate
		auto count_entries = [&]() -> std::vector<ScriptApiCheatsCheat *> {
			std::vector<ScriptApiCheatsCheat *> result;
			ClientScripting *script = m_client->getScript();
			if (!script || !script->m_cheats_loaded)
				return result;

			if (isRecentPanel(panel)) {
				for (auto &s : m_recent_cheats) {
					for (auto &cat : script->m_cheat_categories)
						for (auto *ch : cat->m_cheats)
							if (ch->m_setting == s)
								result.push_back(ch);
				}
			} else if (isCatPanel(panel) && panel.selected_category >= 0 &&
					(size_t)panel.selected_category < script->m_cheat_categories.size()) {
				for (auto *ch : script->m_cheat_categories[panel.selected_category]->m_cheats)
					if (matchesSearch(ch->m_name, m_search_text))
						result.push_back(ch);
			} else if (isFavPanel(panel)) {
				auto favs = getFavoritesSet();
				for (auto &cat : script->m_cheat_categories)
					for (auto *ch : cat->m_cheats)
						if (favs.count(ch->m_setting) && matchesSearch(ch->m_name, m_search_text))
							result.push_back(ch);
			}
			return result;
		};

		auto entries = count_entries();
		s32 iy = cy;
		for (size_t ei = 0; ei < entries.size(); ei++) {
			if (pointInRect(pos.X, pos.Y, cx, iy, cw, m_entry_height)) {
				auto *cheat = entries[ei];
				m_ctx.active = true;
				m_ctx.x = pos.X;
				m_ctx.y = pos.Y;
				m_ctx.selected = 0;
				m_ctx.cheat_setting = cheat->m_setting;
				m_ctx.is_enabled = cheat->is_enabled();

				lua_State *L = m_client->getScript()->getLuaState();
				lua_getglobal(L, "core");
				lua_getfield(L, -1, "cheat_defs");
				lua_getfield(L, -1, cheat->m_setting.c_str());
				if (lua_istable(L, -1)) {
					lua_getfield(L, -1, "cheat_settings");
					m_ctx.has_settings = lua_istable(L, -1) || lua_isfunction(L, -1);
					lua_pop(L, 1);
				} else {
					m_ctx.has_settings = false;
				}
				lua_pop(L, 3);

				m_ctx.is_favorite = isFavorite(cheat->m_setting);
				return;
			}
			iy += m_entry_height + m_gap;
		}
	}
}

void CheatMenu::execContextMenu()
{
	if (!m_ctx.active)
		return;

	// Panel-level: enable/disable all in a category
	if (m_ctx.ctx_panel_idx >= 0) {
		size_t pi = (size_t)m_ctx.ctx_panel_idx;
		if (pi < m_panels.size() && isCatPanel(m_panels[pi])) {
			int cat_idx = m_panels[pi].selected_category;
			ClientScripting *script = m_client->getScript();
			if (script && script->m_cheats_loaded && cat_idx >= 0 &&
					(size_t)cat_idx < script->m_cheat_categories.size()) {
				bool enable = (m_ctx.selected == 0);
				for (auto *ch : script->m_cheat_categories[cat_idx]->m_cheats) {
					if (ch->m_setting.empty())
						script->toggle_cheat(ch);
					else
						g_settings->setBool(ch->m_setting, enable);
				}
			}
		}
		dismissContextMenu();
		return;
	}

	ClientScripting *script = m_client->getScript();
	if (!script || !script->m_cheats_loaded)
		return;

	enum { OPT_TOGGLE = 0, OPT_SETTINGS = 1, OPT_FAVORITE = 2, OPT_SLOT = 3 };

	if (m_ctx.selected == OPT_TOGGLE) {
		for (auto &cat : script->m_cheat_categories)
			for (auto *ch : cat->m_cheats)
				if (ch->m_setting == m_ctx.cheat_setting) {
					script->toggle_cheat(ch);
					addRecentCheat(ch->m_setting);
					dismissContextMenu();
					return;
				}
	} else if (m_ctx.selected == OPT_SETTINGS && m_ctx.has_settings) {
		closeForFormspec();
		script->show_cheat_settings(m_ctx.cheat_setting);
	} else if (m_ctx.selected == OPT_FAVORITE) {
		toggleFavorite(m_ctx.cheat_setting);
	} else if (m_ctx.selected == OPT_SLOT && !m_ctx.cheat_setting.empty()) {
		closeForFormspec();
		lua_State *L = m_client->getScript()->getLuaState();
		lua_getglobal(L, "core");
		lua_getfield(L, -1, "show_slot_picker");
		if (lua_isfunction(L, -1)) {
			lua_pushstring(L, m_ctx.cheat_setting.c_str());
			lua_pcall(L, 1, 0, 0);
		}
		lua_pop(L, 2);
	}
	dismissContextMenu();
}

void CheatMenu::createCategoryPanels()
{
	CHEAT_MENU_GET_SCRIPTPTR
	m_panels.clear();
	loadRecentCheats();
	size_t n = script->m_cheat_categories.size();
	for (size_t i = 0; i < n; i++) {
		OverlayPanel cp;
		cp.id = "_cat_" + std::to_string(i);
		cp.title = script->m_cheat_categories[i]->m_name;
		cp.selected_category = (int)i;
		cp.w = m_entry_width > 0 ? m_entry_width : 220;
		cp.title_h = m_head_height;

		// Per-category header tint — same color family as m_title_bg
		if (n > 1) {
			float t = (float)i / (float)(n - 1);
			float hueDeg = (t - 0.5f) * 60.0f;
			float satDelta = (t - 0.5f) * 0.1f;
			cp.title_color = shiftHue(m_title_bg, hueDeg, satDelta);
			cp.title_color_set = true;
		}

		m_panels.push_back(cp);
	}

	// Create favorites panel if any favorites exist
	auto favs = getFavoritesSet();
	if (!favs.empty()) {
		OverlayPanel fp;
		fp.id = "_fav_0";
		fp.title = "Favorites";
		fp.w = m_entry_width > 0 ? m_entry_width : 220;
		fp.title_h = m_head_height;
		m_panels.push_back(fp);
		g_settings->remove("panel_pos__fav_0");
	}

	createRecentPanel();
	createSupermenuPanel();

	m_search_text.clear();
}

s32 CheatMenu::getPanelContentHeight(const OverlayPanel &panel)
{
	if (panel.collapsed)
		return 0;

	ClientScripting *script = m_client->getScript();
	if (!script || !script->m_cheats_loaded)
		return 0;

	s32 count = 0;
	if (isSuperPanel(panel)) {
		if (m_super_level == 0) {
			for (auto &cat : script->m_cheat_categories)
				if (matchesSearch(cat->m_name, m_search_text))
					count++;
		} else {
			count = 1; // back button
			if (m_super_selected_category >= 0 && (size_t)m_super_selected_category < script->m_cheat_categories.size())
				for (auto &cheat : script->m_cheat_categories[m_super_selected_category]->m_cheats)
					if (matchesSearch(cheat->m_name, m_search_text))
						count++;
		}
	} else if (isFavPanel(panel)) {
		for (auto &cat : script->m_cheat_categories)
			for (auto &cheat : cat->m_cheats)
				if (isFavorite(cheat->m_setting) && matchesSearch(cheat->m_name, m_search_text))
					count++;
	} else if (isRecentPanel(panel)) {
		for (auto &setting : m_recent_cheats)
			for (auto &cat : script->m_cheat_categories)
				for (auto &cheat : cat->m_cheats)
					if (cheat->m_setting == setting)
						{ count++; break; }
	} else if (isCatPanel(panel) && panel.selected_category >= 0 &&
			(size_t)panel.selected_category < script->m_cheat_categories.size()) {
		for (auto &cheat : script->m_cheat_categories[panel.selected_category]->m_cheats)
			if (matchesSearch(cheat->m_name, m_search_text))
				count++;
	}
	return count * (m_entry_height + m_gap);
}

void CheatMenu::drawPanelContent(video::IVideoDriver *driver,
	OverlayPanel &panel, s32 content_x, s32 content_y,
	s32 content_w, s32 content_h, v2s32 mouse_pos)
{
	if (!isCatPanel(panel) && !isFavPanel(panel) && !isSuperPanel(panel) && !isRecentPanel(panel))
		return;
	CHEAT_MENU_GET_SCRIPTPTR

	// Supermenu panel with two-level navigation
	if (isSuperPanel(panel)) {
		auto fill_bg = [&](s32 iy, bool selected) {
			video::SColor cbg = selected ? m_active_bg_color : m_item_bg;
			driver->draw2DRectangle(cbg,
				core::rect<s32>(content_x + 1, iy, content_x + content_w - 1, iy + m_entry_height));
		};

		s32 iy = content_y;
		int chi = 0;

		if (m_super_level == 0) {
			// Level 0: list categories
			for (size_t ci = 0; ci < script->m_cheat_categories.size(); ci++) {
				auto &cat = script->m_cheat_categories[ci];
				if (!matchesSearch(cat->m_name, m_search_text))
					continue;
				bool selected = (chi == panel.selected_cheat);
				if (pointInRect(mouse_pos.X, mouse_pos.Y, content_x, iy, content_w, m_entry_height))
					panel.selected_cheat = chi;
				fill_bg(iy, selected);
				drawText("> " + cat->m_name, content_x + 5,
					iy + (m_entry_height - m_fontsize.Y) / 2,
					selected ? m_selected_font_color : m_font_color);
				iy += m_entry_height + m_gap;
				chi++;
			}
		} else {
			// Level 1: back button + cheats in selected category
			// Back button
			bool back_sel = (panel.selected_cheat == 0);
			if (pointInRect(mouse_pos.X, mouse_pos.Y, content_x, iy, content_w, m_entry_height))
				panel.selected_cheat = 0;
			fill_bg(iy, back_sel);
			drawText("\u2190 Categories", content_x + 5,
				iy + (m_entry_height - m_fontsize.Y) / 2,
				back_sel ? m_selected_font_color : m_font_color);
			iy += m_entry_height + m_gap;
			chi = 1;

			// Cheats
			if (m_super_selected_category >= 0 && (size_t)m_super_selected_category < script->m_cheat_categories.size()) {
				for (auto &cheat : script->m_cheat_categories[m_super_selected_category]->m_cheats) {
					if (!matchesSearch(cheat->m_name, m_search_text))
						continue;
					bool selected = (chi == panel.selected_cheat);
					if (pointInRect(mouse_pos.X, mouse_pos.Y, content_x, iy, content_w, m_entry_height))
						panel.selected_cheat = chi;
					bool enabled = cheat->is_enabled();
					fill_bg(iy, selected);
					std::string txt = enabled ? "[x] " : "[ ] ";
					txt += cheat->m_name;
					drawText(txt, content_x + 5,
						iy + (m_entry_height - m_fontsize.Y) / 2,
						selected ? m_selected_font_color : m_font_color);
					iy += m_entry_height + m_gap;
					chi++;
				}
			}
		}
		return;
	}

	// Collect the cheats to draw based on panel type
	struct DrawEntry {
		ScriptApiCheatsCheat *cheat;
		int category_idx;
	};
	std::vector<DrawEntry> entries;

	auto favs = getFavoritesSet();

	if (isRecentPanel(panel)) {
		for (auto &setting : m_recent_cheats) {
			for (size_t ci = 0; ci < script->m_cheat_categories.size(); ci++) {
				for (auto &cheat : script->m_cheat_categories[ci]->m_cheats) {
					if (cheat->m_setting == setting) {
						entries.push_back({cheat, (int)ci});
						goto next_recent;
					}
				}
			}
			next_recent:;
		}
	} else if (isFavPanel(panel)) {
		for (size_t ci = 0; ci < script->m_cheat_categories.size(); ci++) {
			for (auto &cheat : script->m_cheat_categories[ci]->m_cheats) {
				if (favs.count(cheat->m_setting) && matchesSearch(cheat->m_name, m_search_text))
					entries.push_back({cheat, (int)ci});
			}
		}
	} else if (panel.selected_category >= 0 && (size_t)panel.selected_category < script->m_cheat_categories.size()) {
		for (auto &cheat : script->m_cheat_categories[panel.selected_category]->m_cheats)
			if (matchesSearch(cheat->m_name, m_search_text))
				entries.push_back({cheat, panel.selected_category});
	}

	int chi = 0;
	s32 iy = content_y;
	for (auto &de : entries) {
		auto *cheat = de.cheat;
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
		bool conflict = hasActiveConflict(cheat);
		if (conflict)
			txt += "\u26A0 ";
		txt += cheat->m_name;
		drawText(txt, content_x + 5, iy + (m_entry_height - m_fontsize.Y) / 2,
			(chi == panel.selected_cheat) ? m_selected_font_color : m_font_color);

		int slot = !cheat->m_setting.empty() ? getSlotForSetting(cheat->m_setting) : 0;
		if (slot) {
			std::string badge = " [" + std::to_string(slot) + "]";
			drawText(badge, content_x + 5 + m_font->getDimension(utf8_to_wide(txt).c_str()).Width + 2,
				iy + (m_entry_height - m_fontsize.Y) / 2,
				video::SColor(255, 255, 200, 0));
		}

		if (conflict && !tooltip_desc.empty())
			tooltip_desc += " \u26A0 Conflict with another active cheat";

		// Star icon (far right)
		s32 star_x = content_x + content_w - 18;
		bool star_hov = pointInRect(mouse_pos.X, mouse_pos.Y, star_x, iy, 16, m_entry_height);
		video::SColor sbtn = star_hov ? m_active_bg_color : m_item_bg;
		driver->draw2DRectangle(sbtn, core::rect<s32>(star_x, iy, star_x + 16, iy + m_entry_height));
		drawText(favs.count(cheat->m_setting) ? "\u2605" : "\u2606", star_x + 3,
			iy + (m_entry_height - m_fontsize.Y) / 2, m_selected_font_color);

		// Gear icon (left of star, if has settings)
		if (has_set) {
			s32 gear_x = content_x + content_w - 36;
			bool gear_hov = pointInRect(mouse_pos.X, mouse_pos.Y, gear_x, iy, 16, m_entry_height);
			video::SColor gbtn = gear_hov ? m_active_bg_color : m_item_bg;
			driver->draw2DRectangle(gbtn, core::rect<s32>(gear_x, iy, gear_x + 16, iy + m_entry_height));
			drawText("\u2699", gear_x + 3, iy + (m_entry_height - m_fontsize.Y) / 2,
				m_selected_font_color);
		}

		iy += m_entry_height + m_gap;
		chi++;
	}

	if (m_hover_start > 0.0) {
		bool hovering = false;
		for (auto &p : m_panels) {
			if (!isCatPanel(p) && !isFavPanel(p)) continue;
			s32 iy2 = p.y + p.title_h + m_gap;
			for ([[maybe_unused]] auto &de2 : entries) {
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

			driver->draw2DRectangle(m_tooltip_bg,
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
	if (!isCatPanel(panel) && !isFavPanel(panel) && !isSuperPanel(panel) && !isRecentPanel(panel))
		return;
	CHEAT_MENU_GET_SCRIPTPTR

	// Supermenu panel
	if (isSuperPanel(panel)) {
		s32 iy = cy;
		int chi = 0;
		if (m_super_level == 0) {
			for (size_t ci = 0; ci < script->m_cheat_categories.size(); ci++) {
				if (!matchesSearch(script->m_cheat_categories[ci]->m_name, m_search_text))
					continue;
				if (pointInRect(pos.X, pos.Y, panel.x, iy, panel.w, m_entry_height)) {
					m_super_level = 1;
					m_super_selected_category = (int)ci;
					panel.selected_cheat = 0;
					m_panels[panel_idx].title = script->m_cheat_categories[ci]->m_name;
					return;
				}
				iy += m_entry_height + m_gap;
				chi++;
			}
		} else {
			// Back button
			if (pointInRect(pos.X, pos.Y, panel.x, iy, panel.w, m_entry_height)) {
				m_super_level = 0;
				panel.selected_cheat = chi;
				m_panels[panel_idx].title = "Menu";
				return;
			}
			iy += m_entry_height + m_gap;

			// Cheats
			if (m_super_selected_category >= 0 && (size_t)m_super_selected_category < script->m_cheat_categories.size()) {
				for (auto &cheat : script->m_cheat_categories[m_super_selected_category]->m_cheats) {
					if (!matchesSearch(cheat->m_name, m_search_text))
						continue;
					if (pointInRect(pos.X, pos.Y, panel.x, iy, panel.w, m_entry_height)) {
						panel.selected_cheat = chi;
						script->toggle_cheat(cheat);
						addRecentCheat(cheat->m_setting);
						return;
					}
					iy += m_entry_height + m_gap;
					chi++;
				}
			}
		}
		return;
	}

	// Collect entries
	struct Entry {
		ScriptApiCheatsCheat *cheat;
	};
	std::vector<Entry> entries;

	auto favs = getFavoritesSet();

	if (isRecentPanel(panel)) {
		for (auto &setting : m_recent_cheats) {
			for (auto &cat : script->m_cheat_categories)
				for (auto *ch : cat->m_cheats)
					if (ch->m_setting == setting) {
						entries.push_back({ch});
						goto next_recent_click;
					}
		next_recent_click:;
		}
	} else if (isFavPanel(panel)) {
		for (size_t ci = 0; ci < script->m_cheat_categories.size(); ci++)
			for (auto &cheat : script->m_cheat_categories[ci]->m_cheats)
				if (favs.count(cheat->m_setting) && matchesSearch(cheat->m_name, m_search_text))
					entries.push_back({cheat});
	} else if (panel.selected_category >= 0 && (size_t)panel.selected_category < script->m_cheat_categories.size()) {
		for (auto &cheat : script->m_cheat_categories[panel.selected_category]->m_cheats)
			if (matchesSearch(cheat->m_name, m_search_text))
				entries.push_back({cheat});
	}

	s32 iy = cy;
	int chi = 0;
	for (auto &e : entries) {
		if (pointInRect(pos.X, pos.Y, panel.x, iy, panel.w, m_entry_height)) {
			// Star zone (far right)
			s32 star_x = panel.x + panel.w - 18;
			if (pointInRect(pos.X, pos.Y, star_x, iy, 16, m_entry_height)) {
				toggleFavorite(e.cheat->m_setting);
				return;
			}

			// Gear zone (left of star)
			bool has_set = false;
			lua_State *L = m_client->getScript()->getLuaState();
			lua_getglobal(L, "core");
			lua_getfield(L, -1, "cheat_defs");
			lua_getfield(L, -1, e.cheat->m_setting.c_str());
			if (lua_istable(L, -1)) {
				lua_getfield(L, -1, "cheat_settings");
				has_set = lua_istable(L, -1) || lua_isfunction(L, -1);
				lua_pop(L, 1);
			}
			lua_pop(L, 3);

			if (has_set) {
				s32 gear_x = panel.x + panel.w - 36;
				if (pointInRect(pos.X, pos.Y, gear_x, iy, 16, m_entry_height)) {
					closeForFormspec();
					script->show_cheat_settings(e.cheat->m_setting);
					return;
				}
			}

			// Main area: toggle cheat
			panel.selected_cheat = chi;
			script->toggle_cheat(e.cheat);
			addRecentCheat(e.cheat->m_setting);
			return;
		}
		iy += m_entry_height + m_gap;
		chi++;
	}
}

void CheatMenu::closeForFormspec()
{
	g_cheat_layer_active = false;
	if (g_cheat_menu)
		g_cheat_menu->onLayerClosed();
	auto *device = RenderingEngine::get_raw_device();
	if (device) {
		if (auto *cur = device->getCursorControl())
			cur->setVisible(false);
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

	// Remove saved positions for special panels so they always reset to left
	g_settings->remove("panel_pos__fav_0");
	g_settings->remove("panel_pos__super_0");
	g_settings->remove("panel_pos__recent_0");

	for (s32 i = (s32)m_panels.size() - 1; i >= 0; i--) {
		auto &p = m_panels[i];
		if ((isCatPanel(p) || isFavPanel(p) || isSuperPanel(p) || isRecentPanel(p)) && !p.pinned)
			m_panels.erase(m_panels.begin() + i);
	}
}

void CheatMenu::drawHUD(video::IVideoDriver *driver, double dtime)
{
	CHEAT_MENU_GET_SCRIPTPTR
	float speed = g_settings->getFloat("cheat_hud.speed", 0.0f, 10.0f);
	if (speed <= 0) speed = 1.0f;
	m_rainbow_offset += dtime * speed;
	m_rainbow_offset = std::fmod(m_rainbow_offset, 6.0f);

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
		f32 xv = (1 - std::abs(std::fmod(h, 2.0f) - 1.0f)) * 255.0f;
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
	} else if (isFavPanel(*panel)) {
		int max = countFavoritedCheats(script) - 1;
		panel->selected_cheat--;
		if (panel->selected_cheat < 0) panel->selected_cheat = max;
	} else if (isRecentPanel(*panel)) {
		int max = (int)m_recent_cheats.size() - 1;
		panel->selected_cheat--;
		if (panel->selected_cheat < 0) panel->selected_cheat = max;
	} else if (isSuperPanel(*panel)) {
		int max = 1;
		if (m_super_level == 0) {
			max = 0;
			for (auto &cat : script->m_cheat_categories)
				if (matchesSearch(cat->m_name, m_search_text))
					max++;
			max--;
		} else {
			max = 0;
			if (m_super_selected_category >= 0 && (size_t)m_super_selected_category < script->m_cheat_categories.size())
				for (auto &cheat : script->m_cheat_categories[m_super_selected_category]->m_cheats)
					if (matchesSearch(cheat->m_name, m_search_text))
						max++;
		}
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
	} else if (isFavPanel(*panel)) {
		int max = countFavoritedCheats(script) - 1;
		panel->selected_cheat++;
		if (panel->selected_cheat > max) panel->selected_cheat = 0;
	} else if (isRecentPanel(*panel)) {
		int max = (int)m_recent_cheats.size() - 1;
		panel->selected_cheat++;
		if (panel->selected_cheat > max) panel->selected_cheat = 0;
	} else if (isSuperPanel(*panel)) {
		int max = 1;
		if (m_super_level == 0) {
			max = 0;
			for (auto &cat : script->m_cheat_categories)
				if (matchesSearch(cat->m_name, m_search_text))
					max++;
			max--;
		} else {
			max = 0;
			if (m_super_selected_category >= 0 && (size_t)m_super_selected_category < script->m_cheat_categories.size())
				for (auto &cheat : script->m_cheat_categories[m_super_selected_category]->m_cheats)
					if (matchesSearch(cheat->m_name, m_search_text))
						max++;
		}
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
				addRecentCheat(cheat->m_setting);
			}
		}
	} else if (isFavPanel(*panel)) {
		int idx = 0;
		for (auto &cat : script->m_cheat_categories) {
			for (auto &cheat : cat->m_cheats) {
				if (isFavorite(cheat->m_setting)) {
					if (idx == panel->selected_cheat) {
						script->toggle_cheat(cheat);
						addRecentCheat(cheat->m_setting);
						return;
					}
					idx++;
				}
			}
		}
	} else if (isRecentPanel(*panel)) {
		int idx = 0;
		for (auto &setting : m_recent_cheats) {
			for (auto &cat : script->m_cheat_categories)
				for (auto *ch : cat->m_cheats)
					if (ch->m_setting == setting) {
						if (idx == panel->selected_cheat) {
							script->toggle_cheat(ch);
							addRecentCheat(ch->m_setting);
							return;
						}
						idx++;
						break;
					}
		}
	} else if (isSuperPanel(*panel)) {
		if (m_super_level == 0) {
			int cat_idx = 0;
			for (size_t ci = 0; ci < script->m_cheat_categories.size(); ci++) {
				if (!matchesSearch(script->m_cheat_categories[ci]->m_name, m_search_text))
					continue;
				if (cat_idx == panel->selected_cheat) {
					m_super_level = 1;
					m_super_selected_category = (int)ci;
					panel->selected_cheat = 0;
					panel->title = script->m_cheat_categories[ci]->m_name;
					return;
				}
				cat_idx++;
			}
		} else {
			if (panel->selected_cheat == 0) {
				m_super_level = 0;
				panel->selected_cheat = 0;
				panel->title = "Menu";
				return;
			}
			int cheat_idx = 1;
			if (m_super_selected_category >= 0 && (size_t)m_super_selected_category < script->m_cheat_categories.size()) {
				for (auto &cheat : script->m_cheat_categories[m_super_selected_category]->m_cheats) {
					if (!matchesSearch(cheat->m_name, m_search_text))
						continue;
					if (cheat_idx == panel->selected_cheat) {
						script->toggle_cheat(cheat);
						addRecentCheat(cheat->m_setting);
						return;
					}
					cheat_idx++;
				}
			}
		}
	}
}

void CheatMenu::handleMouse(v2s32 pos, bool left_down)
{
	static bool left_prev = false;
	bool clicked = !left_prev && left_down;
	left_prev = left_down;

	if (!clicked) {
		PanelOverlay::handleMouse(pos, left_down);
		return;
	}

	// Check profiles popup clicks BEFORE panel handler (popup is topmost layer)
	if (m_profiles_active) {
		s32 entry_h = 30;
		s32 gap = 2;
		s32 px = m_profiles_pos.X;
		s32 py = m_profiles_pos.Y;
		int num_items = (int)m_profile_names.size() + 2;
		s32 pw = 200;
		s32 ph = num_items * entry_h + (num_items - 1) * gap + 6;
		if (pointInRect(pos.X, pos.Y, px, py, pw, ph)) {
			s32 iy = py + 3;
			int idx = 0;
			for (size_t i = 0; i < m_profile_names.size(); i++) {
				if (pointInRect(pos.X, pos.Y, px + 1, iy, pw - 2, entry_h)) {
					m_profiles_selected = idx;
					m_profiles_active = false;
					loadProfile(i);
					return;
				}
				iy += entry_h + gap;
				idx++;
			}
			if (pointInRect(pos.X, pos.Y, px + 1, iy, pw - 2, entry_h)) {
				m_profiles_active = false;
				lua_State *L = m_client->getScript()->getLuaState();
				lua_getglobal(L, "core");
				lua_getfield(L, -1, "save_cheat_profile_dialog");
				if (lua_isfunction(L, -1))
					lua_pcall(L, 0, 0, 0);
				lua_pop(L, 2);
				return;
			}
			iy += entry_h + gap;
			idx++;
			if (pointInRect(pos.X, pos.Y, px + 1, iy, pw - 2, entry_h)) {
				m_profiles_active = false;
				lua_State *L = m_client->getScript()->getLuaState();
				lua_getglobal(L, "core");
				lua_getfield(L, -1, "run_server_chatcommand");
				if (lua_isfunction(L, -1)) {
					lua_pushstring(L, "profile");
					lua_pushstring(L, "list");
					lua_pcall(L, 2, 0, 0);
				}
				lua_pop(L, 2);
				return;
			}
			return;
		}
		m_profiles_active = false;
	}

	// Handle context menu left-click
	if (m_ctx.active) {
		if (handleContextMenuItemClick(pos))
			return;
		dismissContextMenu();
	}

	// Forward to panel handler
	PanelOverlay::handleMouse(pos, left_down);

	// Check profiles button click
	s32 bar_w = 400;
	s32 bar_x = ((s32)m_screen_size.X - bar_w) / 2;
	s32 btn_x = bar_x + bar_w + 6;
	s32 btn_w = 90;
	s32 bar_y = 8;
	s32 btn_h = 34;
	if (pointInRect(pos.X, pos.Y, btn_x, bar_y, btn_w, btn_h)) {
		refreshProfileList();
		m_profiles_active = true;
		return;
	}

	// Click outside context menu → dismiss
	if (m_ctx.active && !pointInRect(pos.X, pos.Y, m_ctx.x, m_ctx.y, m_ctx.w, m_ctx.h))
		dismissContextMenu();
}

void CheatMenu::drawAll(video::IVideoDriver *driver, v2s32 mouse_pos, bool show_debug)
{
	PanelOverlay::drawAll(driver, mouse_pos, show_debug);
	drawContextMenu(driver);
	drawProfilesPopup(driver);
}

bool CheatMenu::isFavorite(const std::string &setting) const
{
	auto favs = getFavoritesSet();
	return favs.count(setting) > 0;
}

void CheatMenu::toggleFavorite(const std::string &setting)
{
	lua_State *L = m_client->getScript()->getLuaState();
	lua_getglobal(L, "core");
	lua_getfield(L, -1, "toggle_favorite");
	if (lua_isfunction(L, -1)) {
		lua_pushstring(L, setting.c_str());
		lua_call(L, 1, 0);
	}
	lua_pop(L, 2);
}

int CheatMenu::countFavoritedCheats(ClientScripting *script) const
{
	int count = 0;
	for (auto &cat : script->m_cheat_categories)
		for (auto &cheat : cat->m_cheats)
			if (isFavorite(cheat->m_setting))
				count++;
	return count;
}

void CheatMenu::drawSearchBar(video::IVideoDriver *driver)
{
	auto ss = driver->getScreenSize();
	s32 bar_w = 400;
	s32 bar_h = 34;
	s32 bar_x = ((s32)ss.Width - bar_w) / 2;
	s32 bar_y = 8;

	driver->draw2DRectangle(m_panel_bg,
		core::rect<s32>(bar_x - 2, bar_y - 2, bar_x + bar_w + 2, bar_y + bar_h + 2));

	driver->draw2DRectangle(m_item_bg,
		core::rect<s32>(bar_x, bar_y, bar_x + bar_w, bar_y + bar_h));

	std::string display;
	if (m_search_text.empty())
		display = "Search cheats... (\u2386 to clear)";
	else
		display = "\u2315 " + m_search_text;

	drawText(display, bar_x + 8, bar_y + (bar_h - m_fontsize.Y) / 2,
		m_search_text.empty() ? m_font_color : m_selected_font_color);

	// Profiles button to the right of the search bar
	s32 btn_x = bar_x + bar_w + 6;
	s32 btn_w = 90;
	driver->draw2DRectangle(m_item_bg,
		core::rect<s32>(btn_x, bar_y, btn_x + btn_w, bar_y + bar_h));
	drawText("Profiles \u25BC", btn_x + 4, bar_y + (bar_h - m_fontsize.Y) / 2, m_font_color);
	m_profiles_pos = v2s32(btn_x, bar_y + bar_h + 2);
}

bool CheatMenu::pollInput()
{
	if (!g_cheat_layer_active && !m_quick_palette_active)
		return false;

	auto *device = RenderingEngine::get_raw_device();
	auto *receiver = static_cast<MyEventReceiver *>(device->getEventReceiver());

	if (!receiver->cheat_char_avail)
		return false;

	receiver->consumeCheatChar();
	wchar_t c = receiver->cheat_char;

	if (m_quick_palette_active) {
		if (c == 8) {
			if (!m_quick_palette_text.empty())
				m_quick_palette_text.pop_back();
		} else if (c == 27) {
			if (!m_quick_palette_text.empty()) {
				m_quick_palette_text.clear();
			} else {
				m_quick_palette_active = false;
				if (auto *device = RenderingEngine::get_raw_device())
					if (auto *cur = device->getCursorControl())
						cur->setVisible(false);
			}
		} else if (c >= 32) {
			m_quick_palette_text += (char)c;
		}
		m_quick_palette_selected = 0;
		return false;
	}

	if (c == 8) {
		if (!m_search_text.empty())
			m_search_text.pop_back();
	} else if (c == 27) {
		if (!m_search_text.empty()) {
			m_search_text.clear();
		} else {
			return true;
		}
	} else if (c >= '1' && c <= '9' && m_search_text.empty()) {
		// Quick slot toggle: 1-9 without search text
		int slot = c - '0';
		std::string setting = g_settings->get("cheat_slot_" + std::to_string(slot));
		if (!setting.empty() && setting.find("cheat_slot_") != 0) {
			bool val = g_settings->getBool(setting);
			g_settings->setBool(setting, !val);
		}
		return false;
	} else if (c >= 32) {
		m_search_text += (char)c;
	}
	return false;
}

void CheatMenu::toggleQuickPalette()
{
	if (m_quick_palette_active) {
		m_quick_palette_active = false;
		g_quick_palette_active = false;
	} else {
		// Clear any stale character from the ~ key that opened the palette
		auto *device = RenderingEngine::get_raw_device();
		if (device) {
			auto *receiver = static_cast<MyEventReceiver *>(device->getEventReceiver());
			receiver->consumeCheatChar();
		}
		m_quick_palette_text.clear();
		m_quick_palette_selected = 0;
		m_quick_palette_active = true;
		g_quick_palette_active = true;
	}
}

void CheatMenu::drawQuickPalette(video::IVideoDriver *driver)
{
	if (!m_quick_palette_active)
		return;

	auto ss = driver->getScreenSize();
	driver->draw2DRectangle(video::SColor(180, 0, 0, 0),
		core::rect<s32>(0, 0, ss.Width, ss.Height));

	s32 pw = 450;
	s32 ph = 400;
	s32 px = ((s32)ss.Width - pw) / 2;
	s32 py = ((s32)ss.Height - ph) / 2;

	drawRoundedRect(driver, px, py, pw, ph, m_panel_bg, m_bg_color);

	// Search field
	s32 search_y = py + 10;
	driver->draw2DRectangle(m_item_bg,
		core::rect<s32>(px + 8, search_y, px + pw - 8, search_y + 34));
	std::string display = m_quick_palette_text.empty()
		? "Search cheats..."
		: "\u2315 " + m_quick_palette_text;
	drawText(display, px + 14, search_y + (34 - m_fontsize.Y) / 2,
		m_selected_font_color);

	// Collect matching entries
	ClientScripting *script = m_client->getScript();
	std::vector<ScriptApiCheatsCheat *> entries;
	if (script && script->m_cheats_loaded) {
		for (auto &cat : script->m_cheat_categories)
			for (auto &cheat : cat->m_cheats)
				if (matchesSearch(cheat->m_name, m_quick_palette_text))
					entries.push_back(cheat);
	}

	// Results list
	s32 list_y = search_y + 42;
	int idx = 0;
	auto clip_bottom = py + ph - 10;
	for (auto *cheat : entries) {
		if (list_y + m_entry_height > clip_bottom) break;

		bool selected = (idx == m_quick_palette_selected);
		video::SColor cbg = selected ? m_active_bg_color : m_item_bg;
		driver->draw2DRectangle(cbg,
			core::rect<s32>(px + 1, list_y, px + pw - 1, list_y + m_entry_height));

		std::string txt = cheat->is_enabled() ? "[x] " : "[ ] ";
		txt += cheat->m_name;
		drawText(txt, px + 10, list_y + (m_entry_height - m_fontsize.Y) / 2,
			selected ? m_selected_font_color : m_font_color);

		list_y += m_entry_height + m_gap;
		idx++;
	}
}

void CheatMenu::pollQuickPaletteInput()
{
	if (!m_quick_palette_active)
		return;

	auto *device = RenderingEngine::get_raw_device();
	auto *receiver = static_cast<MyEventReceiver *>(device->getEventReceiver());
	if (!receiver->cheat_char_avail)
		return;

	receiver->consumeCheatChar();
	wchar_t c = receiver->cheat_char;

	if (c == 8) {
		if (!m_quick_palette_text.empty())
			m_quick_palette_text.pop_back();
	} else if (c == 27) {
		if (!m_quick_palette_text.empty())
			m_quick_palette_text.clear();
		else
			m_quick_palette_active = false;
	} else if (c >= 32) {
		m_quick_palette_text += (char)c;
	}
	m_quick_palette_selected = 0;
}

void CheatMenu::paletteUp()
{
	if (!m_quick_palette_active) return;
	ClientScripting *script = m_client->getScript();
	if (!script || !script->m_cheats_loaded) return;

	int count = 0;
	for (auto &cat : script->m_cheat_categories)
		for (auto &cheat : cat->m_cheats)
			if (matchesSearch(cheat->m_name, m_quick_palette_text))
				count++;

	if (count <= 0) return;
	m_quick_palette_selected--;
	if (m_quick_palette_selected < 0) m_quick_palette_selected = count - 1;
}

void CheatMenu::paletteDown()
{
	if (!m_quick_palette_active) return;
	ClientScripting *script = m_client->getScript();
	if (!script || !script->m_cheats_loaded) return;

	int count = 0;
	for (auto &cat : script->m_cheat_categories)
		for (auto &cheat : cat->m_cheats)
			if (matchesSearch(cheat->m_name, m_quick_palette_text))
				count++;

	if (count <= 0) return;
	m_quick_palette_selected++;
	if (m_quick_palette_selected >= count) m_quick_palette_selected = 0;
}

void CheatMenu::paletteConfirm()
{
	if (!m_quick_palette_active) return;
	ClientScripting *script = m_client->getScript();
	if (!script || !script->m_cheats_loaded) return;

	int idx = 0;
	for (auto &cat : script->m_cheat_categories)
		for (auto &cheat : cat->m_cheats) {
			if (!matchesSearch(cheat->m_name, m_quick_palette_text))
				continue;
			if (idx == m_quick_palette_selected) {
				script->toggle_cheat(cheat);
				addRecentCheat(cheat->m_setting);
				return;
			}
			idx++;
		}
}

void CheatMenu::createSupermenuPanel()
{
	OverlayPanel sp;
	sp.id = "_super_0";
	sp.title = "Menu";
	sp.w = m_entry_width > 0 ? m_entry_width : 220;
	sp.title_h = m_head_height;
	m_panels.push_back(sp);
	g_settings->remove("panel_pos__super_0");
	m_super_level = 0;
}

void CheatMenu::autoTilePanels(v2u32 screen_size)
{
	s32 margin = 10;

	// Compute panel heights
	for (auto &panel : m_panels)
		panel.h = panel.title_h + getPanelContentHeight(panel);

	auto isSpecial = [&](const OverlayPanel &p) -> bool {
		return isFavPanel(p) || isSuperPanel(p) || isRecentPanel(p);
	};

	// Left column reserved for special panels
	s32 left_col_x = margin;

	// Stack special panels vertically in left column
	s32 left_y = 60;
	for (auto &panel : m_panels) {
		if (isSpecial(panel)) {
			panel.x = left_col_x;
			panel.y = left_y;
			panel.detached = false;
			left_y += panel.h + m_gap;
		}
	}

	// Collect non-special panels and sort by height (tallest first)
	std::vector<size_t> order;
	for (size_t i = 0; i < m_panels.size(); i++) {
		if (!isSpecial(m_panels[i]))
			order.push_back(i);
	}
	std::stable_sort(order.begin(), order.end(), [&](size_t a, size_t b) {
		return m_panels[a].h > m_panels[b].h;
	});

	// Mark special panels as already placed
	std::vector<bool> placed(m_panels.size(), false);
	for (size_t i = 0; i < m_panels.size(); i++) {
		if (isSpecial(m_panels[i]))
			placed[i] = true;
	}

	auto overlaps = [&](size_t idx, s32 tx, s32 ty) -> bool {
		for (size_t j = 0; j < m_panels.size(); j++) {
			if (!placed[j] || j == idx) continue;
			auto &p = m_panels[j];
			if (tx + m_panels[idx].w > p.x && tx < p.x + p.w &&
					ty + m_panels[idx].h > p.y && ty < p.y + p.h)
				return true;
		}
		return false;
	};

	s32 right_start = margin;
	for (auto &p : m_panels) {
		if (isSpecial(p))
			right_start = std::max(right_start, p.x + p.w + m_gap);
	}

	// Edge-snapping packer for remaining panels, starting from right_start
	for (auto i : order) {
		s32 px = right_start, py = 60;
		bool found = false;

		// Try saved position (must be at or right of right_start)
		OverlayPanel saved;
		saved.id = m_panels[i].id;
		loadPanelPosition(saved);
		if ((saved.x != 0 || saved.y != 0) && saved.x >= right_start && !overlaps(i, saved.x, saved.y)) {
			px = saved.x;
			py = saved.y;
			found = true;
		}

		if (!found) {
			std::vector<s32> ys = {60};
			for (size_t j = 0; j < m_panels.size(); j++) {
				if (!placed[j]) continue;
				s32 by = m_panels[j].y + m_panels[j].h + m_gap;
				if (by + m_panels[i].h <= (s32)screen_size.Y)
					ys.push_back(by);
			}
			std::sort(ys.begin(), ys.end());

			for (auto cy : ys) {
				std::vector<s32> xs = {right_start};
				for (size_t j = 0; j < m_panels.size(); j++) {
					if (!placed[j]) continue;
					auto &p = m_panels[j];
					if (cy < p.y + p.h && cy + m_panels[i].h > p.y) {
						s32 rx = p.x + p.w + m_gap;
						if (rx + m_panels[i].w <= (s32)screen_size.X - margin)
							xs.push_back(rx);
					}
				}
				std::sort(xs.begin(), xs.end());

				for (auto cx : xs) {
					if (!overlaps(i, cx, cy)) {
						px = cx;
						py = cy;
						found = true;
						break;
					}
				}
				if (found) break;
			}
		}

		m_panels[i].x = px;
		m_panels[i].y = py;
		m_panels[i].detached = false;
		placed[i] = true;
	}
}
