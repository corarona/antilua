// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "gui/toastManager.h"
#include "client/fontengine.h"
#include "irr_v2d.h"
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

void ToastManager::draw(video::IVideoDriver *driver)
{
	if (m_toasts.empty())
		return;

	if (m_toasts.empty())
		return;

	v2u32 screen = driver->getScreenSize();

	// Compute origin X: right-aligned if -1 (10px from right edge)
	s32 origin_x = m_origin_x;
	if (origin_x < 0)
		origin_x = (s32)screen.X - m_toast_width - 10;

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
