// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "overlayPanel.h"
#include "porting.h"
#include "settings.h"
#include "util/string.h"
#include <algorithm>
#include <cstdlib>

PanelOverlay::PanelOverlay()
{
	m_font = g_fontengine->getFont(FONT_SIZE_UNSPECIFIED, FM_Standard);
	if (m_font) {
		core::dimension2d<u32> dim = m_font->getDimension(L"M");
		m_fontsize = v2u32(dim.Width, dim.Height);
		m_font->grab();
	}
	m_fontsize.X = MYMAX(m_fontsize.X, 1);
	m_fontsize.Y = MYMAX(m_fontsize.Y, 1);
}

FontMode PanelOverlay::fontStringToEnum(const std::string &str)
{
	if (str == "FM_Standard") return FM_Standard;
	if (str == "FM_Mono") return FM_Mono;
	if (str == "FM_Fallback") return _FM_Fallback;
	if (str == "FM_MaxMode") return FM_MaxMode;
	if (str == "FM_Unspecified") return FM_Unspecified;
	return FM_Standard;
}

bool PanelOverlay::pointInRect(s32 px, s32 py, s32 x, s32 y, s32 w, s32 h)
{
	return px >= x && px < x + w && py >= y && py < y + h;
}

void PanelOverlay::drawRoundedRect(video::IVideoDriver *driver,
	s32 x, s32 y, s32 w, s32 h, video::SColor fill, video::SColor bg, s32 r)
{
	driver->draw2DRectangle(fill, core::rect<s32>(x + r, y, x + w - r, y + h));
	driver->draw2DRectangle(fill, core::rect<s32>(x, y + r, x + r, y + h - r));
	driver->draw2DRectangle(fill, core::rect<s32>(x + w - r, y + r, x + w, y + h - r));
	for (s32 i = 0; i < r; i++) {
		for (s32 j = 0; j < r; j++) {
			if ((i + 1) * (i + 1) + (j + 1) * (j + 1) > r * r) {
				s32 px = 1, py = 1;
				driver->draw2DRectangle(bg, core::rect<s32>(x + i, y + j, x + i + px, y + j + py));
				driver->draw2DRectangle(bg, core::rect<s32>(x + w - i - px, y + j, x + w - i, y + j + py));
				driver->draw2DRectangle(bg, core::rect<s32>(x + i, y + h - j - py, x + i + px, y + h - j));
				driver->draw2DRectangle(bg, core::rect<s32>(x + w - i - px, y + h - j - py, x + w - i, y + h - j));
			}
		}
	}
}

void PanelOverlay::drawRoundedBorder(video::IVideoDriver *driver,
	s32 x, s32 y, s32 w, s32 h, video::SColor color, s32 r)
{
	driver->draw2DRectangle(color, core::rect<s32>(x + r, y, x + w - r, y + 1));
	driver->draw2DRectangle(color, core::rect<s32>(x + r, y + h - 1, x + w - r, y + h));
	driver->draw2DRectangle(color, core::rect<s32>(x, y + r, x + 1, y + h - r));
	driver->draw2DRectangle(color, core::rect<s32>(x + w - 1, y + r, x + w, y + h - r));
}

void PanelOverlay::drawText(const std::string &text, s32 x, s32 y, const video::SColor &color)
{
	if (!m_font)
		return;
	s32 fw = m_font->getDimension(utf8_to_wide(text).c_str()).Width;
	s32 fh = m_font->getDimension(L"M").Height;
	core::rect<s32> r(x, y, x + fw, y + fh);
	m_font->draw(utf8_to_wide(text).c_str(), r, color, false, false);
}

void PanelOverlay::drawPanelChrome(video::IVideoDriver *driver,
	OverlayPanel &panel, v2s32 mouse_pos)
{
	s32 &x = panel.x, &y = panel.y;
	s32 w = panel.w, h = panel.h;

	drawRoundedRect(driver, x, y, w, h, m_panel_bg, video::SColor(0, 0, 0, 0));
	drawRoundedBorder(driver, x, y, w, h, m_border_color);
	driver->draw2DRectangle(m_title_bg, core::rect<s32>(x + 4, y + 1, x + w - 4, y + panel.title_h));

	drawText(panel.title.empty() ? panel.id : panel.title,
		x + 5, y + (panel.title_h - m_fontsize.Y) / 2, m_font_color);

	s32 pin_x = x + w - 56;
	panel.hover_pin = pointInRect(mouse_pos.X, mouse_pos.Y, pin_x, y, 16, panel.title_h);
	driver->draw2DRectangle(panel.hover_pin ? video::SColor(200, 100, 100, 100) : video::SColor(180, 60, 60, 80),
		core::rect<s32>(pin_x, y, pin_x + 16, y + panel.title_h));
	drawText(panel.pinned ? "P" : "p", pin_x + 3, y + 4,
		panel.pinned ? video::SColor(255, 255, 200, 50) : m_font_color);

	s32 fw = 16;
	s32 fx = pin_x - fw;
	panel.hover_focus = pointInRect(mouse_pos.X, mouse_pos.Y, fx, y, fw, panel.title_h);
	driver->draw2DRectangle(panel.hover_focus ? video::SColor(200, 100, 100, 100) : video::SColor(180, 60, 60, 80),
		core::rect<s32>(fx, y, fx + fw, y + panel.title_h));
	drawText(panel.keyboard_focus ? "K" : "k", fx + 3, y + 4,
		panel.keyboard_focus ? video::SColor(255, 100, 255, 100) : m_font_color);

	s32 rsx = fx - 16;
	driver->draw2DRectangle(video::SColor(180, 60, 60, 80), core::rect<s32>(rsx, y, rsx + 16, y + panel.title_h));
	drawText("R", rsx + 3, y + 4, m_font_color);

	panel.hover_title = pointInRect(mouse_pos.X, mouse_pos.Y, x, y, w, panel.title_h);
}

void PanelOverlay::drawAll(video::IVideoDriver *driver, v2s32 mouse_pos, bool show_debug)
{
	m_screen_size = driver->getScreenSize();

	if (!m_categories_initialized) {
		initPanels();
		autoTilePanels(m_screen_size);
		m_categories_initialized = true;
	}

	for (auto &panel : m_panels) {
		s32 &x = panel.x, &y = panel.y;
		s32 w = panel.w;

		s32 h = panel.title_h + getPanelContentHeight(panel);
		panel.h = h;

		if (x + w > (s32)m_screen_size.X) x = m_screen_size.X - w;
		if (y + h > (s32)m_screen_size.Y) y = m_screen_size.Y - h;
		if (x < 0) x = 0;
		if (y < 0) y = 0;

		drawPanelChrome(driver, panel, mouse_pos);

		s32 iy = y + panel.title_h + m_gap;
		drawPanelContent(driver, panel, x, iy, w, h - panel.title_h - m_gap, mouse_pos);
	}
}

void PanelOverlay::drawPinned(video::IVideoDriver *driver, v2s32 mouse_pos)
{
	m_screen_size = driver->getScreenSize();
	for (auto &panel : m_panels) {
		if (panel.pinned) {
			panel.h = panel.title_h + getPanelContentHeight(panel);
			drawPanelChrome(driver, panel, mouse_pos);
			s32 iy = panel.y + panel.title_h + m_gap;
			drawPanelContent(driver, panel, panel.x, iy, panel.w,
				panel.h - panel.title_h - m_gap, mouse_pos);
		}
	}
}

void PanelOverlay::autoTilePanels(v2u32 screen_size)
{
	s32 margin = 10;

	for (auto &panel : m_panels)
		panel.h = panel.title_h + getPanelContentHeight(panel);

	std::vector<bool> placed(m_panels.size(), false);

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

	// Pass 1: Place pinned panels unconditionally at saved positions
	for (size_t i = 0; i < m_panels.size(); i++) {
		OverlayPanel saved;
		saved.id = m_panels[i].id;
		loadPanelPosition(saved);
		if (saved.pinned) {
			m_panels[i].x = saved.x;
			m_panels[i].y = saved.y;
			m_panels[i].pinned = true;
			m_panels[i].detached = true;
			placed[i] = true;
		}
	}

	// Pass 2: Place unpinned panels using edge-snapping packer
	for (size_t i = 0; i < m_panels.size(); i++) {
		if (placed[i])
			continue;

		s32 px = margin, py = 60;
		bool found = false;

		// Try saved position first (only if no overlap)
		OverlayPanel saved;
		saved.id = m_panels[i].id;
		loadPanelPosition(saved);
		if ((saved.x != 0 || saved.y != 0) && !overlaps(i, saved.x, saved.y)) {
			px = saved.x;
			py = saved.y;
			found = true;
		}

		// Edge-snapping pack: scan candidate positions derived from placed panel edges
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
				std::vector<s32> xs = {margin};
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

bool PanelOverlay::overlapsAny(int idx, s32 tx, s32 ty)
{
	s32 tw = m_panels[idx].w;
	s32 th = m_panels[idx].h;
	for (size_t i = 0; i < m_panels.size(); i++) {
		if ((s32)i == idx) continue;
		auto &p = m_panels[i];
		if (tx + tw > p.x && tx < p.x + p.w && ty + th > p.y && ty < p.y + p.h)
			return true;
	}
	return false;
}

void PanelOverlay::snapPanel(int idx)
{
	auto &panel = m_panels[idx];
	s32 ox = panel.x, oy = panel.y;
	s32 pw = panel.w, ph = panel.h;
	auto &ss = m_screen_size;
	s32 margin = 10;

	if (!overlapsAny(idx, ox, oy))
		return;

	const s32 step = 5;
	s32 x = ox, y = oy;
	for (s32 radius = step; radius < (s32)std::max(ss.X, ss.Y); radius += step) {
		x = ox + radius;
		y = oy;
		if (x + pw < (s32)ss.X - margin && !overlapsAny(idx, x, y)) {
			panel.x = x; panel.y = y; panel.detached = true; return;
		}
		x = ox;
		y = oy + radius;
		if (y + ph < (s32)ss.Y - margin && !overlapsAny(idx, x, y)) {
			panel.x = x; panel.y = y; panel.detached = true; return;
		}
		x = ox - radius;
		y = oy;
		if (x >= margin && !overlapsAny(idx, x, y)) {
			panel.x = x; panel.y = y; panel.detached = true; return;
		}
		x = ox;
		y = oy - radius;
		if (y >= 60 && !overlapsAny(idx, x, y)) {
			panel.x = x; panel.y = y; panel.detached = true; return;
		}
	}

	panel.x = 10 + idx * 30;
	panel.y = 60 + idx * 30;
	panel.detached = true;
}

void PanelOverlay::handleMouse(v2s32 pos, bool left_down)
{
	bool was = m_mouse_left_prev;
	bool clicked = !was && left_down;
	bool released = was && !left_down;
	m_mouse_left_prev = left_down;
	m_prev_mouse_x = pos.X;
	m_prev_mouse_y = pos.Y;

	if (m_drag_panel >= 0 && (size_t)m_drag_panel < m_panels.size()) {
		if (left_down) {
			m_panels[m_drag_panel].x = pos.X - m_drag_off_x;
			m_panels[m_drag_panel].y = pos.Y - m_drag_off_y;
		}
		if (released) {
			snapPanel(m_drag_panel);
			m_drag_panel = -1;
			savePanelPositions();
		}
		return;
	}

	if (!clicked)
		return;

	for (size_t pi = 0; pi < m_panels.size(); pi++) {
		auto &panel = m_panels[pi];
		s32 x = panel.x, y = panel.y, w = panel.w, h = panel.h;

		if (!pointInRect(pos.X, pos.Y, x, y, w, h))
			continue;

		if (pointInRect(pos.X, pos.Y, x, y, w, panel.title_h)) {
			s32 pin_x = x + w - 56;
			if (pointInRect(pos.X, pos.Y, pin_x, y, 16, panel.title_h)) {
				panel.pinned = !panel.pinned;
				savePanelPositions();
				return;
			}
			s32 fx = pin_x - 16;
			if (pointInRect(pos.X, pos.Y, fx, y, 16, panel.title_h)) {
				for (auto &p : m_panels) p.keyboard_focus = false;
				panel.keyboard_focus = true;
				return;
			}
			s32 rsx = fx - 16;
			if (pointInRect(pos.X, pos.Y, rsx, y, 16, panel.title_h)) {
				panel.x = 10 + (s32)pi * 30;
				panel.y = 60 + (s32)pi * 30;
				savePanelPositions();
				return;
			}
			panel.detached = true;
			m_drag_panel = (s32)pi;
			m_drag_off_x = pos.X - panel.x;
			m_drag_off_y = pos.Y - panel.y;
			return;
		}

		s32 iy = y + panel.title_h + m_gap;
		if (pointInRect(pos.X, pos.Y, x, iy, w, panel.h - panel.title_h - m_gap)) {
			handlePanelContentClick(pi, pos, x, iy, w);
			return;
		}
	}
}

void PanelOverlay::handlePanelContentClick(size_t panel_idx, v2s32 pos, s32 cx, s32 cy, s32 cw)
{
	// Default: no content click handling
}

void PanelOverlay::onLayerClosed()
{
	m_drag_panel = -1;
	m_categories_initialized = false;
	savePanelPositions();
	for (s32 i = (s32)m_panels.size() - 1; i >= 0; i--)
		if (!m_panels[i].pinned)
			m_panels.erase(m_panels.begin() + i);
}

void PanelOverlay::loadPanelPosition(OverlayPanel &panel)
{
	std::string key = "panel_pos_" + panel.id;
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

void PanelOverlay::savePanelPositions()
{
	for (auto &panel : m_panels) {
		std::string key = "panel_pos_" + panel.id;
		std::string val = std::to_string(panel.x) + "," + std::to_string(panel.y);
		if (panel.pinned) val += ",pinned";
		g_settings->set(key, val);
	}
}
