// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "client/al_reconnect.h"
#include "client/client.h"
#include "network/address.h"
#include "settings.h"
#include "gettext.h"
#include "util/string.h"
#include "client/al_hooks.h"

#include <IGUIEnvironment.h>
#include <IVideoDriver.h>
#include <IGUIFont.h>
#include <ICursorControl.h>

ReconnectManager::ReconnectManager() = default;

bool ReconnectManager::onDisconnected(Client *client, bool is_singleplayer)
{
	auto origin = client->getDisconnectOrigin();
	m_reason = client->accessDeniedReason();

	// Check setting
	if (!g_settings->getBool("auto_reconnect"))
		return false;

	// Never reconnect in singleplayer
	if (is_singleplayer)
		return false;

	// Don't reconnect on access denied unless server explicitly asked
	if (origin == DisconnectOrigin::AccessDenied && !client->reconnectRequested())
		return false;

	// Fire Lua on_disconnected — if it returns true, cancel auto-reconnect
	bool cancel = AlClientHooks::on_disconnected(client, m_reason);
	if (cancel)
		return false;

	// Start reconnection
	m_state = State::Waiting;
	m_backoff = std::max(1.0f,
			g_settings->getFloat("auto_reconnect_delay"));
	m_timer = m_backoff;
	m_attempt = 0;
	return true;
}

void ReconnectManager::onConnected()
{
	m_state = State::Connected;
}

void ReconnectManager::tick(float dtime, Client *client,
		const Address &address, const std::string &address_name)
{
	if (m_state != State::Waiting && m_state != State::Connecting)
		return;

	if (m_state == State::Connecting) {
		// Check if reconnection succeeded
		if (client->getState() == LC_Ready && !client->accessDenied()) {
			m_state = State::Idle;
			m_attempt = 0;
			m_backoff = std::max(1.0f,
					g_settings->getFloat("auto_reconnect_delay"));
			AlClientHooks::on_connect(client);
		}
		return;
	}

	// Waiting — count down backoff timer
	m_timer -= dtime;
	if (m_timer > 0.0f)
		return;

	// Timer expired — attempt reconnection
	m_attempt++;
	float max_backoff = g_settings->getFloat("auto_reconnect_max_backoff");
	m_backoff = std::min(m_backoff * 2.0f, max_backoff);
	m_timer = m_backoff;

	client->resetForReconnect();
	client->connect(address, address_name);
	m_state = State::Connecting;
}

void ReconnectManager::cancel()
{
	if (m_state != State::Idle)
		m_state = State::Cancelled;
}

void ReconnectManager::drawOverlay(video::IVideoDriver *driver,
		gui::IGUIEnvironment *guienv)
{
	if (m_state != State::Waiting && m_state != State::Connecting)
		return;

	auto *font = guienv->getBuiltInFont();
	if (!font)
		return;

	auto screen = driver->getViewPort();
	auto center = core::rect<s32>(0, 0, screen.getWidth(), screen.getHeight());

	// Dark semi-transparent overlay
	driver->draw2DRectangle(video::SColor(160, 0, 0, 0), center);

	// "Connection lost" title
	std::wstring title = wstrgettext("Connection lost");
	auto title_dim = font->getDimension(title.c_str());
	core::position2d<s32> title_pos(
		(screen.getWidth() - title_dim.Width) / 2,
		screen.getHeight() / 2 - 60);
	font->draw(title.c_str(), core::rect<s32>(title_pos, title_dim),
		video::SColor(255, 255, 200, 100));

	// Reconnecting status
	char buf[128];
	if (m_state == State::Waiting) {
		snprintf(buf, sizeof(buf), "%s %.0fs... (%s %d)",
				gettext("Reconnecting in"),
				m_timer,
				gettext("attempt"),
				m_attempt + 1);
	} else {
		snprintf(buf, sizeof(buf), "%s... (%s %d)",
				gettext("Reconnecting"),
				gettext("attempt"),
				m_attempt);
	}
	std::wstring sub = utf8_to_wide(buf);
	auto sub_dim = font->getDimension(sub.c_str());
	core::position2d<s32> sub_pos(
		(screen.getWidth() - sub_dim.Width) / 2,
		screen.getHeight() / 2 - 20);
	font->draw(sub.c_str(), core::rect<s32>(sub_pos, sub_dim),
		video::SColor(255, 255, 255, 255));

	// Cancel hint
	std::wstring hint = wstrgettext("Press Esc to cancel");
	auto hint_dim = font->getDimension(hint.c_str());
	core::position2d<s32> hint_pos(
		(screen.getWidth() - hint_dim.Width) / 2,
		screen.getHeight() / 2 + 20);
	font->draw(hint.c_str(), core::rect<s32>(hint_pos, hint_dim),
		video::SColor(200, 180, 180, 180));
}
