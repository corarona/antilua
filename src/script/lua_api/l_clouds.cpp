// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "l_clouds.h"
#include "l_internal.h"
#include "common/c_converter.h"
#include "client/clouds.h"

LuaClouds::LuaClouds(Clouds *m) : m_clouds(m)
{
}

void LuaClouds::create(lua_State *L, Clouds *m)
{
	lua_getglobal(L, "core");
	luaL_checktype(L, -1, LUA_TTABLE);

	lua_getfield(L, -1, "clouds");
	if (lua_type(L, -1) == LUA_TUSERDATA) {
		lua_pop(L, 1);
		return;
	}
	lua_pop(L, 1);

	auto *o = new LuaClouds(m);
	*(void **)(lua_newuserdata(L, sizeof(void *))) = o;
	luaL_getmetatable(L, className);
	lua_setmetatable(L, -2);

	lua_pushvalue(L, lua_gettop(L));
	lua_setfield(L, -3, "clouds");
	lua_pop(L, 1);
}

int LuaClouds::l_set_density(lua_State *L)
{
	auto *ref = checkObject<LuaClouds>(L, 1);
	if (!ref || !ref->m_clouds) return 0;
	ref->m_clouds->setDensity(luaL_checknumber(L, 2));
	return 0;
}

int LuaClouds::l_set_height(lua_State *L)
{
	auto *ref = checkObject<LuaClouds>(L, 1);
	if (!ref || !ref->m_clouds) return 0;
	ref->m_clouds->setHeight(luaL_checknumber(L, 2));
	return 0;
}

int LuaClouds::l_set_thickness(lua_State *L)
{
	auto *ref = checkObject<LuaClouds>(L, 1);
	if (!ref || !ref->m_clouds) return 0;
	ref->m_clouds->setThickness(luaL_checknumber(L, 2));
	return 0;
}

int LuaClouds::l_set_speed(lua_State *L)
{
	auto *ref = checkObject<LuaClouds>(L, 1);
	if (!ref || !ref->m_clouds) return 0;
	ref->m_clouds->setSpeed(read_v2f(L, 2));
	return 0;
}

int LuaClouds::l_set_color_bright(lua_State *L)
{
	auto *ref = checkObject<LuaClouds>(L, 1);
	if (!ref || !ref->m_clouds) return 0;
	video::SColor col(255, 229, 240, 240);
	if (lua_isstring(L, 2))
		read_color(L, 2, &col);
	ref->m_clouds->setColorBright(col);
	return 0;
}

int LuaClouds::l_set_color_ambient(lua_State *L)
{
	auto *ref = checkObject<LuaClouds>(L, 1);
	if (!ref || !ref->m_clouds) return 0;
	video::SColor col(255, 0, 0, 0);
	if (lua_isstring(L, 2))
		read_color(L, 2, &col);
	ref->m_clouds->setColorAmbient(col);
	return 0;
}

int LuaClouds::l_set_color_shadow(lua_State *L)
{
	auto *ref = checkObject<LuaClouds>(L, 1);
	if (!ref || !ref->m_clouds) return 0;
	video::SColor col(255, 204, 204, 204);
	if (lua_isstring(L, 2))
		read_color(L, 2, &col);
	ref->m_clouds->setColorShadow(col);
	return 0;
}

int LuaClouds::l_get_color(lua_State *L)
{
	auto *ref = checkObject<LuaClouds>(L, 1);
	if (!ref || !ref->m_clouds) return 0;
	push_ARGB8(L, ref->m_clouds->getColor());
	return 1;
}

int LuaClouds::l_is_camera_inside(lua_State *L)
{
	auto *ref = checkObject<LuaClouds>(L, 1);
	if (!ref || !ref->m_clouds) return 0;
	lua_pushboolean(L, ref->m_clouds->isCameraInsideCloud());
	return 1;
}

int LuaClouds::gc_object(lua_State *L)
{
	auto *o = *(LuaClouds **)(lua_touserdata(L, 1));
	delete o;
	return 0;
}

void LuaClouds::Register(lua_State *L)
{
	static const luaL_Reg metamethods[] = {
		{"__gc", gc_object},
		{0, 0}
	};
	registerClass<LuaClouds>(L, methods, metamethods);
}

const char LuaClouds::className[] = "Clouds";
const luaL_Reg LuaClouds::methods[] = {
	luamethod(LuaClouds, set_density),
	luamethod(LuaClouds, set_height),
	luamethod(LuaClouds, set_thickness),
	luamethod(LuaClouds, set_speed),
	luamethod(LuaClouds, set_color_bright),
	luamethod(LuaClouds, set_color_ambient),
	luamethod(LuaClouds, set_color_shadow),
	luamethod(LuaClouds, get_color),
	luamethod(LuaClouds, is_camera_inside),
	{0, 0}
};
