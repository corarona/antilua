// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "al_callbacks.h"
#include "../s_internal.h"
#include "client/client.h"
#include "common/c_converter.h"
#include "common/c_content.h"
#include "client/localplayer.h"
#include "network/clientopcodes.h"
#include "network/networkprotocol.h"
#include "particles.h"
#include "sound_spec.h"
#include "lighting.h"

// ---------------------------------------------------------------------------
// Phase 1a: Wire dead callbacks
// ---------------------------------------------------------------------------

void AlScriptApi::push_movement_table(LocalPlayer *player)
{
	lua_State *L = getStack();
	lua_newtable(L);
	lua_pushnumber(L, player->movement_acceleration_default); lua_setfield(L, -2, "acceleration_default");
	lua_pushnumber(L, player->movement_acceleration_air); lua_setfield(L, -2, "acceleration_air");
	lua_pushnumber(L, player->movement_acceleration_fast); lua_setfield(L, -2, "acceleration_fast");
	lua_pushnumber(L, player->movement_speed_walk); lua_setfield(L, -2, "speed_walk");
	lua_pushnumber(L, player->movement_speed_crouch); lua_setfield(L, -2, "speed_crouch");
	lua_pushnumber(L, player->movement_speed_fast); lua_setfield(L, -2, "speed_fast");
	lua_pushnumber(L, player->movement_speed_climb); lua_setfield(L, -2, "speed_climb");
	lua_pushnumber(L, player->movement_speed_jump); lua_setfield(L, -2, "speed_jump");
	lua_pushnumber(L, player->movement_liquid_fluidity); lua_setfield(L, -2, "liquid_fluidity");
	lua_pushnumber(L, player->movement_liquid_fluidity_smooth); lua_setfield(L, -2, "liquid_fluidity_smooth");
	lua_pushnumber(L, player->movement_liquid_sink); lua_setfield(L, -2, "liquid_sink");
	lua_pushnumber(L, player->movement_gravity); lua_setfield(L, -2, "gravity");
}

void AlScriptApi::on_receive_physics_override(LocalPlayer *player)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_receive_physics_override");
	push_movement_table(player);
	try {
		runCallbacks(1, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
	}
}

bool AlScriptApi::on_play_sound(const SoundSpec &spec, SoundLocation type,
		v3f pos, u16 object_id, bool ephemeral, s32 server_id)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_play_sound");

	lua_newtable(L);
	lua_pushstring(L, spec.name.c_str()); lua_setfield(L, -2, "name");
	lua_pushnumber(L, spec.gain); lua_setfield(L, -2, "gain");
	lua_pushinteger(L, (int)type); lua_setfield(L, -2, "type");
	push_v3f(L, pos); lua_setfield(L, -2, "pos");
	lua_pushinteger(L, object_id); lua_setfield(L, -2, "object_id");
	lua_pushboolean(L, spec.loop); lua_setfield(L, -2, "loop");
	lua_pushnumber(L, spec.fade); lua_setfield(L, -2, "fade");
	lua_pushnumber(L, spec.pitch); lua_setfield(L, -2, "pitch");
	lua_pushboolean(L, ephemeral); lua_setfield(L, -2, "ephemeral");
	lua_pushnumber(L, spec.start_time); lua_setfield(L, -2, "start_time");
	lua_pushinteger(L, server_id); lua_setfield(L, -2, "server_id");

	try {
		runCallbacks(1, RUN_CALLBACKS_MODE_OR_SC);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
		return true;
	}
	return readParam<bool>(L, -1);
}

bool AlScriptApi::on_stop_sound(s32 server_id)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_stop_sound");
	lua_pushinteger(L, server_id);
	try {
		runCallbacks(1, RUN_CALLBACKS_MODE_OR_SC);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
		return true;
	}
	return readParam<bool>(L, -1);
}

bool AlScriptApi::on_fade_sound(s32 sound_id, float step, float gain)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_fade_sound");
	lua_pushinteger(L, sound_id);
	lua_pushnumber(L, step);
	lua_pushnumber(L, gain);
	try {
		runCallbacks(3, RUN_CALLBACKS_MODE_OR_SC);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
		return true;
	}
	return readParam<bool>(L, -1);
}

bool AlScriptApi::on_delete_particlespawner(u32 server_id)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_delete_particlespawner");
	lua_pushinteger(L, server_id);
	try {
		runCallbacks(1, RUN_CALLBACKS_MODE_OR_SC);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
		return true;
	}
	return readParam<bool>(L, -1);
}

void AlScriptApi::on_hud_flags_changed()
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_hud_flags_changed");
	try {
		runCallbacks(0, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
	}
}

void AlScriptApi::on_hud_param_changed(u16 param, const std::string &value)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_hud_param_changed");
	lua_pushinteger(L, param);
	lua_pushstring(L, value.c_str());
	try {
		runCallbacks(2, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
	}
}

void AlScriptApi::on_inventory_action()
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_inventory_action");
	try {
		runCallbacks(0, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
	}
}

void AlScriptApi::on_inventory_update()
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_inventory_update");
	try {
		runCallbacks(0, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
	}
}

static void push_stringmap(lua_State *L, const StringMap &map)
{
	lua_newtable(L);
	for (const auto &[key, val] : map) {
		lua_pushstring(L, val.c_str());
		lua_setfield(L, -2, key.c_str());
	}
}

void AlScriptApi::on_nodemetadata_change(const std::vector<NodeMetaChange> &changes)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_nodemetadata_change");

	lua_newtable(L);
	int idx = 1;
	for (const auto &change : changes) {
		lua_newtable(L);

		push_v3s16(L, change.pos);
		lua_setfield(L, -2, "pos");

		push_stringmap(L, change.old_strings);
		lua_setfield(L, -2, "old");

		push_stringmap(L, change.new_strings);
		lua_setfield(L, -2, "new");

		lua_rawseti(L, -2, idx++);
	}
	try {
		runCallbacks(1, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
	}
}

void AlScriptApi::on_sky_changed()
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_sky_changed");
	try {
		runCallbacks(0, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
	}
}

void AlScriptApi::on_clouds_changed()
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_clouds_changed");
	try {
		runCallbacks(0, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
	}
}

bool AlScriptApi::on_spawn_particle(const ParticleParameters &p)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_spawn_particle");

	lua_newtable(L);
	push_v3f(L, p.pos); lua_setfield(L, -2, "pos");
	push_v3f(L, p.vel); lua_setfield(L, -2, "vel");
	push_v3f(L, p.acc); lua_setfield(L, -2, "acc");
	lua_pushnumber(L, p.expirationtime); lua_setfield(L, -2, "expiration_time");
	lua_pushnumber(L, p.size); lua_setfield(L, -2, "size");
	lua_pushboolean(L, p.collisiondetection); lua_setfield(L, -2, "collisiondetection");
	lua_pushstring(L, p.texture.string.c_str()); lua_setfield(L, -2, "texture");

	try {
		runCallbacks(1, RUN_CALLBACKS_MODE_OR_SC);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
		return true;
	}
	return readParam<bool>(L, -1);
}

bool AlScriptApi::on_receive_particlespawner(
		const ParticleSpawnerParameters &p, u32 server_id, u16 attached_id)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_receive_particlespawner");

	lua_newtable(L);
	lua_pushinteger(L, p.amount); lua_setfield(L, -2, "amount");
	lua_pushnumber(L, p.time); lua_setfield(L, -2, "time");
	lua_pushinteger(L, server_id); lua_setfield(L, -2, "id");
	lua_pushinteger(L, attached_id); lua_setfield(L, -2, "attached_id");

	push_v3f(L, p.pos.start.min); lua_setfield(L, -2, "minpos");
	push_v3f(L, p.pos.start.max); lua_setfield(L, -2, "maxpos");
	push_v3f(L, p.vel.start.min); lua_setfield(L, -2, "minvel");
	push_v3f(L, p.vel.start.max); lua_setfield(L, -2, "maxvel");
	push_v3f(L, p.acc.start.min); lua_setfield(L, -2, "minacc");
	push_v3f(L, p.acc.start.max); lua_setfield(L, -2, "maxacc");
	lua_pushstring(L, p.texture.string.c_str()); lua_setfield(L, -2, "texture");
	lua_pushboolean(L, p.collisiondetection); lua_setfield(L, -2, "collisiondetection");
	lua_pushboolean(L, p.vertical); lua_setfield(L, -2, "vertical");

	try {
		runCallbacks(1, RUN_CALLBACKS_MODE_OR_SC);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
		return true;
	}
	return readParam<bool>(L, -1);
}

bool AlScriptApi::on_sending_inventory_fields(const std::string &formname,
		const StringMap &fields)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_sending_inventory_fields");
	lua_pushstring(L, formname.c_str());
	lua_newtable(L);
	for (const auto &[key, val] : fields) {
		lua_pushstring(L, val.c_str());
		lua_setfield(L, -2, key.c_str());
	}
	try {
		runCallbacks(2, RUN_CALLBACKS_MODE_OR_SC);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
		return true;
	}
	return readParam<bool>(L, -1);
}

bool AlScriptApi::on_sending_nodemeta_fields(const std::string &formname,
		const StringMap &fields)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_sending_nodemeta_fields");
	lua_pushstring(L, formname.c_str());
	lua_newtable(L);
	for (const auto &[key, val] : fields) {
		lua_pushstring(L, val.c_str());
		lua_setfield(L, -2, key.c_str());
	}
	try {
		runCallbacks(2, RUN_CALLBACKS_MODE_OR_SC);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
		return true;
	}
	return readParam<bool>(L, -1);
}

void AlScriptApi::on_detached_inventory_update(const std::string &name, bool keep)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_detached_inventory_update");
	lua_pushstring(L, name.c_str());
	lua_pushboolean(L, keep);
	try {
		runCallbacks(2, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
	}
}

std::string AlScriptApi::on_receiving_inventory_form(const std::string &formspec)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_receiving_inventory_form");
	lua_pushstring(L, formspec.c_str());
	try {
		runCallbacks(1, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
		return formspec;
	}
	if (lua_type(L, -1) == LUA_TSTRING) {
		const char *s = lua_tostring(L, -1);
		if (s && s[0])
			return s;
	}
	return formspec;
}

bool AlScriptApi::on_open_nodemeta_form(v3s16 pos, const std::string &formspec)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_open_nodemeta_form");
	// pos is passed as the nodemeta position in node coordinates
	push_v3s16(L, pos);
	lua_pushstring(L, formspec.c_str());
	try {
		runCallbacks(2, RUN_CALLBACKS_MODE_OR_SC);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
		return true;
	}
	return readParam<bool>(L, -1);
}

// ---------------------------------------------------------------------------
// Phase 1b: Moved from ScriptApiClient
// ---------------------------------------------------------------------------

void AlScriptApi::on_death()
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_death");
	try {
		runCallbacks(0, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
	}
}

bool AlScriptApi::on_object_add(u16 id)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_object_add");
	lua_pushnumber(L, id);
	try {
		runCallbacks(1, RUN_CALLBACKS_MODE_OR_SC);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
		return true;
	}
	return readParam<bool>(L, -1);
}

void AlScriptApi::on_object_hp_change(u16 id, u16 hp)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_object_hp_change");
	lua_pushnumber(L, id);
	lua_pushnumber(L, hp);
	try {
		runCallbacks(2, RUN_CALLBACKS_MODE_OR_SC);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
	}
}

void AlScriptApi::on_object_properties_change(u16 id)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_object_properties_change");
	lua_pushnumber(L, id);
	try {
		runCallbacks(1, RUN_CALLBACKS_MODE_OR_SC);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
	}
}

// ---------------------------------------------------------------------------
// Phase 2: New interception callbacks
// ---------------------------------------------------------------------------

std::string AlScriptApi::on_receiving_formspec(const std::string &formname,
		const std::string &formspec)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_receiving_formspec");
	lua_remove(L, -2); // pop 'core'

	if (lua_type(L, -1) != LUA_TTABLE) {
		lua_pop(L, 1);
		return formspec;
	}

	// Chain: each callback receives the output of the previous one
	std::string current = formspec;

	lua_pushnil(L);
	while (lua_next(L, -2) != 0) {
		if (lua_type(L, -1) == LUA_TFUNCTION) {
			PUSH_ERROR_HANDLER(L);
			lua_pushvalue(L, -2); // copy function
			lua_pushstring(L, formname.c_str());
			lua_pushlstring(L, current.data(), current.size());

			if (lua_pcall(L, 2, 1, -4) == 0) {
				if (lua_type(L, -1) == LUA_TSTRING)
					current = lua_tostring(L, -1);
				lua_pop(L, 1); // pop return value
			} else {
				lua_pop(L, 1); // pop error message
			}
			lua_pop(L, 1); // pop error handler
		}
		lua_pop(L, 1); // pop value (function or non-function)
	}
	lua_pop(L, 1); // pop table

	return current;
}

void AlScriptApi::on_node_add(v3s16 pos, const MapNode &node)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_node_add");
	push_v3s16(L, pos);
	pushnode(L, node);
	try {
		runCallbacks(2, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
	}
}

void AlScriptApi::on_node_remove(v3s16 pos)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_node_remove");
	push_v3s16(L, pos);
	try {
		runCallbacks(1, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
	}
}

bool AlScriptApi::on_hud_add(u32 server_id, u8 type, const v2f &pos,
		const std::string &name, const v2f &scale,
		const std::string &text, u32 number, u32 item,
		u32 dir, const v2f &align, const v2f &offset,
		const v3f &world_pos, const v2f &size, s16 z_index,
		const std::string &text2, u32 style, bool hideable)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_hud_add");

	lua_newtable(L);
	lua_pushinteger(L, server_id); lua_setfield(L, -2, "server_id");
	lua_pushinteger(L, type); lua_setfield(L, -2, "type");
	push_v2f(L, pos); lua_setfield(L, -2, "pos");
	lua_pushstring(L, name.c_str()); lua_setfield(L, -2, "name");
	push_v2f(L, scale); lua_setfield(L, -2, "scale");
	lua_pushstring(L, text.c_str()); lua_setfield(L, -2, "text");
	lua_pushinteger(L, number); lua_setfield(L, -2, "number");
	lua_pushinteger(L, item); lua_setfield(L, -2, "item");
	lua_pushinteger(L, dir); lua_setfield(L, -2, "dir");
	push_v2f(L, align); lua_setfield(L, -2, "align");
	push_v2f(L, offset); lua_setfield(L, -2, "offset");
	push_v3f(L, world_pos); lua_setfield(L, -2, "world_pos");
	push_v2f(L, size); lua_setfield(L, -2, "size");
	lua_pushinteger(L, z_index); lua_setfield(L, -2, "z_index");
	lua_pushstring(L, text2.c_str()); lua_setfield(L, -2, "text2");
	lua_pushinteger(L, style); lua_setfield(L, -2, "style");
	lua_pushboolean(L, hideable); lua_setfield(L, -2, "hideable");

	try {
		runCallbacks(1, RUN_CALLBACKS_MODE_OR_SC);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
		return true;
	}
	return readParam<bool>(L, -1);
}

bool AlScriptApi::on_hud_remove(u32 server_id)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_hud_remove");
	lua_pushinteger(L, server_id);
	try {
		runCallbacks(1, RUN_CALLBACKS_MODE_OR_SC);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
		return true;
	}
	return readParam<bool>(L, -1);
}

bool AlScriptApi::on_hud_change(u32 server_id, HudElementStat stat,
		const std::string &sdata, const v2f &v2fdata,
		const v3f &v3fdata, u32 intdata)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_hud_change");
	lua_pushinteger(L, server_id);
	lua_pushinteger(L, (int)stat);
	// Push the appropriate value based on stat type
	// Callbacks can look at the value they care about
	lua_pushstring(L, sdata.c_str());
	push_v2f(L, v2fdata);
	push_v3f(L, v3fdata);
	lua_pushinteger(L, intdata);
	try {
		runCallbacks(6, RUN_CALLBACKS_MODE_OR_SC);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
		return true;
	}
	return readParam<bool>(L, -1);
}

float AlScriptApi::on_time_of_day(u16 time, float speed)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_time_of_day");
	lua_pushinteger(L, time);
	lua_pushnumber(L, speed);
	try {
		runCallbacks(2, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
		return -1.0f;
	}
	if (lua_type(L, -1) == LUA_TNUMBER) {
		float val = lua_tonumber(L, -1);
		if (val >= 0.0f && val <= 24000.0f)
			return val;
	}
	return -1.0f;
}

// ---------------------------------------------------------------------------
// Phase 3: New notification callbacks
// ---------------------------------------------------------------------------

void AlScriptApi::on_connect()
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_connect");
	try {
		runCallbacks(0, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
	}
}

void AlScriptApi::on_disconnect()
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_disconnect");
	try {
		runCallbacks(0, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
	}
}

void AlScriptApi::on_privileges_changed(const std::set<std::string> &privileges)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_privileges_changed");

	lua_newtable(L);
	int idx = 1;
	for (const auto &priv : privileges) {
		lua_pushstring(L, priv.c_str());
		lua_rawseti(L, -2, idx++);
	}
	try {
		runCallbacks(1, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
	}
}

void AlScriptApi::on_breath_changed(u16 breath)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_breath_changed");
	lua_pushinteger(L, breath);
	try {
		runCallbacks(1, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
	}
}

void AlScriptApi::on_player_list_changed(u8 type,
		const std::vector<std::string> &names)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_player_list_changed");
	lua_pushinteger(L, type);

	lua_newtable(L);
	int idx = 1;
	for (const auto &name : names) {
		lua_pushstring(L, name.c_str());
		lua_rawseti(L, -2, idx++);
	}
	try {
		runCallbacks(2, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
	}
}

void AlScriptApi::push_lighting_table(const Lighting &lighting)
{
	lua_State *L = getStack();
	lua_newtable(L);
	lua_pushnumber(L, lighting.shadow_intensity); lua_setfield(L, -2, "shadow_intensity");
	lua_pushnumber(L, lighting.saturation); lua_setfield(L, -2, "saturation");
	lua_pushnumber(L, lighting.exposure.luminance_min); lua_setfield(L, -2, "luminance_min");
	lua_pushnumber(L, lighting.exposure.luminance_max); lua_setfield(L, -2, "luminance_max");
	lua_pushnumber(L, lighting.exposure.exposure_correction); lua_setfield(L, -2, "exposure_correction");
	lua_pushnumber(L, lighting.exposure.speed_dark_bright); lua_setfield(L, -2, "speed_dark_bright");
	lua_pushnumber(L, lighting.exposure.speed_bright_dark); lua_setfield(L, -2, "speed_bright_dark");
	lua_pushnumber(L, lighting.exposure.center_weight_power); lua_setfield(L, -2, "center_weight_power");
	lua_pushnumber(L, lighting.volumetric_light_strength); lua_setfield(L, -2, "volumetric_light_strength");
	lua_pushinteger(L, lighting.shadow_tint.color); lua_setfield(L, -2, "shadow_tint");
	lua_pushnumber(L, lighting.bloom_intensity); lua_setfield(L, -2, "bloom_intensity");
	lua_pushnumber(L, lighting.bloom_strength_factor); lua_setfield(L, -2, "bloom_strength_factor");
	lua_pushnumber(L, lighting.bloom_radius); lua_setfield(L, -2, "bloom_radius");
}

void AlScriptApi::on_lighting_changed(const Lighting &lighting)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_lighting_changed");
	push_lighting_table(lighting);
	try {
		runCallbacks(1, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
	}
}

// ---------------------------------------------------------------------------
// Phase 4: Game loop hooks
// ---------------------------------------------------------------------------

void AlScriptApi::on_pre_step(float dtime)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_pre_step");
	lua_pushnumber(L, dtime);
	try {
		runCallbacks(1, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
	}
}

void AlScriptApi::on_post_step(float dtime)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_post_step");
	lua_pushnumber(L, dtime);
	try {
		runCallbacks(1, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
	}
}

// ---------------------------------------------------------------------------
// Phase 5: Raw packet interception
// ---------------------------------------------------------------------------

RawPacketHookResult AlScriptApi::on_raw_packet_received(u16 command,
		const std::string &payload)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_receiving_raw_packet");
	lua_pushinteger(L, command);
	lua_pushlstring(L, payload.data(), payload.size());
	try {
		runCallbacks(2, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
		return {false, {}};
	}
	if (lua_type(L, -1) == LUA_TBOOLEAN) {
		if (lua_toboolean(L, -1))
			return {true, {}};
		return {false, {}};
	}
	if (lua_type(L, -1) == LUA_TSTRING) {
		size_t len;
		const char *s = lua_tolstring(L, -1, &len);
		if (s)
			return {false, std::string(s, len)};
	}
	return {false, {}};
}

RawPacketHookResult AlScriptApi::on_raw_packet_sending(u16 command,
		const std::string &payload)
{
	SCRIPTAPI_PRECHECKHEADER

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "registered_on_sending_raw_packet");
	lua_pushinteger(L, command);
	lua_pushlstring(L, payload.data(), payload.size());
	try {
		runCallbacks(2, RUN_CALLBACKS_MODE_FIRST);
	} catch (LuaError &e) {
		getClient()->setFatalError(e);
		return {false, {}};
	}
	if (lua_type(L, -1) == LUA_TBOOLEAN) {
		if (lua_toboolean(L, -1))
			return {true, {}};
		return {false, {}};
	}
	if (lua_type(L, -1) == LUA_TSTRING) {
		size_t len;
		const char *s = lua_tolstring(L, -1, &len);
		if (s)
			return {false, std::string(s, len)};
	}
	return {false, {}};
}

void AlScriptApi::init_raw_packet_api()
{
	SCRIPTAPI_PRECHECKHEADER

	// core.TOCLIENT table
	lua_getglobal(L, "core");
	lua_newtable(L);
	for (u16 i = 0; i < TOCLIENT_NUM_MSG_TYPES; i++) {
		if (!toClientCommandTable[i].name)
			continue;
		const char *name = toClientCommandTable[i].name + 9; // strip "TOCLIENT_"
		lua_pushinteger(L, i);
		lua_setfield(L, -2, name);
	}
	lua_setfield(L, -2, "TOCLIENT");

	// core.TOSERVER table
	lua_newtable(L);
	for (u16 i = 0; i < TOSERVER_NUM_MSG_TYPES; i++) {
		if (!serverCommandFactoryTable[i].name)
			continue;
		const char *name = serverCommandFactoryTable[i].name + 9; // strip "TOSERVER_"
		lua_pushinteger(L, i);
		lua_setfield(L, -2, name);
	}
	lua_setfield(L, -2, "TOSERVER");

	lua_pop(L, 1); // pop core
}

bool AlScriptApi::send_raw_packet(u16 command, const std::string &payload)
{
	switch (command) {
	case TOSERVER_INIT:
	case TOSERVER_INIT2:
	case TOSERVER_FIRST_SRP:
	case TOSERVER_SRP_BYTES_A:
	case TOSERVER_SRP_BYTES_M:
		return false;
	default:
		break;
	}

	if (command >= TOSERVER_NUM_MSG_TYPES ||
			!serverCommandFactoryTable[command].name)
		return false;

	Client *client = getClient();
	NetworkPacket pkt(command, payload.size());
	pkt.putRawString(payload.data(), payload.size());
	client->Send(&pkt);
	return true;
}
