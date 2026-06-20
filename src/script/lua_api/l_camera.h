// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright (C) 2013-2017 celeron55, Perttu Ahola <celeron55@gmail.com>

#pragma once

#include "l_base.h"
#include <vector>

class Camera;
namespace scene { class ISceneNode; }

struct Nametag;

class LuaCamera : public ModApiBase
{
private:
	static const luaL_Reg methods[];

	// garbage collector
	static int gc_object(lua_State *L);

	static int l_set_camera_mode(lua_State *L);
	static int l_get_camera_mode(lua_State *L);

	static int l_get_fov(lua_State *L);

	static int l_get_pos(lua_State *L);
	static int l_get_offset(lua_State *L);
	static int l_get_look_dir(lua_State *L);
	static int l_get_look_vertical(lua_State *L);
	static int l_get_look_horizontal(lua_State *L);
	static int l_get_aspect_ratio(lua_State *L);

	// Nametag API
	static int l_add_nametag(lua_State *L);
	static int l_remove_nametag(lua_State *L);
	static int l_clear_nametags(lua_State *L);

	static Camera *getobject(LuaCamera *ref);
	static Camera *getobject(lua_State *L, int narg);

	struct LuaNametagEntry {
		u32 id;
		scene::ISceneNode *node;
		Nametag *tag;
	};
	std::vector<LuaNametagEntry> m_nametags;
	u32 m_next_nametag_id = 1;

	Camera *m_camera = nullptr;

public:
	LuaCamera(Camera *m);
	~LuaCamera();

	static void create(lua_State *L, Camera *m);

	static void Register(lua_State *L);

	static const char className[];
};
