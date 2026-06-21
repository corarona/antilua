// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "al_hooks.h"
#include "client.h"
#include "client/localplayer.h"
#include "script/scripting_client.h"
#include "script/cpp_api/al/al_callbacks.h"
#include "particles.h"
#include "sound_spec.h"
#include "hud.h"
#include "lighting.h"

namespace AlClientHooks {

// ---------------------------------------------------------------------------
// Phase 1a helpers
// ---------------------------------------------------------------------------

void on_movement(Client *client, LocalPlayer *player)
{
	if (client->modsLoaded())
		client->getScript()->on_receive_physics_override(player);
}

bool on_play_sound(Client *client, const SoundSpec &spec,
		SoundLocation type, v3f pos, u16 object_id,
		bool ephemeral, s32 server_id)
{
	if (client->modsLoaded())
		return client->getScript()->on_play_sound(spec, type, pos,
				object_id, ephemeral, server_id);
	return false;
}

bool on_spawn_particle(Client *client, const ParticleParameters &p)
{
	if (client->modsLoaded())
		return client->getScript()->on_spawn_particle(p);
	return false;
}

bool on_receive_particlespawner(Client *client,
		const ParticleSpawnerParameters &p,
		u32 server_id, u16 attached_id)
{
	if (client->modsLoaded())
		return client->getScript()->on_receive_particlespawner(
				p, server_id, attached_id);
	return false;
}

void on_sending_inventory_fields(Client *client,
		const std::string &formname, const StringMap &fields)
{
	if (client->modsLoaded())
		client->getScript()->on_sending_inventory_fields(
				formname, fields);
}

void on_sending_nodemeta_fields(Client *client,
		const std::string &formname, const StringMap &fields)
{
	if (client->modsLoaded())
		client->getScript()->on_sending_nodemeta_fields(
				formname, fields);
}

void on_detached_inventory_update(Client *client,
		const std::string &name, bool keep)
{
	if (client->modsLoaded())
		client->getScript()->on_detached_inventory_update(name, keep);
}

std::string on_receiving_inventory_form(Client *client,
		const std::string &formspec)
{
	if (client->modsLoaded())
		return client->getScript()->on_receiving_inventory_form(formspec);
	return "";
}

bool on_open_nodemeta_form(Client *client, v3s16 pos,
		const std::string &formspec)
{
	if (client->modsLoaded())
		return client->getScript()->on_open_nodemeta_form(pos, formspec);
	return false;
}

// ---------------------------------------------------------------------------
// Phase 1b: Moved from ScriptApiClient
// ---------------------------------------------------------------------------

bool on_delete_particlespawner(Client *client, u32 server_id)
{
	if (client->modsLoaded())
		return client->getScript()->on_delete_particlespawner(server_id);
	return false;
}

void on_death(Client *client)
{
	if (client->modsLoaded())
		client->getScript()->on_death();
}


bool on_stop_sound(Client *client, s32 server_id)
{
	if (client->modsLoaded())
		return client->getScript()->on_stop_sound(server_id);
	return false;
}

bool on_fade_sound(Client *client, s32 sound_id, float step, float gain)
{
	if (client->modsLoaded())
		return client->getScript()->on_fade_sound(sound_id, step, gain);
	return false;
}

bool on_object_add(Client *client, u16 id)
{
	if (client->modsLoaded())
		return client->getScript()->on_object_add(id);
	return false;
}

void on_object_hp_change(Client *client, u16 id, u16 hp)
{
	if (client->modsLoaded())
		client->getScript()->on_object_hp_change(id, hp);
}

void on_object_properties_change(Client *client, u16 id)
{
	if (client->modsLoaded())
		client->getScript()->on_object_properties_change(id);
}

void on_hp_change(Client *client, u16 hp)
{
	if (client->modsLoaded())
		client->getScript()->on_hp_modification(hp);
}

// ---------------------------------------------------------------------------
// Phase 2: New interception callbacks
// ---------------------------------------------------------------------------

std::string on_receiving_formspec(Client *client,
		const std::string &formname, const std::string &formspec)
{
	if (client->modsLoaded())
		return client->getScript()->on_receiving_formspec(formname, formspec);
	return "";
}

void on_node_add(Client *client, v3s16 pos, const MapNode &node)
{
	if (client->modsLoaded())
		client->getScript()->on_node_add(pos, node);
}

void on_node_remove(Client *client, v3s16 pos)
{
	if (client->modsLoaded())
		client->getScript()->on_node_remove(pos);
}

bool on_hud_add(Client *client, u32 server_id, u8 type,
		const v2f &pos, const std::string &name,
		const v2f &scale, const std::string &text,
		u32 number, u32 item, u32 dir, const v2f &align,
		const v2f &offset, const v3f &world_pos,
		const v2f &size, s16 z_index, const std::string &text2,
		u32 style, bool hideable)
{
	if (client->modsLoaded())
		return client->getScript()->on_hud_add(server_id, type, pos, name,
				scale, text, number, item, dir, align, offset,
				world_pos, size, z_index, text2, style, hideable);
	return false;
}

bool on_hud_remove(Client *client, u32 server_id)
{
	if (client->modsLoaded())
		return client->getScript()->on_hud_remove(server_id);
	return false;
}

bool on_hud_change(Client *client, u32 server_id,
		HudElementStat stat, const std::string &sdata,
		const v2f &v2fdata, const v3f &v3fdata, u32 intdata)
{
	if (client->modsLoaded())
		return client->getScript()->on_hud_change(server_id, stat,
				sdata, v2fdata, v3fdata, intdata);
	return false;
}

float on_time_of_day(Client *client, u16 time, float speed)
{
	if (client->modsLoaded())
		return client->getScript()->on_time_of_day(time, speed);
	return -1.0f;
}

// ---------------------------------------------------------------------------
// Phase 3: New notification callbacks
// ---------------------------------------------------------------------------

void on_connect(Client *client)
{
	if (client->modsLoaded())
		client->getScript()->on_connect();
}

void on_disconnect(Client *client)
{
	if (client->modsLoaded())
		client->getScript()->on_disconnect();
}

void on_privileges(Client *client,
		const std::set<std::string> &privileges)
{
	if (client->modsLoaded())
		client->getScript()->on_privileges_changed(privileges);
}

void on_breath(Client *client, u16 breath)
{
	if (client->modsLoaded())
		client->getScript()->on_breath_changed(breath);
}

void on_player_list(Client *client, u8 type,
		const std::vector<std::string> &names)
{
	if (client->modsLoaded())
		client->getScript()->on_player_list_changed(type, names);
}

void on_lighting(Client *client, const Lighting &lighting)
{
	if (client->modsLoaded())
		client->getScript()->on_lighting_changed(lighting);
}

// ---------------------------------------------------------------------------
// Phase 4: Game loop hooks
// ---------------------------------------------------------------------------

void on_pre_step(Client *client, float dtime)
{
	if (client->modsLoaded())
		client->getScript()->on_pre_step(dtime);
}

void on_post_step(Client *client, float dtime)
{
	if (client->modsLoaded())
		client->getScript()->on_post_step(dtime);
}

// ---------------------------------------------------------------------------
// Phase 5: Raw packet callbacks
// ---------------------------------------------------------------------------

RawPacketHookResult on_raw_packet_received(Client *client, u16 command,
		const std::string &payload)
{
	if (client->modsLoaded())
		return client->getScript()->on_raw_packet_received(command, payload);
	return {false, {}};
}

RawPacketHookResult on_raw_packet_sending(Client *client, u16 command,
		const std::string &payload)
{
	if (client->modsLoaded())
		return client->getScript()->on_raw_packet_sending(command, payload);
	return {false, {}};
}

} // namespace AlClientHooks
