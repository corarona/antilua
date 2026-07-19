// Antilua — Lua 3D drawing API
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "l_base.h"

class LuaDraw3D : public ModApiBase
{
private:
	static const luaL_Reg methods[];
	static int gc_object(lua_State *L);

	static int l_add_sphere(lua_State *L);
	static int l_add_box(lua_State *L);
	static int l_add_wirebox(lua_State *L);
	static int l_add_line(lua_State *L);
	static int l_add_circle(lua_State *L);
	static int l_clear(lua_State *L);

public:
	static void create(lua_State *L);
	static void Register(lua_State *L);
	static const char className[];
};
