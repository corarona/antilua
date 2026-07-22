// Antilua — Cheat menu color theme system
// Adapted from Lunarchy's color_theme.h
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <string>
#include <vector>
#include <SColor.h>

struct CheatTheme {
	std::string name;

	video::SColor bg;
	video::SColor active_bg;
	video::SColor text;
	video::SColor selected_text;
	video::SColor panel_bg;
	video::SColor title_bg;
	video::SColor border;
	video::SColor item_bg;
	video::SColor tooltip_bg;
};

class ThemeManager {
public:
	static ThemeManager &getInstance();

	void loadBuiltinThemes();

	std::vector<std::string> getThemeNames() const;
	CheatTheme getTheme(const std::string &name) const;

private:
	ThemeManager() = default;

	static CheatTheme parseTheme(const std::string &data);
	static video::SColor parseHex(const std::string &hex, u32 alpha = 255);

	std::vector<CheatTheme> m_themes;
};
