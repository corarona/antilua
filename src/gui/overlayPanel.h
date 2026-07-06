// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "irrlichttypes_bloated.h"
#include <IVideoDriver.h>
#include <SColor.h>
#include <IGUIFont.h>
#include "client/fontengine.h"
#include <cstddef>
#include <string>
#include <vector>

struct OverlayPanel {
	std::string id;
	std::string title;
	s32 x = 0, y = 0, w = 220, h = 0;
	s32 title_h = 30;
	int selected_category = 0;
	int selected_cheat = 0;
	bool pinned = false;
	bool detached = false;
	bool keyboard_focus = false;
	bool hover_title = false;
	bool hover_pin = false;
	bool hover_focus = false;
};

class PanelOverlay
{
public:
	PanelOverlay();
	virtual ~PanelOverlay() = default;

	void drawAll(video::IVideoDriver *driver, v2s32 mouse_pos, bool show_debug);
	void drawPinned(video::IVideoDriver *driver, v2s32 mouse_pos);

	void handleMouse(v2s32 pos, bool left_down);
	void onLayerClosed();

	virtual void autoTilePanels(v2u32 screen_size);
	void snapPanel(int idx);
	bool overlapsAny(int idx, s32 tx, s32 ty);
	void rearrangePanels();

protected:
	// Subclasses implement panel content
	virtual void initPanels() = 0;
	virtual s32 getPanelContentHeight(const OverlayPanel &panel) = 0;
	virtual void drawPanelContent(video::IVideoDriver *driver,
		OverlayPanel &panel, s32 content_x, s32 content_y,
		s32 content_w, s32 content_h, v2s32 mouse_pos) = 0;
	virtual void handlePanelContentClick(size_t panel_idx, v2s32 pos, s32 cx, s32 cy, s32 cw);

	// Drawing helpers
	void drawPanelChrome(video::IVideoDriver *driver, OverlayPanel &panel, v2s32 mouse_pos);
	static bool pointInRect(s32 px, s32 py, s32 x, s32 y, s32 w, s32 h);

	void loadPanelPosition(OverlayPanel &panel);
	void savePanelPositions();

	// Configurable panel styles (subclasses can override)
	s32 m_head_height = 50;
	s32 m_entry_height = 40;
	s32 m_entry_width = 200;
	s32 m_gap = 3;

	video::SColor m_panel_bg = video::SColor(204, 30, 30, 45);
	video::SColor m_title_bg = video::SColor(204, 50, 50, 75);
	video::SColor m_border_color = video::SColor(204, 70, 70, 100);
	video::SColor m_item_bg = video::SColor(204, 55, 55, 75);
	video::SColor m_font_color = video::SColor(255, 0, 0, 0);
	video::SColor m_selected_font_color = video::SColor(255, 255, 252, 88);
	video::SColor m_bg_color = video::SColor(204, 255, 145, 88);
	video::SColor m_active_bg_color = video::SColor(204, 255, 87, 53);

	gui::IGUIFont *m_font = nullptr;
	v2u32 m_fontsize;

	std::vector<OverlayPanel> m_panels;
	v2u32 m_screen_size{0, 0};
	bool m_categories_initialized = false;

	s32 m_prev_mouse_x = 0, m_prev_mouse_y = 0;
	bool m_mouse_left_prev = false;
	int m_drag_panel = -1;
	s32 m_drag_off_x = 0, m_drag_off_y = 0;

	FontMode fontStringToEnum(const std::string &str);
	void drawRoundedRect(video::IVideoDriver *driver, s32 x, s32 y, s32 w, s32 h,
		video::SColor fill, video::SColor bg, s32 r = 4);
	void drawRoundedBorder(video::IVideoDriver *driver, s32 x, s32 y, s32 w, s32 h,
		video::SColor color, s32 r = 4);
	void drawText(const std::string &text, s32 x, s32 y, const video::SColor &color);
};
