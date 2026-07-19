/*
Minetest
Copyright (C) 2013 celeron55, Perttu Ahola <celeron55@gmail.com>
Copyright (C) 2017 nerzhul, Loic Blot <loic.blot@unix-experience.fr>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

#include "scripting_client.h"
#include "client/client.h"
#include "client/game.h"
#include "client/game_internal.h"
#include "cpp_api/s_internal.h"
#include "lua_api/l_client.h"
#include "lua_api/l_clientobject.h"
#include "lua_api/l_client_common.h"
#include "lua_api/l_env.h"
#include "lua_api/l_inventoryaction.h"
#include "lua_api/l_item.h"
#include "lua_api/l_itemstackmeta.h"
#include "lua_api/l_minimap.h"
#include "lua_api/l_modchannels.h"
#include "lua_api/l_particles_local.h"
#include "lua_api/l_storage.h"
#include "lua_api/l_util.h"
#include "lua_api/l_item.h"
#include "lua_api/l_nodemeta.h"
#include "porting.h"
#include "filesys.h"
#include "lua_api/l_noise.h"
#include "lua_api/l_localplayer.h"
#include "lua_api/l_camera.h"
#include "lua_api/l_settings.h"
#include "lua_api/l_http.h"
#include "lua_api/l_vmanip.h"
#include "lua_api/l_client_sound.h"
#include "lua_api/l_sky.h"
#include "lua_api/l_clouds.h"
#include "lua_api/l_draw3d.h"
#include "lua_api/al_client_map.h"

ClientScripting::ClientScripting(Client *client):
	ScriptApiBase(ScriptingType::Client)
{
	setGameDef(client);

	SCRIPTAPI_PRECHECKHEADER

	// Security is mandatory client side
	initializeSecurityClient();

	lua_getglobal(L, "core");
	int top = lua_gettop(L);

	lua_newtable(L);
	lua_setfield(L, -2, "ui");

	lua_newtable(L);
	lua_setfield(L, -2, "object_refs");

	InitializeModApi(L, top);
	lua_pop(L, 1);

	// Push builtin initialization type
	lua_pushstring(L, "client");
	lua_setglobal(L, "INIT");

	AlScriptApi::setClient(client);

	infostream << "SCRIPTAPI: Initialized client game modules" << std::endl;
}

bool ClientScripting::checkPathInternal(const std::string &abs_path,
	bool write_required, bool *write_allowed)
{
	std::string user_path = fs::AbsolutePath(porting::path_user);
	std::string cache_path = fs::AbsolutePath(porting::path_cache);
	std::string share_path = fs::AbsolutePath(porting::path_share);

	// Write access to user data dir and cache
	if (abs_path.substr(0, user_path.size()) == user_path ||
		abs_path.substr(0, cache_path.size()) == cache_path) {
		if (write_allowed)
			*write_allowed = true;
		return true;
	}

	// Read-only access to share dir
	if (!write_required && abs_path.substr(0, share_path.size()) == share_path)
		return true;

	return false;
}

void ClientScripting::InitializeModApi(lua_State *L, int top)
{
	LuaItemStack::Register(L);
	LuaValueNoise::Register(L);
	LuaValueNoiseMap::Register(L);
	LuaPseudoRandom::Register(L);
	LuaPcgRandom::Register(L);
	LuaSecureRandom::Register(L);
	ItemStackMetaRef::Register(L);
	LuaRaycast::Register(L);
	StorageRef::Register(L);
	LuaMinimap::Register(L);
	NodeMetaRef::RegisterClient(L);
	ModChannelRef::Register(L);
	LuaSettings::Register(L);
	ClientObjectRef::Register(L);
	LuaInventoryAction::Register(L);
	LuaVoxelManip::Register(L);

	ModApiItem::InitializeClient(L, top);
	ModApiUtil::InitializeClient(L, top);
	ModApiHttp::Initialize(L, top);
	ModApiHttp::InitializeAsync(L, top);
	ModApiClient::Initialize(L, top);
	ModApiClientCommon::Initialize(L, top);
	ModApiStorage::Initialize(L, top);
	ModApiEnv::InitializeClient(L, top);
	ModApiChannels::Initialize(L, top);

	// Antilua API registrations
	LuaLocalPlayer::Register(L);
	LuaCamera::Register(L);
	LuaSky::Register(L);
	LuaClouds::Register(L);
	LuaDraw3D::Register(L);
	ModApiParticlesLocal::Initialize(L, top);
	ModApiClientSound::Initialize(L, top);
	ClientSoundHandle::Register(L);
	AlApiClientMap::Initialize(L, top);
	init_raw_packet_api();
}

void ClientScripting::on_client_ready(LocalPlayer *localplayer)
{
	LuaLocalPlayer::create(getStack(), localplayer);
}

void ClientScripting::on_camera_ready(Camera *camera)
{
	LuaCamera::create(getStack(), camera);
}

void ClientScripting::on_minimap_ready(Minimap *minimap)
{
	LuaMinimap::create(getStack(), minimap);
	LuaSky::create(getStack(), g_game->sky.get());
	LuaClouds::create(getStack(), g_game->clouds.get());
	LuaDraw3D::create(getStack());
}
