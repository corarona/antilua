// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <functional>
#include <string>
#include <vector>

#include "client/keycode.h"
#include "irr_v2d.h"

class Client;

namespace video {
	class IVideoDriver;
}

// One registered UI layer. A layer is a named, z-ordered UI mode that can be
// shown and hidden independently. Two kinds exist:
//   * CONTAINER — hosts content with its own sub-state (e.g. the cheat menu
//     with its desktops/tabs).
//   * FULLSCREEN — a single fullscreen view (e.g. the big map).
//
// The layer manager unifies the previously ad-hoc UI modes (cheat layer, quick
// palette, big map) so they can share z-ordering, ESC/char input handling and
// a single draw dispatch point. Layers are registered bottom-to-top.
struct AlLayer {
	enum class Type { CONTAINER, FULLSCREEN };

	std::string id;
	std::string title;
	Type type = Type::FULLSCREEN;
	// Manager draws a generic dark scrim over the world when the layer is
	// visible (in addition to any layer-specific drawing).
	bool opaque = false;
	// ESC closes this layer before the pause menu opens — but only when it is
	// the topmost visible layer (a higher visible layer blocks it).
	bool esc_closes = false;
	// A visible layer can claim ESC priority over all lower layers when this
	// predicate returns true (used by the cheat layer on the Map desktop: the
	// big map belongs to the desktop, so ESC should close the cheat layer
	// rather than just the map underneath).
	std::function<bool()> esc_steal;
	// The layer captures typed characters while visible (cheat search bar,
	// quick palette).
	bool captures_chars = false;
	// Predicate for whether the layer is currently visible. When null, the
	// manager-controlled m_visible flag is used instead. Predicates mirror
	// legacy globals until call sites are migrated to setVisible().
	std::function<bool()> visible_check;
	bool m_visible = false;
	// Optional close action (e.g. AlBigMap::closeActive()).
	std::function<void()> close_fn;
	// 2D drawing hook, invoked from the DrawGUI pipeline step.
	std::function<void(video::IVideoDriver *, v2u32)> draw_above_gui;
	// Optional toggle key (KeyPress-compatible name, e.g. "KEY_KEY_X" or
	// "SYSTEM_SCANCODE_45"). Pressing it toggles the layer's visibility.
	std::string key_name;
	bool m_key_was_down = false;
	// Lua callbacks (registry refs) for Lua-registered layers. on_draw is
	// invoked while the layer draws (may use core.draw_rect/text/texture);
	// on_input receives an event table and may return true to consume it.
	int on_draw = 0;
	int on_input = 0;

	bool isVisible() const
	{
		return visible_check ? visible_check() : m_visible;
	}
};

class LayerManager
{
public:
	LayerManager() = default;
	~LayerManager() = default;

	// The owning client (for invoking Lua layer callbacks). Set at startup.
	void setClient(class Client *client) { m_client = client; }
	Client *getClient() const { return m_client; }

	// Registry. Registering an existing id replaces the layer in place
	// (keeping its z-position).
	void registerLayer(AlLayer layer);
	void unregisterLayer(const std::string &id);
	AlLayer *getLayer(const std::string &id);
	const AlLayer *getLayer(const std::string &id) const;
	const std::vector<AlLayer> &getLayers() const { return m_layers; }

	// Visibility. Only affects manager-controlled layers (no visible_check);
	// predicate layers derive visibility from their predicate.
	void setVisible(const std::string &id, bool visible);
	bool isVisible(const std::string &id) const;

	// Convenience queries.
	bool isCheatLayerVisible() const { return isVisible("cheat"); }
	bool isQuickPaletteVisible() const { return isVisible("quick_palette"); }
	bool isBigmapVisible() const { return isVisible("bigmap"); }
	bool anyLayerCapturesChars() const;
	bool anyLayerVisible() const;

	// Input: ESC closes the topmost visible esc_closes layer, unless a higher
	// visible layer that isn't esc_closes blocks it. Returns true if the event
	// was consumed.
	bool handleEsc();

	// Input: dispatches a mouse click to the topmost visible layer with an
	// on_input callback (in z-order, top first). Each receives
	// {type="click", x, y}; returning true consumes the event (stops
	// dispatch to lower layers). Returns true if a layer consumed it.
	bool handleClick(v2s32 pos);

	// Input: toggles the visibility of any registered layer whose key_name
	// matches the given key (edge-triggered on press). Returns true if a layer
	// consumed the event.
	bool handleKeyPress(const KeyPress &key, bool pressed);

	// Drawing, called from the DrawGUI pipeline step. Draws every visible
	// layer in z-order (registration order).
	void drawAboveGUI(video::IVideoDriver *driver, v2u32 target_size);

private:
	std::vector<AlLayer> m_layers; // registration order = z-order (bottom to top)
	Client *m_client = nullptr;
};

// Registers the built-in layers (cheat layer, quick palette, big map) with
// their draw hooks and input behavior. Called once at game startup.
void setupDefaultLayers();

// Global layer manager, owned by Game (created in startup, deleted in the
// destructor). Null outside a running game.
extern LayerManager *g_layer_manager;