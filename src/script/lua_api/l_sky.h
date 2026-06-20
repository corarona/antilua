// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "l_base.h"

class Sky;

class LuaSky : public ModApiBase
{
private:
	static const luaL_Reg methods[];

	static int gc_object(lua_State *L);

	static int l_set_sun_visible(lua_State *L);
	static int l_set_moon_visible(lua_State *L);
	static int l_set_stars_visible(lua_State *L);
	static int l_set_star_count(lua_State *L);
	static int l_set_star_color(lua_State *L);
	static int l_set_star_scale(lua_State *L);
	static int l_set_sun_scale(lua_State *L);
	static int l_set_moon_scale(lua_State *L);
	static int l_set_body_orbit_tilt(lua_State *L);
	static int l_set_clouds_enabled(lua_State *L);
	static int l_set_fog_distance(lua_State *L);
	static int l_set_fog_start(lua_State *L);
	static int l_set_fog_color(lua_State *L);
	static int l_get_brightness(lua_State *L);
	static int l_get_sun_direction(lua_State *L);
	static int l_get_moon_direction(lua_State *L);
	static int l_get_cloud_color(lua_State *L);

	Sky *m_sky = nullptr;

public:
	LuaSky(Sky *m);
	~LuaSky() = default;

	static void create(lua_State *L, Sky *m);

	static void Register(lua_State *L);

	static const char className[];
};
