// Antilua — ChatPlus settings reader
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "al_chatplus.h"
#include "settings.h"
#include "util/string.h"
#include <algorithm>

namespace ChatPlus {

HudStyle readHudStyle()
{
	HudStyle style;

	style.enabled = g_settings->getBool("chatplus.enabled");

	g_settings->getS32NoEx("chatplus_offset_x", style.offset_x);
	g_settings->getS32NoEx("chatplus_offset_y", style.offset_y);

	style.background = g_settings->getBool("chatplus_background");
	style.border = g_settings->getBool("chatplus_border");

	s32 alpha = 180;
	g_settings->getS32NoEx("chatplus_background_alpha", alpha);
	alpha = std::clamp(alpha, 0, 255);

	video::SColor bg(alpha, 0, 0, 0);
	if (g_settings->exists("chatplus_background_color"))
		parseColorString(g_settings->get("chatplus_background_color"), bg, true, alpha);
	style.background_color = bg;

	s32 border_alpha = 255;
	g_settings->getS32NoEx("chatplus_border_alpha", border_alpha);
	border_alpha = std::clamp(border_alpha, 0, 255);

	video::SColor border_col(255, 120, 120, 255);
	if (g_settings->exists("chatplus_border_color"))
		parseColorString(g_settings->get("chatplus_border_color"), border_col, true, border_alpha);
	style.border_color = border_col;

	s32 pad = 4;
	g_settings->getS32NoEx("chatplus_padding", pad);
	style.padding = std::max<s32>(0, pad);

	return style;
}

} // namespace ChatPlus
