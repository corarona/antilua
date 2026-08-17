// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "layerManager.h"

#include "client/al_bigmap.h"
#include "client/client.h"
#include "client/renderingengine.h"
#include "gui/cheatMenu.h"
#include "lualib.h"
#include "script/scripting_client.h"

#include <IVideoDriver.h>
#include <algorithm>

LayerManager *g_layer_manager = nullptr;

void LayerManager::registerLayer(AlLayer layer)
{
	auto it = std::find_if(m_layers.begin(), m_layers.end(),
			[&](const AlLayer &l) { return l.id == layer.id; });
	if (it != m_layers.end())
		*it = std::move(layer);
	else
		m_layers.emplace_back(std::move(layer));
}

void LayerManager::unregisterLayer(const std::string &id)
{
	m_layers.erase(std::remove_if(m_layers.begin(), m_layers.end(),
			[&](const AlLayer &l) { return l.id == id; }), m_layers.end());
}

AlLayer *LayerManager::getLayer(const std::string &id)
{
	auto it = std::find_if(m_layers.begin(), m_layers.end(),
			[&](const AlLayer &l) { return l.id == id; });
	return it != m_layers.end() ? &*it : nullptr;
}

const AlLayer *LayerManager::getLayer(const std::string &id) const
{
	auto it = std::find_if(m_layers.begin(), m_layers.end(),
			[&](const AlLayer &l) { return l.id == id; });
	return it != m_layers.end() ? &*it : nullptr;
}

void LayerManager::setVisible(const std::string &id, bool visible)
{
	if (AlLayer *l = getLayer(id))
		l->m_visible = visible;
}

bool LayerManager::isVisible(const std::string &id) const
{
	const AlLayer *l = getLayer(id);
	return l && l->isVisible();
}

bool LayerManager::anyLayerCapturesChars() const
{
	for (const auto &l : m_layers)
		if (l.isVisible() && l.captures_chars)
			return true;
	return false;
}

bool LayerManager::anyLayerVisible() const
{
	for (const auto &l : m_layers)
		if (l.isVisible())
			return true;
	return false;
}

bool LayerManager::handleEsc()
{
	// Walk from the top of the stack down. The first visible layer decides:
	// an esc_closes layer is closed (consuming the event), any other visible
	// layer blocks the layers below it.
	for (auto it = m_layers.rbegin(); it != m_layers.rend(); ++it) {
		if (!it->isVisible())
			continue;
		if (!it->esc_closes)
			return false;
		if (it->close_fn)
			it->close_fn();
		if (!it->visible_check)
			it->m_visible = false;
		return true;
	}
	return false;
}

bool LayerManager::handleKeyPress(const KeyPress &key, bool pressed)
{
	bool handled = false;
	for (auto &l : m_layers) {
		if (l.key_name.empty())
			continue;
		KeyPress kp = KeyPress(l.key_name);
		if (!kp || !(kp == key))
			continue;
		l.m_key_was_down = pressed;
		if (pressed) {
			setVisible(l.id, !l.isVisible());
			handled = true;
		}
	}
	return handled;
}

void LayerManager::drawAboveGUI(video::IVideoDriver *driver, v2u32 target_size)
{
	const video::SColor scrim(178, 0, 0, 0);
	for (auto &l : m_layers) {
		if (!l.isVisible())
			continue;
		if (l.opaque)
			driver->draw2DRectangle(scrim,
				core::rect<s32>(0, 0, target_size.X, target_size.Y));
		if (l.draw_above_gui)
			l.draw_above_gui(driver, target_size);
		// Lua-registered layers draw via their on_draw callback + the draw
		// queue (core.draw_rect/text/texture).
		if (l.on_draw != 0 && m_client) {
			lua_State *L = m_client->getScript() ?
					m_client->getScript()->getLuaState() : nullptr;
			if (L) {
				int base = lua_gettop(L);
				if (g_cheat_menu)
					g_cheat_menu->m_draw_queue.clear();
				lua_rawgeti(L, LUA_REGISTRYINDEX, l.on_draw);
				if (lua_pcall(L, 0, 0, 0) != 0) {
					const char *err = lua_tostring(L, -1);
					warningstream << "layer on_draw error: "
							<< (err ? err : "(unknown)") << std::endl;
					lua_settop(L, base);
					continue;
				}
				lua_settop(L, base);
				if (g_cheat_menu)
					g_cheat_menu->flushDrawQueue(driver, target_size);
			}
		}
	}
}

// Registers the built-in layers. The draw hooks reproduce the previous
// hardcoded DrawGUI logic exactly (behavior-preserving migration).
void setupDefaultLayers()
{
	// Cheat layer: dark scrim + search bar + panels + pinned panels.
	AlLayer cheat;
	cheat.id = "cheat";
	cheat.title = "Cheats";
	cheat.type = AlLayer::Type::CONTAINER;
	cheat.captures_chars = true;
	cheat.visible_check = []() { return g_cheat_layer_active; };
	cheat.draw_above_gui = [](video::IVideoDriver *driver, v2u32) {
		if (!g_cheat_menu)
			return;
		v2s32 mouse_pos;
		if (auto *device = RenderingEngine::get_raw_device())
			if (auto *cur = device->getCursorControl())
				mouse_pos = cur->getPosition();
		if (g_cheat_layer_active) {
			auto ss = driver->getScreenSize();
			if (g_settings->getBool("cheat_menu_opaque"))
				driver->draw2DRectangle(video::SColor(178, 0, 0, 0),
					core::rect<s32>(0, 0, ss.Width, ss.Height));
			if (g_cheat_menu->needsSearchBar())
				g_cheat_menu->drawSearchBar(driver);
			g_cheat_menu->drawAll(driver, mouse_pos, g_show_minimal_debug);
		}
		g_cheat_menu->drawPinned(driver, mouse_pos);
	};
	g_layer_manager->registerLayer(cheat);

	// Quick palette: centered search overlay.
	AlLayer palette;
	palette.id = "quick_palette";
	palette.title = "Quick Access";
	palette.type = AlLayer::Type::FULLSCREEN;
	palette.captures_chars = true;
	palette.visible_check = []() { return g_quick_palette_active; };
	palette.draw_above_gui = [](video::IVideoDriver *driver, v2u32) {
		if (!g_cheat_menu || !g_quick_palette_active)
			return;
		v2s32 mouse_pos;
		if (auto *device = RenderingEngine::get_raw_device())
			if (auto *cur = device->getCursorControl())
				mouse_pos = cur->getPosition();
		g_cheat_menu->drawQuickPalette(driver, mouse_pos);
	};
	g_layer_manager->registerLayer(palette);

	// Big map: fullscreen overlay rendered by its own pipeline step below the
	// GUI. Only visibility + ESC handling are managed here.
	AlLayer bigmap;
	bigmap.id = "bigmap";
	bigmap.title = "Map";
	bigmap.type = AlLayer::Type::FULLSCREEN;
	bigmap.esc_closes = true;
	bigmap.visible_check = []() { return AlBigMap::getActive() != nullptr; };
	bigmap.close_fn = []() { AlBigMap::closeActive(); };
	g_layer_manager->registerLayer(bigmap);
}