// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "l_base.h"

class Clouds;

class LuaClouds : public ModApiBase
{
private:
	static const luaL_Reg methods[];

	static int gc_object(lua_State *L);

	static int l_set_density(lua_State *L);
	static int l_set_height(lua_State *L);
	static int l_set_thickness(lua_State *L);
	static int l_set_speed(lua_State *L);
	static int l_set_color_bright(lua_State *L);
	static int l_set_color_ambient(lua_State *L);
	static int l_set_color_shadow(lua_State *L);
	static int l_get_color(lua_State *L);
	static int l_is_camera_inside(lua_State *L);

	Clouds *m_clouds = nullptr;

public:
	LuaClouds(Clouds *m);
	~LuaClouds() = default;

	static void create(lua_State *L, Clouds *m);

	static void Register(lua_State *L);

	static const char className[];
};
