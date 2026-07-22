// Antilua — Cheat menu theme manager
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "al_theme.h"
#include <sstream>
#include <algorithm>
#include <map>
#include <cctype>

ThemeManager &ThemeManager::getInstance()
{
	static ThemeManager instance;
	return instance;
}

video::SColor ThemeManager::parseHex(const std::string &hex, u32 alpha)
{
	std::string h = hex;
	if (h.empty())
		return video::SColor(alpha, 0, 0, 0);
	if (h[0] == '#')
		h = h.substr(1);
	if (h.size() < 6)
		return video::SColor(alpha, 0, 0, 0);
	u32 val = std::stoul(h.substr(0, 6), nullptr, 16);
	return video::SColor(alpha, (val >> 16) & 0xFF,
		(val >> 8) & 0xFF, val & 0xFF);
}

CheatTheme ThemeManager::parseTheme(const std::string &data)
{
	CheatTheme t;
	std::istringstream stream(data);
	std::string line;

	std::map<std::string, video::SColor CheatTheme::*> colorMap = {
		{"bg",           &CheatTheme::bg},
		{"active_bg",    &CheatTheme::active_bg},
		{"text",         &CheatTheme::text},
		{"selected_text",&CheatTheme::selected_text},
		{"panel_bg",     &CheatTheme::panel_bg},
		{"title_bg",     &CheatTheme::title_bg},
		{"border",       &CheatTheme::border},
		{"item_bg",      &CheatTheme::item_bg},
		{"tooltip_bg",   &CheatTheme::tooltip_bg},
	};

	while (std::getline(stream, line)) {
		auto trim = [](const std::string &s) {
			size_t start = s.find_first_not_of(" \t\r\n");
			size_t end = s.find_last_not_of(" \t\r\n");
			return (start == std::string::npos || end == std::string::npos)
				? "" : s.substr(start, end - start + 1);
		};
		line = trim(line);
		if (line.empty() || line[0] == '#')
			continue;

		size_t eq = line.find('=');
		if (eq == std::string::npos)
			continue;

		std::string key = line.substr(0, eq);
		std::string value = line.substr(eq + 1);
		key = trim(key);
		value = trim(value);

		// Lowercase key
		for (auto &c : key)
			c = std::tolower(c);

		if (key == "name") {
			t.name = value;
		} else if (colorMap.count(key)) {
			t.*(colorMap[key]) = parseHex(value, 255);
		}
	}
	return t;
}

void ThemeManager::loadBuiltinThemes()
{
	m_themes.clear();

	static const char *builtin_themes[] = {
		// Modern — current Antilua default (dark blue-grey)
		R"TH(
name = Modern
bg = #1E1E2E
active_bg = #FF5733
text = #FFFFFF
selected_text = #FFFC58
panel_bg = #1E1E2D
title_bg = #32324B
border = #464664
item_bg = #37374B
tooltip_bg = #1E1E2D
)TH",
		// Matrix — green-on-black
		R"TH(
name = Matrix
bg = #000000
active_bg = #002800
text = #00FF00
selected_text = #00FF80
panel_bg = #000A00
title_bg = #001400
border = #00B400
item_bg = #000F00
tooltip_bg = #001400
)TH",
		// Legacy — Lunarchy's dark theme
		R"TH(
name = Legacy
bg = #0D0E1A
active_bg = #FF5633
text = #FFFFFF
selected_text = #FFFC58
panel_bg = #12131E
title_bg = #1A1C2E
border = #4A4B6A
item_bg = #1E2030
tooltip_bg = #12131E
)TH",
		// Midnight — Lunarchy's dark purple theme
		R"TH(
name = Midnight
bg = #08080E
active_bg = #AD1436
text = #E6E6E6
selected_text = #FFFC58
panel_bg = #0B0B14
title_bg = #141428
border = #20203F
item_bg = #141428
tooltip_bg = #0B0B14
)TH",
		// Moss — green-ish dark theme from Lunarchy
		R"TH(
name = Moss
bg = #121E12
active_bg = #2E8B2E
text = #E6E6E6
selected_text = #FFFC58
panel_bg = #141F14
title_bg = #1A2D1A
border = #334D33
item_bg = #1E2D1E
tooltip_bg = #141F14
)TH",
		// Ocean — blue light theme from Lunarchy
		R"TH(
name = Ocean
bg = #F0F8FF
active_bg = #1E90FF
text = #1A2A3A
selected_text = #1E90FF
panel_bg = #E6F0FA
title_bg = #B8D4E8
border = #8BB8D4
item_bg = #D0E4F0
tooltip_bg = #E6F0FA
)TH",
		// Outdoors — green light theme from Lunarchy
		R"TH(
name = Outdoors
bg = #E8ECE0
active_bg = #5A9E3E
text = #1A1E14
selected_text = #5A9E3E
panel_bg = #DEE3D4
title_bg = #B8C8A8
border = #B0C0A0
item_bg = #C8D4BC
tooltip_bg = #DEE3D4
)TH",
	};

	for (const char *data : builtin_themes) {
		CheatTheme t = parseTheme(data);
		if (!t.name.empty())
			m_themes.push_back(t);
	}
}

std::vector<std::string> ThemeManager::getThemeNames() const
{
	std::vector<std::string> names;
	for (const auto &t : m_themes)
		names.push_back(t.name);
	return names;
}

CheatTheme ThemeManager::getTheme(const std::string &name) const
{
	std::string target;
	for (auto c : name)
		target.push_back(std::tolower(c));

	for (const auto &t : m_themes) {
		std::string tn;
		for (auto c : t.name)
			tn.push_back(std::tolower(c));
		if (tn == target)
			return t;
	}

	CheatTheme fallback;
	fallback.name = "Fallback";
	fallback.bg = video::SColor(204, 30, 30, 45);
	fallback.active_bg = video::SColor(204, 255, 87, 53);
	fallback.text = video::SColor(255, 0, 0, 0);
	fallback.selected_text = video::SColor(255, 255, 252, 88);
	fallback.panel_bg = video::SColor(204, 30, 30, 45);
	fallback.title_bg = video::SColor(204, 50, 50, 75);
	fallback.border = video::SColor(204, 70, 70, 100);
	fallback.item_bg = video::SColor(204, 55, 55, 75);
	fallback.tooltip_bg = video::SColor(204, 30, 30, 45);
	return fallback;
}
