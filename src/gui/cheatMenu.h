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

#pragma once

#include "overlayPanel.h"
#include "client/client.h"
#include "script/scripting_client.h"

extern class CheatMenu *g_cheat_menu;
extern bool g_cheat_layer_active;
extern bool g_show_minimal_debug;

#define CHEAT_MENU_GET_SCRIPTPTR                                                         \
	ClientScripting *script = m_client->getScript();                                 \
	if (!script || !script->m_cheats_loaded)                                         \
		return;

#define CHEAT_MENU_GET_SCRIPTPTR_RET(retval)                                             \
	ClientScripting *script = m_client->getScript();                                 \
	if (!script || !script->m_cheats_loaded)                                         \
		return retval;

class CheatMenu : public PanelOverlay
{
public:
	CheatMenu(Client *client);

	ClientScripting *getScript() { return m_client->getScript(); }

	void drawHUD(video::IVideoDriver *driver, double dtime);

	void createCategoryPanels();
	void onLayerClosed();

	void selectUp();
	void selectDown();
	void selectLeft();
	void selectRight();
	void selectConfirm();

protected:
	void initPanels() override { createCategoryPanels(); }
	s32 getPanelContentHeight(const OverlayPanel &panel) override;
	void drawPanelContent(video::IVideoDriver *driver,
		OverlayPanel &panel, s32 content_x, s32 content_y,
		s32 content_w, s32 content_h, v2s32 mouse_pos) override;
	void handlePanelContentClick(size_t panel_idx, v2s32 pos, s32 cx, s32 cy, s32 cw) override;

private:
	Client *m_client;

	float m_rainbow_offset = 0.0;

	// Tooltip state
	std::string m_tooltip_text;
	s32 m_tooltip_x = 0, m_tooltip_y = 0;
	u64 m_hover_start = 0;
};
