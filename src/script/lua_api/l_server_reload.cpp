// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "lua_api/l_server_reload.h"
#include "common/c_content.h"
#include "common/c_converter.h"
#include "cpp_api/s_base.h"
#include "cpp_api/s_env.h"
#include "cpp_api/s_security.h"
#include "lua_api/l_internal.h"
#include "scripting_server.h"
#include "server.h"
#include "serverenvironment.h"
#include "server/mods.h"
#include "nodedef.h"
#include "craftdef.h"
#include "log.h"
#include "filesys.h"

#include <exception>

int ModApiServerReload::l_reload_server_mod(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;

	std::string modname = readParam<std::string>(L, 1);
	if (modname.empty()) {
		lua_pushboolean(L, false);
		lua_pushstring(L, "modname is empty");
		return 2;
	}

	Server *server = getServer(L);

	const ModSpec *mod = server->getModSpec(modname);
	if (!mod) {
		infostream << "reload_server_mod: mod \"" << modname << "\" not found" << std::endl;
		lua_pushboolean(L, false);
		lua_pushstring(L, "mod not found");
		return 2;
	}

	ServerScripting *script = server->getScriptIface();

	infostream << "reload_server_mod: reloading \"" << modname << "\"" << std::endl;

	// Step 1: Run Lua cleanup — remove old callbacks, ABMs, LBMs, items, entities
	lua_getglobal(L, "core");
	lua_getfield(L, -1, "cleanup_server_mod");
	if (lua_type(L, -1) != LUA_TFUNCTION) {
		lua_pop(L, 2);
		lua_pushboolean(L, false);
		lua_pushstring(L, "core.cleanup_server_mod not found");
		return 2;
	}
	lua_pushstring(L, modname.c_str());
	if (lua_pcall(L, 1, 0, 0) != 0) {
		std::string err = lua_tostring(L, -1);
		lua_pop(L, 2);
		infostream << "reload_server_mod: cleanup failed for \"" << modname << "\": "
			<< err << std::endl;
		lua_pushboolean(L, false);
		lua_pushstring(L, ("cleanup failed: " + err).c_str());
		return 2;
	}
	lua_pop(L, 1);

	// Step 2: Unfreeze registration tables
	lua_getglobal(L, "core");
	lua_getfield(L, -1, "unfreeze_registration_tables");
	if (lua_type(L, -1) == LUA_TFUNCTION) {
		if (lua_pcall(L, 0, 0, 0) != 0) {
			std::string err = lua_tostring(L, -1);
			lua_pop(L, 2);
			infostream << "reload_server_mod: unfreeze failed: " << err << std::endl;
			lua_pushboolean(L, false);
			lua_pushstring(L, ("unfreeze failed: " + err).c_str());
			return 2;
		}
	}
	lua_pop(L, 1);

	// Step 3: Re-execute the mod's init.lua
	std::string script_path = mod->path + DIR_DELIM + "init.lua";
	if (!fs::PathExists(script_path)) {
		infostream << "reload_server_mod: init.lua not found for \"" << modname << "\""
			<< std::endl;
		lua_pushboolean(L, false);
		lua_pushstring(L, "init.lua not found");
		return 2;
	}

	try {
		script->loadMod(script_path, modname);
	} catch (ModError &e) {
		infostream << "reload_server_mod: loadMod failed for \"" << modname << "\": "
			<< e.what() << std::endl;
		lua_pushboolean(L, false);
		lua_pushstring(L, e.what());
		return 2;
	}

	// Step 4: Clear and re-read ABMs from Lua into C++
	{
		ServerEnvironment &env = server->getEnv();
		env.clearActiveBlockModifiers();
		try {
			script->reloadABMs();
		} catch (std::exception &e) {
			infostream << "reload_server_mod: reloadABMs failed: " << e.what() << std::endl;
			lua_pushboolean(L, false);
			lua_pushstring(L, ("ABM reload failed: " + std::string(e.what())).c_str());
			return 2;
		}
	}

	// Step 5: Post-reload maintenance
	try {
		server->getWritableNodeDefManager()->updateAliases(
			server->getItemDefManager());
		server->getWritableNodeDefManager()->runNodeResolveCallbacks();
		server->getWritableCraftDefManager()->initHashes(server);
	} catch (std::exception &e) {
		infostream << "reload_server_mod: post-reload maintenance failed: "
			<< e.what() << std::endl;
	}

	// saveGlobals is intentionally skipped:
	// core.get_globals_to_transfer is unset after the first call,
	// and async workers don't re-read it on reload anyway.

	// Step 6: Refreeze registration tables
	lua_getglobal(L, "core");
	lua_getfield(L, -1, "refreeze_registration_tables");
	if (lua_type(L, -1) == LUA_TFUNCTION) {
		if (lua_pcall(L, 0, 0, 0) != 0) {
			std::string err = lua_tostring(L, -1);
			lua_pop(L, 2);
			infostream << "reload_server_mod: refreeze failed: " << err << std::endl;
			lua_pushboolean(L, false);
			lua_pushstring(L, ("refreeze failed: " + err).c_str());
			return 2;
		}
	}
	lua_pop(L, 1);

	infostream << "reload_server_mod: \"" << modname << "\" reloaded successfully"
		<< std::endl;
	lua_pushboolean(L, true);
	lua_pushstring(L, ("Mod '" + modname + "' reloaded").c_str());
	return 2;
}

void ModApiServerReload::Initialize(lua_State *L, int top)
{
	API_FCT(reload_server_mod);
}
