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

#pragma once

#include "client/client.h"
#include "client/fontengine.h"
#include "irrlichttypes_bloated.h"
#include <IVideoDriver.h>
#include <SColor.h>
#include <IGUIFont.h>
#include "script/scripting_client.h"
#include "gui/mainmenumanager.h"
#include <cstddef>
#include <string>
#include <vector>

#define CHEAT_MENU_GET_SCRIPTPTR                                                         \
	ClientScripting *script = m_client->getScript();                                 \
	if (!script || !script->m_cheats_loaded)                                         \
		return;

enum CheatMenuEntryType
{
	CHEAT_MENU_ENTRY_TYPE_HEAD,
	CHEAT_MENU_ENTRY_TYPE_CATEGORY,
	CHEAT_MENU_ENTRY_TYPE_ENTRY,
};

struct CheatPanel {
	std::string id;
	int selected_category = 0;
	int selected_cheat = 0;
	s32 x = 0, y = 0, w = 220, h = 0;
	s32 title_h = 30;
	bool pinned = false;
	bool detached = false;
	bool keyboard_focus = false;
	bool hover_title = false;
	bool hover_pin = false;
	bool hover_focus = false;
};

class CheatMenu
{
public:
	CheatMenu(Client *client);

	ClientScripting *getScript() { return m_client->getScript(); }

	void drawPanels(video::IVideoDriver *driver, v2s32 mouse_pos, bool show_debug);
	void drawPinned(video::IVideoDriver *driver, v2s32 mouse_pos);
	void drawHUD(video::IVideoDriver *driver, double dtime);

	void handleMouse(v2s32 pos, bool left_down);
	void onLayerClosed();

	void createCategoryPanels();
	void autoTilePanels(v2u32 screen_size);
	void snapPanel(int idx);
	bool overlapsAny(int idx, s32 tx, s32 ty);

	void selectUp();
	void selectDown();
	void selectLeft();
	void selectRight();
	void selectConfirm();

private:
	void drawPanel(video::IVideoDriver *driver, CheatPanel &panel, v2s32 mouse_pos);
	void loadPanelPosition(CheatPanel &panel);
	void savePanelPositions();

	FontMode fontStringToEnum(std::string str);

	int m_selected_cheat = 0;
	int m_selected_category = 0;

	int m_head_height = 50;
	int m_entry_height = 40;
	int m_entry_width = 200;
	int m_gap = 3;

	video::SColor m_bg_color = video::SColor(192, 255, 145, 88);
	video::SColor m_active_bg_color = video::SColor(192, 255, 87, 53);
	video::SColor m_font_color = video::SColor(255, 0, 0, 0);
	video::SColor m_selected_font_color = video::SColor(255, 255, 252, 88);
	video::SColor m_panel_bg = video::SColor(230, 30, 30, 45);
	video::SColor m_title_bg = video::SColor(230, 50, 50, 75);
	video::SColor m_border_color = video::SColor(230, 70, 70, 100);
	video::SColor m_item_bg = video::SColor(200, 55, 55, 75);

	Client *m_client;

	gui::IGUIFont *m_font = nullptr;
	v2u32 m_fontsize;

	float m_rainbow_offset = 0.0;

	// Panel system
	std::vector<CheatPanel> m_panels;
	s32 m_prev_mouse_x = 0, m_prev_mouse_y = 0;
	bool m_mouse_left_prev = false;
	int m_drag_panel = -1;
	s32 m_drag_off_x = 0, m_drag_off_y = 0;

	// State
	v2u32 m_screen_size{0, 0};
	bool m_categories_initialized = false;

	// Tooltip state
	std::string m_tooltip_text;
	s32 m_tooltip_x = 0, m_tooltip_y = 0;
	u64 m_hover_start = 0;
};
