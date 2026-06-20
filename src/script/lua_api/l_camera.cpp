// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright (C) 2010-2013 celeron55, Perttu Ahola <celeron55@gmail.com>

#include "l_camera.h"
#include "script/common/c_converter.h"
#include "l_internal.h"
#include "client/content_cao.h"
#include "client/camera.h"
#include "client/client.h"
#include "client/localplayer.h"
#include <ICameraSceneNode.h>
#include <ISceneManager.h>

LuaCamera::LuaCamera(Camera *m) : m_camera(m)
{
}

LuaCamera::~LuaCamera()
{
	for (auto &entry : m_nametags) {
		m_camera->removeNametag(entry.tag);
		if (entry.node)
			entry.node->remove();
	}
	m_nametags.clear();
}

void LuaCamera::create(lua_State *L, Camera *m)
{
	lua_getglobal(L, "core");
	luaL_checktype(L, -1, LUA_TTABLE);
	int objectstable = lua_gettop(L);
	lua_getfield(L, -1, "camera");

	// Duplication check
	if (lua_type(L, -1) == LUA_TUSERDATA) {
		lua_pop(L, 1);
		return;
	}

	LuaCamera *o = new LuaCamera(m);
	*(void **)(lua_newuserdata(L, sizeof(void *))) = o;
	luaL_getmetatable(L, className);
	lua_setmetatable(L, -2);

	lua_pushvalue(L, lua_gettop(L));
	lua_setfield(L, objectstable, "camera");
}

// set_camera_mode(self, mode)
int LuaCamera::l_set_camera_mode(lua_State *L)
{
	Camera *camera = getobject(L, 1);
	GenericCAO *playercao = getClient(L)->getEnv().getLocalPlayer()->getCAO();
	if (!camera)
		return 0;
	sanity_check(playercao);
	if (!lua_isnumber(L, 2))
		return 0;

	camera->setCameraMode((CameraMode)((int)lua_tonumber(L, 2)));
	// Make the player visible depending on camera mode.
	playercao->updateMeshCulling();
	playercao->setChildrenVisible(camera->getCameraMode() > CAMERA_MODE_FIRST);
	return 0;
}

// get_camera_mode(self)
int LuaCamera::l_get_camera_mode(lua_State *L)
{
	Camera *camera = getobject(L, 1);
	if (!camera)
		return 0;

	lua_pushinteger(L, (int)camera->getCameraMode());

	return 1;
}

// get_fov(self)
int LuaCamera::l_get_fov(lua_State *L)
{
	Camera *camera = getobject(L, 1);
	if (!camera)
		return 0;

	lua_newtable(L);
	lua_pushnumber(L, camera->getFovX() * core::RADTODEG);
	lua_setfield(L, -2, "x");
	lua_pushnumber(L, camera->getFovY() * core::RADTODEG);
	lua_setfield(L, -2, "y");
	lua_pushnumber(L, camera->getCameraNode()->getFOV() * core::RADTODEG);
	lua_setfield(L, -2, "actual");
	lua_pushnumber(L, camera->getFovMax() * core::RADTODEG);
	lua_setfield(L, -2, "max");
	return 1;
}

// get_pos(self)
int LuaCamera::l_get_pos(lua_State *L)
{
	Camera *camera = getobject(L, 1);
	if (!camera)
		return 0;

	push_v3f(L, camera->getPosition() / BS);
	return 1;
}

// get_offset(self)
int LuaCamera::l_get_offset(lua_State *L)
{
	LocalPlayer *player = getClient(L)->getEnv().getLocalPlayer();
	sanity_check(player);

	push_v3f(L, player->getEyeOffset() / BS);
	return 1;
}

// get_look_dir(self)
int LuaCamera::l_get_look_dir(lua_State *L)
{
	Camera *camera = getobject(L, 1);
	if (!camera)
		return 0;

	push_v3f(L, camera->getDirection());
	return 1;
}

// get_look_horizontal(self)
// FIXME: wouldn't localplayer be a better place for this?
int LuaCamera::l_get_look_horizontal(lua_State *L)
{
	LocalPlayer *player = getClient(L)->getEnv().getLocalPlayer();
	sanity_check(player);

	lua_pushnumber(L, (player->getYaw() + 90.f) * core::DEGTORAD);
	return 1;
}

// get_look_vertical(self)
// FIXME: wouldn't localplayer be a better place for this?
int LuaCamera::l_get_look_vertical(lua_State *L)
{
	LocalPlayer *player = getClient(L)->getEnv().getLocalPlayer();
	sanity_check(player);

	lua_pushnumber(L, -1.0f * player->getPitch() * core::DEGTORAD);
	return 1;
}

// get_aspect_ratio(self)
int LuaCamera::l_get_aspect_ratio(lua_State *L)
{
	Camera *camera = getobject(L, 1);
	if (!camera)
		return 0;

	lua_pushnumber(L, camera->getCameraNode()->getAspectRatio());
	return 1;
}

// add_nametag(self, {pos={...}, text="...", color=..., bgcolor=..., size=..., scale_z=...})
int LuaCamera::l_add_nametag(lua_State *L)
{
	Camera *camera = getobject(L, 1);
	LuaCamera *self = checkObject<LuaCamera>(L, 1);
	if (!camera || !self)
		return 0;

	luaL_checktype(L, 2, LUA_TTABLE);

	// Read required fields
	lua_getfield(L, 2, "pos");
	v3f pos = check_v3f(L, -1) * BS;
	lua_pop(L, 1);

	lua_getfield(L, 2, "text");
	const char *text = luaL_checkstring(L, -1);
	lua_pop(L, 1);

	// Read optional fields
	video::SColor textcolor(255, 255, 255, 255);
	if (read_color(L, 2, &textcolor))
		textcolor.setAlpha(255);

	video::SColor bgcolor(0, 0, 0, 0);
	bool has_bg = false;
	{
		video::SColor parsed;
		if (read_color(L, 2, &parsed)) {
			// Need to check if there's a color key in the table
			lua_getfield(L, 2, "bgcolor");
			if (!lua_isnil(L, -1)) {
				has_bg = true;
				bgcolor = parsed;
				bgcolor.setAlpha(128);
			}
			lua_pop(L, 1);
		}
	}

	u32 fontsize = 0;
	bool has_fontsize = false;
	lua_getfield(L, 2, "size");
	if (lua_isnumber(L, -1)) {
		fontsize = (u32)lua_tonumber(L, -1);
		has_fontsize = true;
	}
	lua_pop(L, 1);

	bool scale_z = false;
	lua_getfield(L, 2, "scale_z");
	if (lua_isboolean(L, -1))
		scale_z = lua_toboolean(L, -1);
	lua_pop(L, 1);

	// Create scene node for the nametag
	auto *smgr = getClient(L)->getSceneManager();
	scene::ISceneNode *node = smgr->addEmptySceneNode(smgr->getRootSceneNode());
	node->setPosition(pos);

	// Build Nametag
	Nametag ntag;
	ntag.parent_node = node;
	ntag.text = text ? text : "";
	ntag.textcolor = textcolor;
	if (has_bg)
		ntag.bgcolor = bgcolor;
	if (has_fontsize)
		ntag.textsize = fontsize;
	ntag.pos = v3f(0.0f);
	ntag.scale_z = scale_z;

	Nametag *tag = camera->addNametag(ntag);

	// Store
	u32 id = self->m_next_nametag_id++;
	self->m_nametags.push_back({id, node, tag});

	lua_pushinteger(L, (lua_Integer)id);
	return 1;
}

// remove_nametag(self, id)
int LuaCamera::l_remove_nametag(lua_State *L)
{
	Camera *camera = getobject(L, 1);
	LuaCamera *self = checkObject<LuaCamera>(L, 1);
	if (!camera || !self)
		return 0;

	u32 id = (u32)luaL_checkinteger(L, 2);

	for (auto it = self->m_nametags.begin(); it != self->m_nametags.end(); ++it) {
		if (it->id == id) {
			camera->removeNametag(it->tag);
			if (it->node)
				it->node->remove();
			self->m_nametags.erase(it);
			lua_pushboolean(L, true);
			return 1;
		}
	}

	lua_pushboolean(L, false);
	return 1;
}

// clear_nametags(self)
int LuaCamera::l_clear_nametags(lua_State *L)
{
	Camera *camera = getobject(L, 1);
	LuaCamera *self = checkObject<LuaCamera>(L, 1);
	if (!camera || !self)
		return 0;

	for (auto &entry : self->m_nametags) {
		camera->removeNametag(entry.tag);
		if (entry.node)
			entry.node->remove();
	}
	self->m_nametags.clear();

	return 0;
}

Camera *LuaCamera::getobject(LuaCamera *ref)
{
	return ref->m_camera;
}

Camera *LuaCamera::getobject(lua_State *L, int narg)
{
	LuaCamera *ref = checkObject<LuaCamera>(L, narg);
	assert(ref);
	return getobject(ref);
}

int LuaCamera::gc_object(lua_State *L)
{
	LuaCamera *o = *(LuaCamera **)(lua_touserdata(L, 1));
	delete o;
	return 0;
}

void LuaCamera::Register(lua_State *L)
{
	static const luaL_Reg metamethods[] = {
		{"__gc", gc_object},
		{0, 0}
	};
	registerClass<LuaCamera>(L, methods, metamethods);
}

const char LuaCamera::className[] = "Camera";
const luaL_Reg LuaCamera::methods[] = {
	luamethod(LuaCamera, set_camera_mode),
	luamethod(LuaCamera, get_camera_mode),
	luamethod(LuaCamera, get_fov),
	luamethod(LuaCamera, get_pos),
	luamethod(LuaCamera, get_offset),
	luamethod(LuaCamera, get_look_dir),
	luamethod(LuaCamera, get_look_vertical),
	luamethod(LuaCamera, get_look_horizontal),
	luamethod(LuaCamera, get_aspect_ratio),

	luamethod(LuaCamera, add_nametag),
	luamethod(LuaCamera, remove_nametag),
	luamethod(LuaCamera, clear_nametags),

	{0, 0}
};
