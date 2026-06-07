// DragonfireClient
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "df_hooks.h"
#include "client.h"
#include "client/localplayer.h"
#include "script/scripting_client.h"
#include "script/cpp_api/df/df_callbacks.h"
#include "particles.h"
#include "sound_spec.h"
#include "hud.h"
#include "lighting.h"

namespace DfClientHooks {

// ---------------------------------------------------------------------------
// Phase 1a helpers
// ---------------------------------------------------------------------------

void on_movement(Client *client, LocalPlayer *player)
{
	if (client->modsLoaded())
		client->getScript()->on_recieve_physics_override(player);
}

void on_play_sound(Client *client, const SoundSpec &spec,
		SoundLocation type, v3f pos, u16 object_id,
		bool ephemeral, s32 server_id)
{
	if (client->modsLoaded())
		client->getScript()->on_play_sound(spec, type, pos,
				object_id, ephemeral, server_id);
}

void on_spawn_particle(Client *client, const ParticleParameters &p)
{
	if (client->modsLoaded())
		client->getScript()->on_spawn_particle(p);
}

void on_receive_particlespawner(Client *client,
		const ParticleSpawnerParameters &p,
		u32 server_id, u16 attached_id)
{
	if (client->modsLoaded())
		client->getScript()->on_receive_particlespawner(
				p, server_id, attached_id);
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

void on_receiving_inventory_form(Client *client,
		const std::string &formspec)
{
	if (client->modsLoaded())
		client->getScript()->on_receiving_inventory_form(formspec);
}

void on_open_nodemeta_form(Client *client, v3s16 pos,
		const std::string &formspec)
{
	if (client->modsLoaded())
		client->getScript()->on_open_nodemeta_form(pos, formspec);
}

// ---------------------------------------------------------------------------
// Phase 1b: Moved from ScriptApiClient
// ---------------------------------------------------------------------------

void on_death(Client *client)
{
	if (client->modsLoaded())
		client->getScript()->on_death();
}

void on_active_object_add_remove(Client *client)
{
	if (client->modsLoaded()) {
		// Note: individual object add/remove IDs need to be tracked
		// This is called from the handler; the individual calls happen
		// directly from the packet handler code.
	}
}

void on_hp_change(Client *client, u16 hp)
{
	if (client->modsLoaded())
		client->getScript()->on_hp_modification(hp);
}

// ---------------------------------------------------------------------------
// Phase 2: New interception callbacks
// ---------------------------------------------------------------------------

void on_receiving_formspec(Client *client,
		const std::string &formname, const std::string &formspec)
{
	if (client->modsLoaded())
		client->getScript()->on_receiving_formspec(formname, formspec);
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

void on_hud_add(Client *client, u32 server_id, u8 type,
		const v2f &pos, const std::string &name,
		const v2f &scale, const std::string &text,
		u32 number, u32 item, u32 dir, const v2f &align,
		const v2f &offset, const v3f &world_pos,
		const v2f &size, s16 z_index, const std::string &text2,
		u32 style, bool hideable)
{
	if (client->modsLoaded())
		client->getScript()->on_hud_add(server_id, type, pos, name,
				scale, text, number, item, dir, align, offset,
				world_pos, size, z_index, text2, style, hideable);
}

void on_hud_remove(Client *client, u32 server_id)
{
	if (client->modsLoaded())
		client->getScript()->on_hud_remove(server_id);
}

void on_hud_change(Client *client, u32 server_id,
		HudElementStat stat, const std::string &sdata,
		const v2f &v2fdata, const v3f &v3fdata, u32 intdata)
{
	if (client->modsLoaded())
		client->getScript()->on_hud_change(server_id, stat,
				sdata, v2fdata, v3fdata, intdata);
}

void on_time_of_day(Client *client, u16 time, float speed)
{
	if (client->modsLoaded())
		client->getScript()->on_time_of_day(time, speed);
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

} // namespace DfClientHooks
