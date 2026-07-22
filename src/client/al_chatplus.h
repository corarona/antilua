// Antilua — ChatPlus: configurable chat HUD styling
// Adapted from Lunarchy's chatplus.h
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <SColor.h>
#include "irr_v2d.h"
#include "irrlichttypes.h"

namespace ChatPlus {

struct HudStyle {
	bool enabled = true;
	s32 offset_x = 0;
	s32 offset_y = 0;
	bool background = true;
	video::SColor background_color = video::SColor(180, 0, 0, 0);
	bool border = false;
	video::SColor border_color = video::SColor(255, 120, 120, 255);
	s32 padding = 4;
};

HudStyle readHudStyle();

} // namespace ChatPlus
