// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <string>
#include <memory>

class Client;
class Address;

namespace video { class IVideoDriver; }
namespace gui { class IGUIEnvironment; }

class ReconnectManager
{
public:
	ReconnectManager();

	// Returns true if we should enter reconnection mode
	bool onDisconnected(Client *client, bool is_singleplayer);

	// Called when reconnection succeeds
	void onConnected();

	// Called each frame. If dtime triggers a reconnect attempt, calls client->connect()
	void tick(float dtime, Client *client,
			const Address &address, const std::string &address_name);

	// User cancelled or game shutting down
	void cancel();

	bool isActive() const { return m_state != State::Idle; }
	bool wasCancelled() const { return m_state == State::Cancelled; }

	void drawOverlay(video::IVideoDriver *driver, gui::IGUIEnvironment *guienv);

private:
	enum class State { Idle, Waiting, Connecting, Connected, Cancelled };

	State m_state = State::Idle;
	float m_backoff = 1.0f;
	float m_timer = 0.0f;
	int m_attempt = 0;
	std::string m_reason;
};
