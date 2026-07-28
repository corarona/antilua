// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "lua_api/l_base.h"

class ModApiServerReload : public ModApiBase
{
private:
	static int l_reload_server_mod(lua_State *L);
	static int l_list_mod_files(lua_State *L);
	static int l_read_mod_file(lua_State *L);
	static int l_write_mod_file(lua_State *L);

public:
	static void Initialize(lua_State *L, int top);
};
