// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "cpp_api/s_base.h"
#include "inventory.h"
#include "mapnode.h"
#include "network/networkpacket.h"
#include "client/al_hooks.h"
#include <string>
#include <vector>
#include <set>

class Client;
class LocalPlayer;
struct ParticleParameters;
struct ParticleSpawnerParameters;
struct SoundSpec;
struct HudElement;
struct Lighting;
enum class SoundLocation : u8;
enum HudElementStat : u8;

class AlScriptApi : virtual public ScriptApiBase
{
public:
	void setClient(Client *client) { m_client = client; }

	// Phase 1a: Wire dead callbacks
	void on_receive_physics_override(LocalPlayer *player);
	bool on_play_sound(const SoundSpec &spec, SoundLocation type,
			v3f pos, u16 object_id, bool ephemeral, s32 server_id);
	bool on_spawn_particle(const ParticleParameters &p);
	bool on_receive_particlespawner(
			const ParticleSpawnerParameters &p, u32 server_id,
			u16 attached_id);
	bool on_sending_inventory_fields(const std::string &formname,
			const StringMap &fields);
	bool on_sending_nodemeta_fields(const std::string &formname,
			const StringMap &fields);
	void on_detached_inventory_update(const std::string &name,
			bool keep);
	std::string on_receiving_inventory_form(
			const std::string &formspec);
	bool on_open_nodemeta_form(v3s16 pos,
			const std::string &formspec);

	// Phase 1b: Moved from ScriptApiClient
	void on_death();
	bool on_object_add(u16 id);
	void on_object_hp_change(u16 id, u16 hp);
	void on_object_properties_change(u16 id);

	// Phase 1c: Sound lifecycle
	bool on_stop_sound(s32 server_id);
	bool on_fade_sound(s32 sound_id, float step, float gain);

	// Phase 1d: Particle lifecycle
	bool on_delete_particlespawner(u32 server_id);

	// Phase 1e: Inventory notification
	void on_inventory_update();

	// Phase 1f: Nodemetadata notification
	void on_nodemetadata_change(const std::vector<v3s16> &positions);

	// Phase 1g: Sky and cloud notifications
	void on_sky_changed();
	void on_clouds_changed();

	// Phase 2: New interception callbacks
	std::string on_receiving_formspec(const std::string &formname,
			const std::string &formspec);
	void on_node_add(v3s16 pos, const MapNode &node);
	void on_node_remove(v3s16 pos);
	bool on_hud_add(u32 server_id, u8 type, const v2f &pos,
			const std::string &name, const v2f &scale,
			const std::string &text, u32 number, u32 item,
			u32 dir, const v2f &align, const v2f &offset,
			const v3f &world_pos, const v2f &size, s16 z_index,
			const std::string &text2, u32 style, bool hideable);
	bool on_hud_remove(u32 server_id);
	bool on_hud_change(u32 server_id, HudElementStat stat,
			const std::string &sdata, const v2f &v2fdata,
			const v3f &v3fdata, u32 intdata);
	float on_time_of_day(u16 time, float speed);

	// Phase 3: New notification callbacks
	void on_connect();
	void on_disconnect();
	void on_privileges_changed(
			const std::set<std::string> &privileges);
	void on_breath_changed(u16 breath);
	void on_player_list_changed(u8 type,
			const std::vector<std::string> &names);
	void on_lighting_changed(const Lighting &lighting);

	// Phase 4: Game loop hooks
	void on_pre_step(float dtime);
	void on_post_step(float dtime);

	// Phase 5: Raw packet interception
	RawPacketHookResult on_raw_packet_received(u16 command,
			const std::string &payload);
	RawPacketHookResult on_raw_packet_sending(u16 command,
			const std::string &payload);
	bool send_raw_packet(u16 command, const std::string &payload);

protected:
	void init_raw_packet_api();

private:
	Client *m_client = nullptr;

	void push_movement_table(LocalPlayer *player);
	void push_lighting_table(const Lighting &lighting);
};
