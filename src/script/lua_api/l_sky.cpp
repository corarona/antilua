// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "l_sky.h"
#include "l_internal.h"
#include "common/c_converter.h"
#include "client/sky.h"

LuaSky::LuaSky(Sky *m) : m_sky(m)
{
}

void LuaSky::create(lua_State *L, Sky *m)
{
	auto *o = new LuaSky(m);
	*(void **)(lua_newuserdata(L, sizeof(void *))) = o;
	luaL_getmetatable(L, className);
	lua_setmetatable(L, -2);

	lua_getglobal(L, "core");
	luaL_checktype(L, -1, LUA_TTABLE);
	lua_pushvalue(L, -2);
	lua_setfield(L, -2, "sky");
	lua_pop(L, 2);
}

int LuaSky::l_set_sun_visible(lua_State *L)
{
	auto *ref = checkObject<LuaSky>(L, 1);
	if (!ref || !ref->m_sky) return 0;
	ref->m_sky->setSunVisible(lua_toboolean(L, 2));
	return 0;
}

int LuaSky::l_set_moon_visible(lua_State *L)
{
	auto *ref = checkObject<LuaSky>(L, 1);
	if (!ref || !ref->m_sky) return 0;
	ref->m_sky->setMoonVisible(lua_toboolean(L, 2));
	return 0;
}

int LuaSky::l_set_stars_visible(lua_State *L)
{
	auto *ref = checkObject<LuaSky>(L, 1);
	if (!ref || !ref->m_sky) return 0;
	ref->m_sky->setStarsVisible(lua_toboolean(L, 2));
	return 0;
}

int LuaSky::l_set_star_count(lua_State *L)
{
	auto *ref = checkObject<LuaSky>(L, 1);
	if (!ref || !ref->m_sky) return 0;
	ref->m_sky->setStarCount((u16)luaL_checkinteger(L, 2));
	return 0;
}

int LuaSky::l_set_star_color(lua_State *L)
{
	auto *ref = checkObject<LuaSky>(L, 1);
	if (!ref || !ref->m_sky) return 0;
	video::SColor col(255, 105, 235, 235);
	if (lua_isstring(L, 2))
		read_color(L, 2, &col);
	ref->m_sky->setStarColor(col);
	return 0;
}

int LuaSky::l_set_star_scale(lua_State *L)
{
	auto *ref = checkObject<LuaSky>(L, 1);
	if (!ref || !ref->m_sky) return 0;
	ref->m_sky->setStarScale(luaL_checknumber(L, 2));
	return 0;
}

int LuaSky::l_set_sun_scale(lua_State *L)
{
	auto *ref = checkObject<LuaSky>(L, 1);
	if (!ref || !ref->m_sky) return 0;
	ref->m_sky->setSunScale(luaL_checknumber(L, 2));
	return 0;
}

int LuaSky::l_set_moon_scale(lua_State *L)
{
	auto *ref = checkObject<LuaSky>(L, 1);
	if (!ref || !ref->m_sky) return 0;
	ref->m_sky->setMoonScale(luaL_checknumber(L, 2));
	return 0;
}

int LuaSky::l_set_body_orbit_tilt(lua_State *L)
{
	auto *ref = checkObject<LuaSky>(L, 1);
	if (!ref || !ref->m_sky) return 0;
	ref->m_sky->setBodyOrbitTilt(luaL_checknumber(L, 2));
	return 0;
}

int LuaSky::l_set_clouds_enabled(lua_State *L)
{
	auto *ref = checkObject<LuaSky>(L, 1);
	if (!ref || !ref->m_sky) return 0;
	ref->m_sky->setCloudsEnabled(lua_toboolean(L, 2));
	return 0;
}

int LuaSky::l_set_fog_distance(lua_State *L)
{
	auto *ref = checkObject<LuaSky>(L, 1);
	if (!ref || !ref->m_sky) return 0;
	ref->m_sky->setFogDistance((s16)luaL_checkinteger(L, 2));
	return 0;
}

int LuaSky::l_set_fog_start(lua_State *L)
{
	auto *ref = checkObject<LuaSky>(L, 1);
	if (!ref || !ref->m_sky) return 0;
	ref->m_sky->setFogStart(luaL_checknumber(L, 2));
	return 0;
}

int LuaSky::l_set_fog_color(lua_State *L)
{
	auto *ref = checkObject<LuaSky>(L, 1);
	if (!ref || !ref->m_sky) return 0;
	video::SColor col(255, 255, 255, 255);
	if (lua_isstring(L, 2))
		read_color(L, 2, &col);
	ref->m_sky->setFogColor(col);
	return 0;
}

int LuaSky::l_get_brightness(lua_State *L)
{
	auto *ref = checkObject<LuaSky>(L, 1);
	if (!ref || !ref->m_sky) return 0;
	lua_pushnumber(L, ref->m_sky->getBrightness());
	return 1;
}

int LuaSky::l_get_sun_direction(lua_State *L)
{
	auto *ref = checkObject<LuaSky>(L, 1);
	if (!ref || !ref->m_sky) return 0;
	push_v3f(L, ref->m_sky->getSunDirection());
	return 1;
}

int LuaSky::l_get_moon_direction(lua_State *L)
{
	auto *ref = checkObject<LuaSky>(L, 1);
	if (!ref || !ref->m_sky) return 0;
	push_v3f(L, ref->m_sky->getMoonDirection());
	return 1;
}

int LuaSky::l_get_cloud_color(lua_State *L)
{
	auto *ref = checkObject<LuaSky>(L, 1);
	if (!ref || !ref->m_sky) return 0;
	const auto &c = ref->m_sky->getCloudColor();
	push_ARGB8(L, c.toSColor());
	return 1;
}

int LuaSky::gc_object(lua_State *L)
{
	auto *o = *(LuaSky **)(lua_touserdata(L, 1));
	delete o;
	return 0;
}

void LuaSky::Register(lua_State *L)
{
	static const luaL_Reg metamethods[] = {
		{"__gc", gc_object},
		{0, 0}
	};
	registerClass<LuaSky>(L, methods, metamethods);
}

const char LuaSky::className[] = "Sky";
const luaL_Reg LuaSky::methods[] = {
	luamethod(LuaSky, set_sun_visible),
	luamethod(LuaSky, set_moon_visible),
	luamethod(LuaSky, set_stars_visible),
	luamethod(LuaSky, set_star_count),
	luamethod(LuaSky, set_star_color),
	luamethod(LuaSky, set_star_scale),
	luamethod(LuaSky, set_sun_scale),
	luamethod(LuaSky, set_moon_scale),
	luamethod(LuaSky, set_body_orbit_tilt),
	luamethod(LuaSky, set_clouds_enabled),
	luamethod(LuaSky, set_fog_distance),
	luamethod(LuaSky, set_fog_start),
	luamethod(LuaSky, set_fog_color),
	luamethod(LuaSky, get_brightness),
	luamethod(LuaSky, get_sun_direction),
	luamethod(LuaSky, get_moon_direction),
	luamethod(LuaSky, get_cloud_color),
	{0, 0}
};
