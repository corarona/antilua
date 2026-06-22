// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "irrlichttypes.h"
#include <IGUIFont.h>
#include <string>
#include <vector>

namespace video
{
class IVideoDriver;
}

enum class ToastType
{
	INFO,
	SUCCESS,
	WARNING,
	ERR
};

struct Toast
{
	std::wstring text;
	ToastType type;
	float elapsed = 0.0f;
};

class ToastManager
{
public:
	ToastManager();
	~ToastManager() = default;

	void addToast(const std::wstring &text, ToastType type);
	void update(float dtime);
	void draw(video::IVideoDriver *driver);

	void setOrigin(s32 x, s32 y);
	void setMaxToasts(int n);
	void clear();

	bool hasToasts() const { return !m_toasts.empty(); }

	static ToastType stringToType(const std::string &s);

private:
	video::SColor getBackgroundColor(ToastType type) const;
	video::SColor getTextColor(ToastType type) const;

	std::vector<Toast> m_toasts;
	gui::IGUIFont *m_font = nullptr;
	s32 m_origin_x = -1;  // -1 means right-aligned (10px from right edge)
	s32 m_origin_y = 10;
	int m_max_toasts = 5;
	s32 m_toast_width = 380;
	s32 m_toast_height = 28;
	s32 m_padding = 6;
	float m_duration = 3.0f;
	float m_fade_start = 2.0f;
};
