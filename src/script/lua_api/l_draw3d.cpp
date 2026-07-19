// Antilua — Lua 3D drawing API
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "lua_api/l_draw3d.h"
#include "lua_api/l_internal.h"
#include "common/c_converter.h"
#include "client/render/al_draw_shapes.h"
#include "constants.h"
#include "SColor.h"

const char LuaDraw3D::className[] = "Draw3D";

void LuaDraw3D::create(lua_State *L)
{
	auto *o = new LuaDraw3D();
	*(void **)(lua_newuserdata(L, sizeof(void *))) = o;
	luaL_getmetatable(L, className);
	lua_setmetatable(L, -2);

	lua_getglobal(L, "core");
	luaL_checktype(L, -1, LUA_TTABLE);
	int core_table = lua_gettop(L);

	lua_pushvalue(L, -2);
	lua_setfield(L, core_table, "draw3d");
	lua_pop(L, 2);
}

int LuaDraw3D::gc_object(lua_State *L)
{
	auto *o = *(LuaDraw3D **)(lua_touserdata(L, 1));
	delete o;
	return 0;
}

// add_sphere(self, pos, radius, color [, segments, group_id])
int LuaDraw3D::l_add_sphere(lua_State *L)
{
	v3f pos = check_v3f(L, 2) * BS;
	f32 radius = luaL_checknumber(L, 3) * BS;
	video::SColor color(255, 255, 255, 255);
	if (!lua_isnoneornil(L, 4))
		read_color(L, 4, &color);
	u32 segments = lua_isnumber(L, 5) ? (u32)lua_tonumber(L, 5) : 24;
	s32 group_id = lua_isnumber(L, 6) ? (s32)lua_tonumber(L, 6) : -1;

	DrawShapeCommand cmd;
	cmd.type = DrawShapeCommand::Type::Sphere;
	cmd.pos = pos;
	cmd.radius = radius;
	cmd.color = color;
	cmd.segments = segments;
	cmd.group_id = group_id;
	DrawLuaShapes::addCommand(cmd);
	return 0;
}

// add_wiresphere(self, pos, radius, color [, segments, group_id])
int LuaDraw3D::l_add_wiresphere(lua_State *L)
{
	v3f pos = check_v3f(L, 2) * BS;
	f32 radius = luaL_checknumber(L, 3) * BS;
	video::SColor color(255, 255, 255, 255);
	if (!lua_isnoneornil(L, 4))
		read_color(L, 4, &color);
	u32 segments = lua_isnumber(L, 5) ? (u32)lua_tonumber(L, 5) : 24;
	s32 group_id = lua_isnumber(L, 6) ? (s32)lua_tonumber(L, 6) : -1;

	DrawShapeCommand cmd;
	cmd.type = DrawShapeCommand::Type::Sphere;
	cmd.pos = pos;
	cmd.radius = radius;
	cmd.color = color;
	cmd.segments = segments;
	cmd.group_id = group_id;
	cmd.wireframe = true;
	DrawLuaShapes::addCommand(cmd);
	return 0;
}

// add_box(self, minp, maxp, color [, group_id])
int LuaDraw3D::l_add_box(lua_State *L)
{
	v3f minp = check_v3f(L, 2) * BS;
	v3f maxp = check_v3f(L, 3) * BS;
	video::SColor color(255, 255, 255, 255);
	if (!lua_isnoneornil(L, 4))
		read_color(L, 4, &color);
	s32 group_id = lua_isnumber(L, 5) ? (s32)lua_tonumber(L, 5) : -1;

	DrawShapeCommand cmd;
	cmd.type = DrawShapeCommand::Type::Box;
	cmd.pos = minp;
	cmd.pos2 = maxp;
	cmd.color = color;
	cmd.group_id = group_id;
	DrawLuaShapes::addCommand(cmd);
	return 0;
}

// add_wirebox(self, minp, maxp, color [, group_id])
int LuaDraw3D::l_add_wirebox(lua_State *L)
{
	v3f minp = check_v3f(L, 2) * BS;
	v3f maxp = check_v3f(L, 3) * BS;
	video::SColor color(255, 255, 255, 255);
	if (!lua_isnoneornil(L, 4))
		read_color(L, 4, &color);
	s32 group_id = lua_isnumber(L, 5) ? (s32)lua_tonumber(L, 5) : -1;

	DrawShapeCommand cmd;
	cmd.type = DrawShapeCommand::Type::WireBox;
	cmd.pos = minp;
	cmd.pos2 = maxp;
	cmd.color = color;
	cmd.group_id = group_id;
	DrawLuaShapes::addCommand(cmd);
	return 0;
}

// add_line(self, from, to, color [, group_id])
int LuaDraw3D::l_add_line(lua_State *L)
{
	v3f from = check_v3f(L, 2) * BS;
	v3f to = check_v3f(L, 3) * BS;
	video::SColor color(255, 255, 255, 255);
	if (!lua_isnoneornil(L, 4))
		read_color(L, 4, &color);
	s32 group_id = lua_isnumber(L, 5) ? (s32)lua_tonumber(L, 5) : -1;

	DrawShapeCommand cmd;
	cmd.type = DrawShapeCommand::Type::Line;
	cmd.pos = from;
	cmd.pos2 = to;
	cmd.color = color;
	cmd.group_id = group_id;
	DrawLuaShapes::addCommand(cmd);
	return 0;
}

// add_circle(self, pos, radius, color [, segments, group_id])
int LuaDraw3D::l_add_circle(lua_State *L)
{
	v3f pos = check_v3f(L, 2) * BS;
	f32 radius = luaL_checknumber(L, 3) * BS;
	video::SColor color(255, 255, 255, 255);
	if (!lua_isnoneornil(L, 4))
		read_color(L, 4, &color);
	u32 segments = lua_isnumber(L, 5) ? (u32)lua_tonumber(L, 5) : 32;
	s32 group_id = lua_isnumber(L, 6) ? (s32)lua_tonumber(L, 6) : -1;

	DrawShapeCommand cmd;
	cmd.type = DrawShapeCommand::Type::Circle;
	cmd.pos = pos;
	cmd.radius = radius;
	cmd.color = color;
	cmd.segments = segments;
	cmd.group_id = group_id;
	DrawLuaShapes::addCommand(cmd);
	return 0;
}

// clear(self [, group_id])
int LuaDraw3D::l_clear(lua_State *L)
{
	s32 group_id = lua_isnumber(L, 2) ? (s32)lua_tonumber(L, 2) : -1;
	DrawLuaShapes::clear(group_id);
	return 0;
}

const luaL_Reg LuaDraw3D::methods[] = {
	luamethod(LuaDraw3D, add_sphere),
	luamethod(LuaDraw3D, add_wiresphere),
	luamethod(LuaDraw3D, add_box),
	luamethod(LuaDraw3D, add_wirebox),
	luamethod(LuaDraw3D, add_line),
	luamethod(LuaDraw3D, add_circle),
	luamethod(LuaDraw3D, clear),
	{0, 0},
};

void LuaDraw3D::Register(lua_State *L)
{
	static const luaL_Reg metamethods[] = {
		{"__gc", gc_object},
		{0, 0},
	};
	registerClass<LuaDraw3D>(L, methods, metamethods);
}
