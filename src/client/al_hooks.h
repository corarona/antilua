// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <string>
#include <vector>
#include <set>
#include "irr_v2d.h"
#include "irr_v3d.h"
#include "util/string.h"

class Client;
class LocalPlayer;
struct MapNode;
struct SoundSpec;
struct ParticleParameters;
struct ParticleSpawnerParameters;
struct Lighting;
enum class SoundLocation : u8;
enum HudElementStat : u8;

struct RawPacketHookResult
{
	bool drop = false;
	std::string payload; // empty = no modification, non-empty = replacement
};

namespace AlClientHooks {

void on_movement(Client *client, LocalPlayer *player);

bool on_play_sound(Client *client, const SoundSpec &spec,
		SoundLocation type, v3f pos, u16 object_id,
		bool ephemeral, s32 server_id);

bool on_spawn_particle(Client *client,
		const ParticleParameters &p);

bool on_receive_particlespawner(Client *client,
		const ParticleSpawnerParameters &p,
		u32 server_id, u16 attached_id);

void on_sending_inventory_fields(Client *client,
		const std::string &formname, const StringMap &fields);

void on_sending_nodemeta_fields(Client *client,
		const std::string &formname, const StringMap &fields);

void on_detached_inventory_update(Client *client,
		const std::string &name, bool keep);

std::string on_receiving_inventory_form(Client *client,
		const std::string &formspec);

bool on_open_nodemeta_form(Client *client, v3s16 pos,
		const std::string &formspec);

void on_death(Client *client);

bool on_delete_particlespawner(Client *client, u32 server_id);

bool on_stop_sound(Client *client, s32 server_id);
bool on_fade_sound(Client *client, s32 sound_id, float step, float gain);

bool on_object_add(Client *client, u16 id);
void on_object_hp_change(Client *client, u16 id, u16 hp);
void on_object_properties_change(Client *client, u16 id);

void on_hp_change(Client *client, u16 hp);

std::string on_receiving_formspec(Client *client,
		const std::string &formname, const std::string &formspec);

void on_node_add(Client *client, v3s16 pos, const MapNode &node);
void on_node_remove(Client *client, v3s16 pos);

bool on_hud_add(Client *client, u32 server_id, u8 type,
		const v2f &pos, const std::string &name,
		const v2f &scale, const std::string &text,
		u32 number, u32 item, u32 dir, const v2f &align,
		const v2f &offset, const v3f &world_pos,
		const v2f &size, s16 z_index, const std::string &text2,
		u32 style, bool hideable);
bool on_hud_remove(Client *client, u32 server_id);
bool on_hud_change(Client *client, u32 server_id,
		HudElementStat stat, const std::string &sdata,
		const v2f &v2fdata, const v3f &v3fdata, u32 intdata);

float on_time_of_day(Client *client, u16 time, float speed);

void on_connect(Client *client);
void on_disconnect(Client *client);
void on_privileges(Client *client,
		const std::set<std::string> &privileges);
void on_breath(Client *client, u16 breath);
void on_player_list(Client *client, u8 type,
		const std::vector<std::string> &names);
void on_lighting(Client *client, const Lighting &lighting);

void on_pre_step(Client *client, float dtime);
void on_post_step(Client *client, float dtime);

RawPacketHookResult on_raw_packet_received(Client *client, u16 command,
		const std::string &payload);
RawPacketHookResult on_raw_packet_sending(Client *client, u16 command,
		const std::string &payload);

} // namespace AlClientHooks
