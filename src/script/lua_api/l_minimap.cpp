// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright (C) 2017 Loic Blot <loic.blot@unix-experience.fr>


#include "lua_api/l_minimap.h"
#include "lua_api/l_internal.h"
#include "common/c_converter.h"
#include "client/client.h"
#include "client/minimap.h"
#include "settings.h"

LuaMinimap::LuaMinimap(Minimap *m) : m_minimap(m)
{
}

void LuaMinimap::create(lua_State *L, Minimap *m)
{
	LuaMinimap *o = new LuaMinimap(m);
	*(void **)(lua_newuserdata(L, sizeof(void *))) = o;
	luaL_getmetatable(L, className);
	lua_setmetatable(L, -2);

	// Keep minimap object stack id
	int minimap_object = lua_gettop(L);

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "ui");
	luaL_checktype(L, -1, LUA_TTABLE);
	int uitable = lua_gettop(L);

	lua_pushvalue(L, minimap_object); // Copy object to top of stack
	lua_setfield(L, uitable, "minimap");
}

int LuaMinimap::l_get_pos(lua_State *L)
{
	LuaMinimap *ref = checkObject<LuaMinimap>(L, 1);
	Minimap *m = getobject(ref);

	push_v3s16(L, m->getPos());
	return 1;
}

int LuaMinimap::l_set_pos(lua_State *L)
{
	LuaMinimap *ref = checkObject<LuaMinimap>(L, 1);
	Minimap *m = getobject(ref);

	m->setPos(read_v3s16(L, 2));
	return 1;
}

int LuaMinimap::l_get_angle(lua_State *L)
{
	LuaMinimap *ref = checkObject<LuaMinimap>(L, 1);
	Minimap *m = getobject(ref);

	lua_pushinteger(L, m->getAngle());
	return 1;
}

int LuaMinimap::l_set_angle(lua_State *L)
{
	LuaMinimap *ref = checkObject<LuaMinimap>(L, 1);
	Minimap *m = getobject(ref);

	m->setAngle(lua_tointeger(L, 2));
	return 1;
}

int LuaMinimap::l_get_mode(lua_State *L)
{
	LuaMinimap *ref = checkObject<LuaMinimap>(L, 1);
	Minimap *m = getobject(ref);

	lua_pushinteger(L, m->getModeIndex());
	return 1;
}

int LuaMinimap::l_set_mode(lua_State *L)
{
	LuaMinimap *ref = checkObject<LuaMinimap>(L, 1);
	Minimap *m = getobject(ref);

	u32 mode = lua_tointeger(L, 2);
	if (mode >= m->getMaxModeIndex())
		return 0;

	m->setModeIndex(mode);
	return 1;
}

int LuaMinimap::l_set_shape(lua_State *L)
{
	LuaMinimap *ref = checkObject<LuaMinimap>(L, 1);
	Minimap *m = getobject(ref);
	if (!lua_isnumber(L, 2))
		return 0;

	m->setMinimapShape((MinimapShape)((int)lua_tonumber(L, 2)));
	return 0;
}

int LuaMinimap::l_get_shape(lua_State *L)
{
	LuaMinimap *ref = checkObject<LuaMinimap>(L, 1);
	Minimap *m = getobject(ref);

	lua_pushnumber(L, (int)m->getMinimapShape());
	return 1;
}

int LuaMinimap::l_show(lua_State *L)
{
	// If minimap is disabled by config, don't show it.
	if (!g_settings->getBool("enable_minimap"))
		return 1;

	LuaMinimap *ref = checkObject<LuaMinimap>(L, 1);
	Minimap *m = getobject(ref);

	// This is not very adapted to new minimap mode management. Btw, tried
	// to do something compatible.

	if (m->getModeIndex() == 0 && m->getMaxModeIndex() > 0)
		m->setModeIndex(1);

	return 1;
}

int LuaMinimap::l_hide(lua_State *L)
{
	LuaMinimap *ref = checkObject<LuaMinimap>(L, 1);
	Minimap *m = getobject(ref);

	// This is not very adapted to new minimap mode management. Btw, tried
	// to do something compatible.

	if (m->getModeIndex() != 0)
		m->setModeIndex(0);

	return 1;
}

// add_marker(self, {pos={...}, color=...})
int LuaMinimap::l_add_marker(lua_State *L)
{
	LuaMinimap *ref = checkObject<LuaMinimap>(L, 1);
	Minimap *m = getobject(ref);

	luaL_checktype(L, 2, LUA_TTABLE);

	lua_getfield(L, 2, "pos");
	v3f posf = check_v3f(L, -1);
	lua_pop(L, 1);
	// Positions are in node coordinates (see read_v3s16), not BS units.
	// Use s32 so waypoints beyond int16 range keep their direction.
	v3s32 pos = v3s32(
		(s32)std::floor(posf.X + 0.5f),
		(s32)std::floor(posf.Y + 0.5f),
		(s32)std::floor(posf.Z + 0.5f));

	video::SColor color(255, 255, 0, 0);
	lua_getfield(L, 2, "color");
	if (lua_isstring(L, -1))
		read_color(L, -1, &color);
	lua_pop(L, 1);

	u32 id = m->addLuaMarker(pos, color);
	lua_pushinteger(L, (lua_Integer)id);
	return 1;
}

// remove_marker(self, id)
int LuaMinimap::l_remove_marker(lua_State *L)
{
	LuaMinimap *ref = checkObject<LuaMinimap>(L, 1);
	Minimap *m = getobject(ref);

	u32 id = (u32)luaL_checkinteger(L, 2);
	bool ok = m->removeLuaMarker(id);
	lua_pushboolean(L, ok);
	return 1;
}

// clear_markers(self)
int LuaMinimap::l_clear_markers(lua_State *L)
{
	LuaMinimap *ref = checkObject<LuaMinimap>(L, 1);
	Minimap *m = getobject(ref);

	m->clearLuaMarkers();
	return 0;
}

Minimap* LuaMinimap::getobject(LuaMinimap *ref)
{
	return ref->m_minimap;
}

int LuaMinimap::gc_object(lua_State *L) {
	LuaMinimap *o = *(LuaMinimap **)(lua_touserdata(L, 1));
	delete o;
	return 0;
}

void LuaMinimap::Register(lua_State *L)
{
	static const luaL_Reg metamethods[] = {
		{"__gc", gc_object},
		{0, 0}
	};
	registerClass<LuaMinimap>(L, methods, metamethods);
}

const char LuaMinimap::className[] = "Minimap";
const luaL_Reg LuaMinimap::methods[] = {
	luamethod(LuaMinimap, show),
	luamethod(LuaMinimap, hide),
	luamethod(LuaMinimap, get_pos),
	luamethod(LuaMinimap, set_pos),
	luamethod(LuaMinimap, get_angle),
	luamethod(LuaMinimap, set_angle),
	luamethod(LuaMinimap, get_mode),
	luamethod(LuaMinimap, set_mode),
	luamethod(LuaMinimap, set_shape),
	luamethod(LuaMinimap, get_shape),
	luamethod(LuaMinimap, add_marker),
	luamethod(LuaMinimap, remove_marker),
	luamethod(LuaMinimap, clear_markers),
	{0,0}
};
