/*
Minetest
Copyright (C) 2013 celeron55, Perttu Ahola <celeron55@gmail.com>
Copyright (C) 2017 nerzhul, Loic Blot <loic.blot@unix-experience.fr>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

#include "l_client.h"
#include "chatmessage.h"
#include "constants.h"
#include "network/connection.h"
#include "script/scripting_client.h"
#include "client/renderingengine.h"
#include <IFileSystem.h>
#include <IReadFile.h>
#include "client/session.h"
#include "itemdef.h"
#include "client/client.h"
#include "client/clientevent.h"
#include "client/sound.h"
#include "client/clientenvironment.h"
#include "client/game.h"
#include "client/game_internal.h"
#include "client/game_formspec.h"
#include "client/localplayer.h"
#include "common/c_content.h"
#include "common/c_converter.h"
#include "cpp_api/s_base.h"
#include "gettext.h"
#include "l_internal.h"
#include "l_clientobject.h"
#include "lua_api/l_nodemeta.h"
#include "gui/mainmenumanager.h"
#include "gui/toastManager.h"
#include "map.h"
#include "filesys.h"
#include "util/string.h"
#include "content/mods.h"
#include "nodedef.h"
#include "client/keycode.h"
#include "client/clientmap.h"
#include "client/content_cao.h"
#include "client/gameui.h"
#include "server.h"
#include "porting.h"
#include "settings.h"
#include "collision.h"
#include "face_position_cache.h"
#include "util/basic_macros.h"
#include "mapgen/mg_schematic.h"
#include "serialization.h"
#include "util/serialize.h"

#define checkCSMRestrictionFlag(flag) \
	( getClient(L)->checkCSMRestrictionFlag(CSMRestrictionFlags::flag) )

// Not the same as FlagDesc, which contains an `u32 flag`
struct CSMFlagDesc {
	const char *name;
	u64 flag;
};

/*
	FIXME: This should eventually be moved somewhere else
	It also needs to be kept in sync with the definition of CSMRestrictionFlags
	in network/networkprotocol.h
*/
const static CSMFlagDesc flagdesc_csm_restriction[] = {
	{"load_client_mods",  CSM_RF_LOAD_CLIENT_MODS},
	{"chat_messages",     CSM_RF_CHAT_MESSAGES},
	{"read_itemdefs",     CSM_RF_READ_ITEMDEFS},
	{"read_nodedefs",     CSM_RF_READ_NODEDEFS},
	{"lookup_nodes",      CSM_RF_LOOKUP_NODES},
	{"read_playerinfo",   CSM_RF_READ_PLAYERINFO},
	{NULL,      0}
};

// get_current_modname()
int ModApiClient::l_get_current_modname(lua_State *L)
{
	lua_rawgeti(L, LUA_REGISTRYINDEX, CUSTOM_RIDX_CURRENT_MOD_NAME);
	return 1;
}

// get_modpath(modname)
int ModApiClient::l_get_modpath(lua_State *L)
{
	std::string modname = readParam<std::string>(L, 1);
	// Client mods use a virtual filesystem, see Client::scanModSubfolder()
	std::string path = modname + ":";
	lua_pushstring(L, path.c_str());
	return 1;
}

// get_modpath_real(modname)
int ModApiClient::l_get_modpath_real(lua_State *L)
{
	std::string modname = readParam<std::string>(L, 1);
	Client *client = getClient(L);
	const ModSpec *mod = client->getModSpec(modname);
	if (mod) {
		lua_pushstring(L, mod->path.c_str());
	} else {
		lua_pushnil(L);
	}
	return 1;
}

// get_last_run_mod()
int ModApiClient::l_get_last_run_mod(lua_State *L)
{
	lua_rawgeti(L, LUA_REGISTRYINDEX, CUSTOM_RIDX_CURRENT_MOD_NAME);
	std::string current_mod = readParam<std::string>(L, -1, "");
	if (current_mod.empty()) {
		lua_pop(L, 1);
		lua_pushstring(L, getScriptApiBase(L)->getOrigin().c_str());
	}
	return 1;
}

// set_last_run_mod(modname)
int ModApiClient::l_set_last_run_mod(lua_State *L)
{
	if (!lua_isstring(L, 1))
		return 0;

	const char *mod = lua_tostring(L, 1);
	getScriptApiBase(L)->setOriginDirect(mod);
	lua_pushboolean(L, true);
	return 1;
}

// print(text)
int ModApiClient::l_print(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	std::string text = luaL_checkstring(L, 1);
	rawstream << text << std::endl;
	return 0;
}

// display_chat_message(message)
int ModApiClient::l_display_chat_message(lua_State *L)
{
	if (!lua_isstring(L, 1))
		return 0;

	std::string message = luaL_checkstring(L, 1);
	getClient(L)->pushToChatQueue(new ChatMessage(utf8_to_wide(message)));
	lua_pushboolean(L, true);
	return 1;
}

// send_chat_message(message)
int ModApiClient::l_send_chat_message(lua_State *L)
{
	if (!lua_isstring(L, 1))
		return 0;

	std::string message = luaL_checkstring(L, 1);
	getClient(L)->sendChatMessage(utf8_to_wide(message));
	return 0;
}

// clear_out_chat_queue()
int ModApiClient::l_clear_out_chat_queue(lua_State *L)
{
	getClient(L)->clearOutChatQueue();
	return 0;
}

// get_player_names()
int ModApiClient::l_get_player_names(lua_State *L)
{
	const std::set<std::string> &plist = getClient(L)->getConnectedPlayerNames();

	lua_newtable(L);
	int i = 1;
	for (const auto &name : plist) {
		lua_pushstring(L, name.c_str());
		lua_rawseti(L, -2, i);
		i++;
	}
	return 1;
}

// show_formspec(formspec)
int ModApiClient::l_show_formspec(lua_State *L)
{
	if (!lua_isstring(L, 1) || !lua_isstring(L, 2))
		return 0;

	ClientEvent *event = new ClientEvent();
	event->type = CE_SHOW_CSM_FORMSPEC;
	event->show_formspec.formname = new std::string(luaL_checkstring(L, 1));
	event->show_formspec.formspec = new std::string(luaL_checkstring(L, 2));
	getClient(L)->pushToEventQueue(event);
	lua_pushboolean(L, true);
	return 1;
}

// send_respawn()
int ModApiClient::l_send_respawn(lua_State *L)
{
	getClient(L)->sendRespawnLegacy();
	return 0;
}

// disconnect()
int ModApiClient::l_disconnect(lua_State *L)
{
	// Stops badly written Lua code form causing boot loops
	if (getClient(L)->isShutdown()) {
		lua_pushboolean(L, false);
		return 1;
	}

	g_gamecallback->disconnect();
	lua_pushboolean(L, true);
	return 1;
}

// gettext(text)
int ModApiClient::l_gettext(lua_State *L)
{
	std::string text = strgettext(std::string(luaL_checkstring(L, 1)));
	lua_pushstring(L, text.c_str());

	return 1;
}

// get_node_or_nil(pos)
// pos = {x=num, y=num, z=num}
int ModApiClient::l_get_node_or_nil(lua_State *L)
{
	// pos
	v3s16 pos = read_v3s16(L, 1);

	// Do it
	bool pos_ok;
	MapNode n = getClient(L)->CSMGetNode(pos, &pos_ok);
	if (pos_ok) {
		// Return node
		pushnode(L, n);
	} else {
		lua_pushnil(L);
	}
	return 1;
}

// find_nodes_near(pos, radius, nodenames, search_center) -> {pos,...}
int ModApiClient::l_find_nodes_near(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;

	v3s16 pos = read_v3s16(L, 1);
	int radius = luaL_checkinteger(L, 2);
	int start_radius = (lua_isboolean(L, 4) && readParam<bool>(L, 4)) ? 0 : 1;

	Client *client = getClient(L);
	radius = client->CSMClampRadius(pos, radius);

	const NodeDefManager *ndef = client->getNodeDefManager();
	std::vector<content_t> filter;
	if (lua_istable(L, 3)) {
		LuaHelper::for_ipairs(L, 3, [&]() {
			luaL_checktype(L, -1, LUA_TSTRING);
			ndef->getIds(readParam<std::string>(L, -1), filter);
		});
	} else if (lua_isstring(L, 3)) {
		ndef->getIds(readParam<std::string>(L, 3), filter);
	}

	lua_newtable(L);
	int table_idx = lua_gettop(L);
	u32 index = 1;

	for (int d = start_radius; d <= radius; d++) {
		const std::vector<v3s16> &list = FacePositionCache::getFacePositions(d);
		for (const v3s16 &p : list) {
			v3s16 check_pos = pos + p;
			bool pos_ok;
			content_t c = client->CSMGetNode(check_pos, &pos_ok).getContent();
			if (pos_ok && CONTAINS(filter, c)) {
				push_v3s16(L, check_pos);
				lua_rawseti(L, table_idx, index++);
			}
		}
	}

	return 1;
}

// get_langauge()
int ModApiClient::l_get_language(lua_State *L)
{
#ifdef _WIN32
	char *locale = setlocale(LC_ALL, NULL);
#else
	char *locale = setlocale(LC_MESSAGES, NULL);
#endif
	std::string lang = gettext("LANG_CODE");
	if (lang == "LANG_CODE")
		lang = "";

	lua_pushstring(L, locale);
	lua_pushstring(L, lang.c_str());
	return 2;
}

// get_meta(pos)
int ModApiClient::l_get_meta(lua_State *L)
{
	v3s16 p = read_v3s16(L, 1);

	// check restrictions first
	bool pos_ok;
	getClient(L)->CSMGetNode(p, &pos_ok);
	if (!pos_ok)
		return 0;

	NodeMetadata *meta = getEnv(L)->getMap().getNodeMetadata(p);
	NodeMetaRef::createClient(L, meta);
	return 1;
}

// sound_play(spec, parameters) — FIXME: luanti's ISoundManager API differs
int ModApiClient::l_sound_play(lua_State *L)
{
	lua_pushinteger(L, -1);
	return 1;
}

// sound_stop(handle)
int ModApiClient::l_sound_stop(lua_State *L)
{
	return 0;
}

// sound_fade(handle, step, gain)
int ModApiClient::l_sound_fade(lua_State *L)
{
	return 0;
}

// get_server_info()
int ModApiClient::l_get_server_info(lua_State *L)
{
	Client *client = getClient(L);
	Address serverAddress = client->getServerAddress();
	lua_newtable(L);
	lua_pushstring(L, client->getAddressName().c_str());
	lua_setfield(L, -2, "address");
	lua_pushstring(L, serverAddress.serializeString().c_str());
	lua_setfield(L, -2, "ip");
	lua_pushinteger(L, serverAddress.getPort());
	lua_setfield(L, -2, "port");
	lua_pushinteger(L, client->getProtoVersion());
	lua_setfield(L, -2, "protocol_version");
	return 1;
}

// get_item_def(itemstring)
int ModApiClient::l_get_item_def(lua_State *L)
{
	IGameDef *gdef = getGameDef(L);
	assert(gdef);

	IItemDefManager *idef = gdef->idef();
	assert(idef);

	if (!lua_isstring(L, 1))
		return 0;

	std::string name = readParam<std::string>(L, 1);
	if (!idef->isKnown(name))
		return 0;
	const ItemDefinition &def = idef->get(name);

	push_item_definition_full(L, def);

	return 1;
}

// get_node_def(nodename)
int ModApiClient::l_get_node_def(lua_State *L)
{
	IGameDef *gdef = getGameDef(L);
	assert(gdef);

	const NodeDefManager *ndef = gdef->ndef();
	assert(ndef);

	if (!lua_isstring(L, 1))
		return 0;

	std::string name = readParam<std::string>(L, 1);
	const ContentFeatures &cf = ndef->get(ndef->getId(name));
	if (cf.name != name) // Unknown node. | name = <whatever>, cf.name = ignore
		return 0;

	push_content_features(L, cf);

	return 1;
}

// get_privilege_list()
int ModApiClient::l_get_privilege_list(lua_State *L)
{
	const Client *client = getClient(L);
	lua_newtable(L);
	for (const std::string &priv : client->getPrivilegeList()) {
		lua_pushboolean(L, true);
		lua_setfield(L, -2, priv.c_str());
	}
	return 1;
}

// get_builtin_path()
int ModApiClient::l_get_builtin_path(lua_State *L)
{
	// SSCSM uses "*client_builtin*", regular client uses "*builtin*"
	if (getScriptApiBase(L)->getType() == ScriptingType::SSCSM)
		lua_pushstring(L, "*client_builtin*:");
	else
		lua_pushstring(L, BUILTIN_MOD_NAME ":");
	return 1;
}

// get_csm_restrictions()
int ModApiClient::l_get_csm_restrictions(lua_State *L)
{
	u64 flags = getClient(L)->getCSMRestrictionFlags();
	const CSMFlagDesc *flagdesc = flagdesc_csm_restriction;

	lua_newtable(L);
	for (int i = 0; flagdesc[i].name; i++) {
		setboolfield(L, -1, flagdesc[i].name, !!(flags & flagdesc[i].flag));
	}
	return 1;
}

// send_damage(damage)
int ModApiClient::l_send_damage(lua_State *L)
{
	u16 damage = luaL_checknumber(L, 1);
	getClient(L)->sendDamage(damage);
	return 0;
}

// place_node(pos)
int ModApiClient::l_place_node(lua_State *L)
{
	Client *client = getClient(L);
	ClientMap &map = client->getEnv().getClientMap();
	LocalPlayer *player = client->getEnv().getLocalPlayer();
	ItemStack selected_item, hand_item;
	player->getWieldedItem(&selected_item, &hand_item);
	const ItemDefinition &selected_def = selected_item.getDefinition(getGameDef(L)->idef());
	v3s16 pos = read_v3s16(L, 1);
	NodeMetadata *meta = map.getNodeMetadata(pos);
	v3f intersection_point = intToFloat(pos, BS);
	PointedThing pointed(pos, pos, pos, intersection_point, v3f(0, 0, 0), 0, 0, PointabilityType::POINTABLE_NOT);
	g_game->nodePlacement(selected_def, selected_item, pos, pos, pointed, meta);
	return 0;
}

// dig_node(pos)
int ModApiClient::l_dig_node(lua_State *L)
{
	Client *client = getClient(L);
	v3s16 pos = read_v3s16(L, 1);
	v3f intersection_point = intToFloat(pos, BS);
	PointedThing pointed(pos, pos, pos, intersection_point, v3f(0, 0, 0), 0, 0, PointabilityType::POINTABLE_NOT);
	client->interact(INTERACT_START_DIGGING, pointed);
	client->interact(INTERACT_DIGGING_COMPLETED, pointed);
	client->removeNode(pos);
	return 0;
}

// get_inventory(location)
int ModApiClient::l_get_inventory(lua_State *L)
{
	Client *client = getClient(L);
	InventoryLocation inventory_location;
	Inventory *inventory;
	std::string location;

	location = readParam<std::string>(L, 1);

	try {
		inventory_location.deSerialize(location);
		inventory = client->getInventory(inventory_location);
		if (! inventory)
			throw SerializationError(std::string("Attempt to access nonexistant inventory (") + location + ")");
		push_inventory_lists(L, *inventory);
	} catch (SerializationError &) {
		lua_pushnil(L);
	}

	return 1;
}

// set_keypress(key_setting, pressed) -> returns true on success
int ModApiClient::l_set_keypress(lua_State *L)
{
	std::string setting_name = "keymap_" + readParam<std::string>(L, 1);
	bool pressed = lua_isboolean(L, 2) && readParam<bool>(L, 2);
	try {
		const auto keylist = getKeySetting(setting_name.c_str());
		KeyPress keyCode = keylist.empty() ? KeyPress() : keylist[0];
		if (pressed)
			g_game->getInput()->setKeypress(keyCode);
		else
			g_game->getInput()->unsetKeypress(keyCode);
		lua_pushboolean(L, true);
	} catch (SettingNotFoundException &) {
		lua_pushboolean(L, false);
	}
	return 1;
}

// drop_selected_item()
int ModApiClient::l_drop_selected_item(lua_State *L)
{
	g_game->dropSelectedItem();
	return 0;
}

// get_objects_inside_radius(pos, radius)
int ModApiClient::l_get_objects_inside_radius(lua_State *L)
{
	ClientEnvironment &env = getClient(L)->getEnv();

	v3f pos = checkFloatPos(L, 1);
	float radius = readParam<float>(L, 2) * BS;

	std::vector<DistanceSortedActiveObject> objs;
	env.getActiveObjects(pos, radius, objs);

	int i = 0;
	lua_createtable(L, objs.size(), 0);
	for (const auto obj : objs) {
		push_objectRef(L, obj.obj->getId());
		lua_rawseti(L, -2, ++i);
	}
	return 1;
}

// make_screenshot()
int ModApiClient::l_make_screenshot(lua_State *L)
{
	auto filename = getClient(L)->makeScreenshot();
	if (!filename.empty()) {
		// return just the basename (no path) for formspec use
		auto pos = filename.rfind("/");
		if (pos == std::string::npos)
			pos = filename.rfind("\\");
		if (pos != std::string::npos)
			filename = filename.substr(pos + 1);
		lua_pushstring(L, filename.c_str());
		return 1;
	}
	return 0;
}

/*
`pointed_thing`
---------------

* `{type="nothing"}`
* `{type="node", under=pos, above=pos}`
    * Indicates a pointed node selection box.
    * `under` refers to the node position behind the pointed face.
    * `above` refers to the node position in front of the pointed face.
* `{type="object", ref=ObjectRef}`

Exact pointing location (currently only `Raycast` supports these fields):

* `pointed_thing.intersection_point`: The absolute world coordinates of the
  point on the selection box which is pointed at. May be in the selection box
  if the pointer is in the box too.
* `pointed_thing.box_id`: The ID of the pointed selection box (counting starts
  from 1).
* `pointed_thing.intersection_normal`: Unit vector, points outwards of the
  selected selection box. This specifies which face is pointed at.
  Is a null vector `{x = 0, y = 0, z = 0}` when the pointer is inside the
  selection box.
*/

// interact(action, pointed_thing)
int ModApiClient::l_interact(lua_State *L)
{
	std::string action_str = readParam<std::string>(L, 1);
	InteractAction action;

	if (action_str == "start_digging")
		action = INTERACT_START_DIGGING;
	else if (action_str == "stop_digging")
		action = INTERACT_STOP_DIGGING;
	else if (action_str == "digging_completed")
		action = INTERACT_DIGGING_COMPLETED;
	else if (action_str == "place")
		action = INTERACT_PLACE;
	else if (action_str == "use")
		action = INTERACT_USE;
	else if (action_str == "activate")
		action = INTERACT_ACTIVATE;
	else
		return 0;

	lua_getfield(L, 2, "type");
	if (! lua_isstring(L, -1))
		return 0;
	std::string type_str = lua_tostring(L, -1);
	lua_pop(L, 1);

	PointedThingType type;

	if (type_str == "nothing")
		type = POINTEDTHING_NOTHING;
	else if (type_str == "node")
		type = POINTEDTHING_NODE;
	else if (type_str == "object")
		type = POINTEDTHING_OBJECT;
	else
		return 0;

	switch (type) {
	case POINTEDTHING_NODE: {
		lua_getfield(L, 2, "under");
		v3s16 under = check_v3s16(L, -1);
		lua_getfield(L, 2, "above");
		v3s16 above = check_v3s16(L, -1);
		v3f point = intToFloat(under, BS);
		PointedThing pointed(under, above, under, point, v3f(0, 0, 0), 0, 0, PointabilityType::POINTABLE_NOT);
		getClient(L)->interact(action, pointed);
		lua_pushboolean(L, true);
		return 1;
	}
	case POINTEDTHING_OBJECT: {
		lua_getfield(L, 2, "ref");
		ClientObjectRef *obj = ClientObjectRef::checkobject(L, -1);
		u16 id = obj->getClientActiveObject()->getId();
		PointedThing pointed(id, v3f(0, 0, 0), v3f(0, 0, 0), v3f(0, 0, 0), 0, PointabilityType::POINTABLE_NOT);
		getClient(L)->interact(action, pointed);
		lua_pushboolean(L, true);
		return 1;
	}
	default:
		getClient(L)->interact(action, PointedThing());
		lua_pushboolean(L, true);
		return 1;
	}
}

StringMap *table_to_stringmap(lua_State *L, int index)
{
	StringMap *m = new StringMap;

	lua_pushvalue(L, index);
	lua_pushnil(L);

	while (lua_next(L, -2)) {
		lua_pushvalue(L, -2);
		std::basic_string<char> key = lua_tostring(L, -1);
		std::basic_string<char> value = lua_tostring(L, -2);
		(*m)[key] = value;
		lua_pop(L, 2);
	}

	lua_pop(L, 1);

	return m;
}

// send_inventory_fields(formname, fields)
// Only works if the inventory form was opened beforehand.
int ModApiClient::l_send_inventory_fields(lua_State *L)
{
	std::string formname = luaL_checkstring(L, 1);
	StringMap *fields = table_to_stringmap(L, 2);

	getClient(L)->sendInventoryFields(formname, *fields);
	return 0;
}

// send_nodemeta_fields(position, formname, fields)
int ModApiClient::l_send_nodemeta_fields(lua_State *L)
{
	v3s16 pos = check_v3s16(L, 1);
	std::string formname = luaL_checkstring(L, 2);
	StringMap *m = table_to_stringmap(L, 3);

	getClient(L)->sendNodemetaFields(pos, formname, *m);
	return 0;
}

// read_file(path)
int ModApiClient::l_read_file(lua_State *L)
{
	std::string path = luaL_checkstring(L, 1);
	// Prevent directory traversal
	if (path.find("..") != std::string::npos) {
		lua_pushnil(L);
		lua_pushstring(L, "Path traversal denied");
		return 2;
	}
	// Try as-is first, then relative to share path (for RUN_IN_PLACE setups
	// where cwd may be bin/ instead of the project root)
	std::string content;
	if (fs::ReadFile(path, content)) {
		lua_pushlstring(L, content.data(), content.size());
		return 1;
	}
	// Try relative to share path
	std::string alt = porting::path_share + DIR_DELIM + path;
	if (fs::ReadFile(alt, content)) {
		lua_pushlstring(L, content.data(), content.size());
		return 1;
	}
	lua_pushnil(L);
	lua_pushstring(L, "File not found");
	return 2;
}

// decode_image(data)
int ModApiClient::l_decode_image(lua_State *L)
{
	size_t len;
	const char *data = luaL_checklstring(L, 1, &len);
	if (!data || len == 0) {
		lua_pushnil(L);
		lua_pushstring(L, "Empty data");
		return 2;
	}

	auto *device = RenderingEngine::get_raw_device();
	if (!device) {
		lua_pushnil(L);
		lua_pushstring(L, "No rendering device");
		return 2;
	}
	auto *fs = device->getFileSystem();
	auto *vd = device->getVideoDriver();

	auto *memfile = fs->createMemoryReadFile(data, (u32)len,
		"__antilua_decode__");
	if (!memfile) {
		lua_pushnil(L);
		lua_pushstring(L, "Failed to create memory file");
		return 2;
	}

	video::IImage *img = vd->createImageFromFile(memfile);
	memfile->drop();

	if (!img) {
		lua_pushnil(L);
		lua_pushstring(L, "Failed to decode image");
		return 2;
	}

	u32 w = img->getDimension().Width;
	u32 h = img->getDimension().Height;

	// Convert to consistent RGBA format
	video::IImage *rgba_img = img;
	bool needs_drop = false;
	if (img->getColorFormat() != video::ECF_A8R8G8B8) {
		rgba_img = vd->createImage(video::ECF_A8R8G8B8, img->getDimension());
		if (rgba_img) {
			img->copyTo(rgba_img);
			needs_drop = true;
		} else {
			rgba_img = img;
		}
	}

	// Build RGBA byte string
	std::string pixels;
	pixels.reserve((size_t)w * h * 4);
	for (u32 y = 0; y < h; y++) {
		for (u32 x = 0; x < w; x++) {
			video::SColor c = rgba_img->getPixel(x, y);
			pixels.push_back((char)c.getRed());
			pixels.push_back((char)c.getGreen());
			pixels.push_back((char)c.getBlue());
			pixels.push_back((char)c.getAlpha());
		}
	}

	if (needs_drop)
		rgba_img->drop();
	img->drop();

	lua_createtable(L, 0, 3);
	lua_pushinteger(L, (int)w);
	lua_setfield(L, -2, "width");
	lua_pushinteger(L, (int)h);
	lua_setfield(L, -2, "height");
	lua_pushlstring(L, pixels.data(), pixels.size());
	lua_setfield(L, -2, "data");
	return 1;
}

// write_file(path, data)
int ModApiClient::l_write_file(lua_State *L)
{
	std::string path = luaL_checkstring(L, 1);
	// Prevent directory traversal
	if (path.find("..") != std::string::npos) {
		lua_pushnil(L);
		lua_pushstring(L, "Path traversal denied");
		return 2;
	}
	size_t data_len;
	const char *content = luaL_checklstring(L, 2, &data_len);

	if (fs::safeWriteToFile(path, std::string_view(content, data_len))) {
		lua_pushboolean(L, true);
		return 1;
	}

	lua_pushnil(L);
	lua_pushstring(L, "Failed to write file");
	return 2;
}

// get_dir_list(path, is_dir)
int ModApiClient::l_get_dir_list(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;
	const char *path = luaL_checkstring(L, 1);
	if (std::string(path).find("..") != std::string::npos) {
		lua_pushnil(L);
		lua_pushstring(L, "Path traversal denied");
		return 1;
	}
	bool list_all = !lua_isboolean(L, 2);
	bool list_dirs = readParam<bool>(L, 2);
	std::vector<fs::DirListNode> list = fs::GetDirListing(path);
	int index = 0;
	lua_newtable(L);
	for (const fs::DirListNode &dln : list) {
		if (list_all || list_dirs == dln.dir) {
			lua_pushstring(L, dln.name.c_str());
			lua_rawseti(L, -2, ++index);
		}
	}
	return 1;
}

// create_client_entity(pos, properties)
int ModApiClient::l_create_client_entity(lua_State *L)
{
	Client *client = getClient(L);
	ClientEnvironment &env = client->getEnv();

	v3f pos = checkFloatPos(L, 1);

	auto obj = std::make_unique<GenericCAO>(client, &env);
	GenericCAO *raw_obj = obj.get();

	raw_obj->setPos(pos);
	raw_obj->setShadersEnabled(g_settings->getBool("enable_shaders"));
	raw_obj->setVisible(true);

	if (lua_istable(L, 2)) {
		ObjectProperties prop = raw_obj->getProperties();
		read_object_properties(L, 2, nullptr, &prop, client->idef());
		raw_obj->setInitProperties(prop);
	}

	u16 id = env.addActiveObject(std::move(obj));
	if (id == 0)
		return 0;

	ClientActiveObject *cao = env.getActiveObject(id);
	if (!cao)
		return 0;
	ClientObjectRef::create(L, cao);

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "object_refs");
	if (lua_istable(L, -1)) {
		lua_pushvalue(L, -3);
		lua_rawseti(L, -2, id);
	}
	lua_pop(L, 2);

	return 1;
}

// read_schematic(schematic, options)
int ModApiClient::l_read_schematic(lua_State *L)
{
	// If input is a table, parse as schematic def and return canonical form
	if (lua_istable(L, 1)) {
		lua_pushvalue(L, 1);
		return 1;
	}

	// Input must be a string (raw MTS binary data)
	size_t len;
	const char *data = luaL_checklstring(L, 1, &len);
	std::istringstream is(std::string(data, len), std::ios_base::binary);

	// Read + validate signature
	u32 signature = readU32(is);
	if (signature != MTSCHEM_FILE_SIGNATURE)
		throw LuaError("Not a valid MTS file (bad signature)");

	u16 version = readU16(is);
	if (version < 1 || version > MTSCHEM_FILE_VER_HIGHEST_READ)
		throw LuaError("Unsupported MTS version");

	// Read size
	v3s16 size = readV3S16(is);
	u32 nodecount = size.X * size.Y * size.Z;

	// Read Y-slice probabilities
	std::vector<u8> slice_probs(size.Y);
	for (s16 y = 0; y < size.Y; y++)
		slice_probs[y] = (version >= 3) ? readU8(is) : MTSCHEM_PROB_ALWAYS_OLD;

	// Read node name table
	u16 name_count = readU16(is);
	std::vector<std::string> names(name_count);
	for (u16 i = 0; i < name_count; i++)
		names[i] = deSerializeString16(is);

	// Fix old versions
	if (version < 4) {
		for (s16 y = 0; y < size.Y; y++)
			slice_probs[y] >>= 1;
	}

	// Decompress bulk data
	std::stringstream d_ss(std::ios_base::binary | std::ios_base::in | std::ios_base::out);
	decompress(is, d_ss, MTSCHEM_MAPNODE_SER_FMT_VER);
	std::string bulk = d_ss.str();

	// Parse bulk: content_ids (u16), param1 (u8), param2 (u8) per node
	u32 content_size = nodecount * 2;
	const u8 *bp = (const u8 *)bulk.data();
	std::vector<u16> content_ids(nodecount);
	for (u32 i = 0; i < nodecount; i++)
		content_ids[i] = readU16(bp + i * 2);

	const u8 *param1s_src = bp + content_size;
	const u8 *param2s_src = param1s_src + nodecount;

	// Copy to mutable vectors (needed for version < 4 fixup)
	std::vector<u8> param1s(param1s_src, param1s_src + nodecount);
	std::vector<u8> param2s(param2s_src, param2s_src + nodecount);

	// Fix probability range for v1-v3
	if (version < 4) {
		for (u32 i = 0; i < nodecount; i++)
			param1s[i] >>= 1;
	}

	// Build Lua result table
	lua_newtable(L);

	// size field (v3s16 table with x, y, z)
	lua_newtable(L);
	lua_pushinteger(L, size.X); lua_setfield(L, -2, "x");
	lua_pushinteger(L, size.Y); lua_setfield(L, -2, "y");
	lua_pushinteger(L, size.Z); lua_setfield(L, -2, "z");
	lua_setfield(L, -2, "size");

	// yslice_prob field
	lua_newtable(L);
	for (s16 y = 0; y < size.Y; y++) {
		lua_newtable(L);
		lua_pushinteger(L, y); lua_setfield(L, -2, "ypos");
		lua_pushinteger(L, (u32)(slice_probs[y] & MTSCHEM_PROB_MASK) * 2);
		lua_setfield(L, -2, "prob");
		lua_rawseti(L, -2, y + 1);
	}
	lua_setfield(L, -2, "yslice_prob");

	// data field
	lua_newtable(L);
	u32 idx = 1;
	for (s16 z = 0; z < size.Z; z++) {
		for (s16 y = 0; y < size.Y; y++) {
			for (s16 x = 0; x < size.X; x++) {
				u32 i = z * size.Y * size.X + y * size.X + x;
				u16 cid = content_ids[i];
				if (cid >= names.size())
					continue;
				u8 p1 = param1s[i];
				u8 p2 = param2s[i];

				lua_newtable(L);
				lua_pushstring(L, names[cid].c_str());
				lua_setfield(L, -2, "name");
				lua_pushinteger(L, x);
				lua_setfield(L, -2, "x");
				lua_pushinteger(L, y);
				lua_setfield(L, -2, "y");
				lua_pushinteger(L, z);
				lua_setfield(L, -2, "z");
				lua_pushinteger(L, (u32)(p1 & MTSCHEM_PROB_MASK) * 2);
				lua_setfield(L, -2, "prob");
				lua_pushinteger(L, p2);
				lua_setfield(L, -2, "param2");
				if (p1 & MTSCHEM_FORCE_PLACE) {
					lua_pushboolean(L, 1);
					lua_setfield(L, -2, "force_place");
				}
				lua_rawseti(L, -2, idx);
				idx++;
			}
		}
	}
	lua_setfield(L, -2, "data");
	return 1;
}

// serialize_schematic(schematic, format, options)
int ModApiClient::l_serialize_schematic(lua_State *L)
{
	// Get format
	std::string format = "mts";
	if (lua_isstring(L, 2))
		format = lua_tostring(L, 2);

	// Parse input table (size, data, optional yslice_prob)
	luaL_checktype(L, 1, LUA_TTABLE);

	lua_getfield(L, 1, "size");
	v3s16 size = check_v3s16(L, -1);
	lua_pop(L, 1);

	lua_getfield(L, 1, "data");
	luaL_checktype(L, -1, LUA_TTABLE);
	u32 nodecount = size.X * size.Y * size.Z;

	if (format == "lua") {
		// Serialize to Lua table string format
		bool use_comments = getboolfield_default(L, 3, "lua_use_comments", false);
		u32 indent = getintfield_default(L, 3, "lua_num_indent_spaces", 0);

		std::ostringstream os(std::ios_base::binary);
		// Write Lua table
		os << "return {";
		if (use_comments) os << " -- schematic";
		os << "\n";

		os << "size = {x=" << size.X << ",y=" << size.Y << ",z=" << size.Z << "},"; if (use_comments) os << " -- size"; os << "\n";

		os << "data = {";
		std::string indent_str(indent, ' ');
		// Iterate through data array
		for (u32 i = 0; i < nodecount; i++) {
			// Get each entry
			lua_rawgeti(L, -1, i + 1);
			lua_getfield(L, -1, "name");
			std::string name = lua_tostring(L, -1);
			lua_pop(L, 1);

			u8 param1 = MTSCHEM_PROB_ALWAYS;
			u8 param2 = 0;
			bool force_place = false;

			lua_getfield(L, -1, "prob");
			if (lua_isnumber(L, -1))
				param1 = lua_tointeger(L, -1) >> 1;
			lua_pop(L, 1);

			lua_getfield(L, -1, "param2");
			if (lua_isnumber(L, -1))
				param2 = lua_tointeger(L, -1);
			lua_pop(L, 1);

			lua_getfield(L, -1, "force_place");
			if (lua_toboolean(L, -1))
				force_place = true;
			lua_pop(L, 1);

			lua_pop(L, 1); // pop entry

			os << indent_str << "{name=\"" << name << "\",prob=" << (u32)param1 * 2
				<< ",param2=" << (u32)param2;
			if (force_place)
				os << ",force_place=true";
			os << "},";
			if (use_comments && i % 100 == 0)
				os << " -- " << (i + 1) << "/" << nodecount;
			os << "\n";
		}
		os << "},\n}\n";
		lua_pop(L, 1); // pop data table
		std::string result = os.str();
		lua_pushlstring(L, result.data(), result.size());
		return 1;
	}

	// Default: serialize to MTS binary format
	//// Collect unique node names
	std::unordered_map<std::string, u16> name_id_map;
	std::vector<std::string> names;
	std::vector<u16> content_ids(nodecount);
	std::vector<u8> param1s(nodecount);
	std::vector<u8> param2s(nodecount);

	for (u32 i = 0; i < nodecount; i++) {
		lua_rawgeti(L, -1, i + 1);
		luaL_checktype(L, -1, LUA_TTABLE);

		// Read name
		lua_getfield(L, -1, "name");
		std::string name = luaL_checkstring(L, -1);
		lua_pop(L, 1);

		// Insert or lookup name
		auto it = name_id_map.find(name);
		if (it != name_id_map.end()) {
			content_ids[i] = it->second;
		} else {
			u16 id = names.size();
			names.push_back(name);
			name_id_map[name] = id;
			content_ids[i] = id;
		}

		// Read prob/param1
		u8 param1 = MTSCHEM_PROB_ALWAYS;
		lua_getfield(L, -1, "prob");
		if (lua_isnumber(L, -1))
			param1 = lua_tointeger(L, -1) >> 1;
		lua_pop(L, 1);

		// Read force_place
		lua_getfield(L, -1, "force_place");
		if (lua_toboolean(L, -1))
			param1 |= MTSCHEM_FORCE_PLACE;
		lua_pop(L, 1);

		param1s[i] = param1;

		// Read param2
		lua_getfield(L, -1, "param2");
		param2s[i] = lua_isnumber(L, -1) ? lua_tointeger(L, -1) : 0;
		lua_pop(L, 1);

		lua_pop(L, 1); // pop entry
	}
	lua_pop(L, 1); // pop data table

	//// Build MTS binary output
	std::ostringstream os(std::ios_base::binary);

	// Header: signature, version, size
	writeU32(os, MTSCHEM_FILE_SIGNATURE);
	writeU16(os, MTSCHEM_FILE_VER_HIGHEST_WRITE);
	writeU16(os, size.X);
	writeU16(os, size.Y);
	writeU16(os, size.Z);

	// Y-slice probabilities (all always-place)
	for (s16 y = 0; y < size.Y; y++)
		writeU8(os, MTSCHEM_PROB_ALWAYS);

	// Node name table
	writeU16(os, names.size());
	for (u16 i = 0; i < names.size(); i++) {
		writeU16(os, names[i].size());
		os.write(names[i].data(), names[i].size());
	}

	// Bulk node data: all content_ids first, then all param1, then all param2
	u32 content_size = nodecount * 2;
	u32 bulk_size = content_size + nodecount * 2;
	std::vector<u8> bulk(bulk_size, 0);
	for (u32 i = 0; i < nodecount; i++) {
		writeU16(&bulk[i * 2], content_ids[i]);
		bulk[content_size + i] = param1s[i];
		bulk[content_size + nodecount + i] = param2s[i];
	}

	// Compress bulk data
	std::ostringstream cs(std::ios_base::binary);
	compress(bulk.data(), bulk.size(), cs, MTSCHEM_MAPNODE_SER_FMT_VER, -1);
	os << cs.str();

	std::string result = os.str();
	lua_pushlstring(L, result.data(), result.size());
	return 1;
}

// show_toast(text, type)
int ModApiClient::l_show_toast(lua_State *L)
{
	std::string text = luaL_checkstring(L, 1);
	std::string type = luaL_optstring(L, 2, "info");

	auto *tm = getClient(L)->getToastManager();
	if (tm) {
		tm->addToast(utf8_to_wide(text), ToastManager::stringToType(type));
	}
	return 0;
}

// send_raw_packet(command, raw_payload)
int ModApiClient::l_send_raw_packet(lua_State *L)
{
	u16 command;
	std::string payload;

	if (lua_isnumber(L, 1)) {
		command = luaL_checkint(L, 1);
	} else if (lua_isstring(L, 1)) {
		const char *name = luaL_checkstring(L, 1);
		lua_getglobal(L, "core");
		lua_getfield(L, -1, "TOCLIENT");
		lua_getfield(L, -1, name);
		if (lua_isnumber(L, -1)) {
			command = lua_tointeger(L, -1);
		} else {
			lua_pop(L, 1);
			lua_getfield(L, -2, "TOSERVER");
			lua_getfield(L, -1, name);
			if (lua_isnumber(L, -1)) {
				command = lua_tointeger(L, -1);
			} else {
				lua_pop(L, 4);
				throw LuaError(std::string("Unknown packet name: ") + name);
			}
			lua_pop(L, 1);
		}
		lua_pop(L, 2);
	} else {
		throw LuaError("Expected number or string for command");
	}

	if (lua_isstring(L, 2)) {
		size_t len;
		const char *data = luaL_checklstring(L, 2, &len);
		payload.assign(data, len);
	} else if (!lua_isnone(L, 2)) {
		throw LuaError("Expected string for payload");
	}

	Client *client = getClient(L);
	ClientScripting *script = dynamic_cast<ClientScripting*>(
			client->getScript());
	if (!script)
		return 0;

	bool ok = script->send_raw_packet(command, payload);
	if (!ok)
		throw LuaError("Failed to send raw packet: invalid or blacklisted command");
	return 0;
}

// send_raw_mtp_packet(payload)
// Sends a raw MTP/UDP packet directly to the server.
// payload: raw bytes for the complete UDP datagram (including PROTOCOL_ID header)
int ModApiClient::l_send_raw_mtp_packet(lua_State *L)
{
	size_t len;
	const char *data = luaL_checklstring(L, 1, &len);
	if (len == 0)
		return 0;

	Client *client = getClient(L);
	client->getConnection().sendRawMTP(PEER_ID_SERVER,
			reinterpret_cast<const u8*>(data), (u32)len);
	return 0;
}

// get_peer_id()
int ModApiClient::l_get_peer_id(lua_State *L)
{
	Client *client = getClient(L);
	lua_pushinteger(L, client->getConnection().GetPeerID());
	return 1;
}

// detach()
int ModApiClient::l_detach(lua_State *L)
{
	RenderingEngine *re = RenderingEngine::get();
	if (re)
		re->setDetached(true);
	return 0;
}

// reattach()
int ModApiClient::l_reattach(lua_State *L)
{
	RenderingEngine *re = RenderingEngine::get();
	if (re)
		re->setDetached(false);
	return 0;
}

void ModApiClient::Initialize(lua_State *L, int top)
{
	API_FCT(get_current_modname);
	API_FCT(get_modpath);
	API_FCT(get_modpath_real);
	API_FCT(print);
	API_FCT(display_chat_message);
	API_FCT(show_toast);
	API_FCT(send_chat_message);
	API_FCT(clear_out_chat_queue);
	API_FCT(get_player_names);
	API_FCT(set_last_run_mod);
	API_FCT(get_last_run_mod);
	API_FCT(show_formspec);
	API_FCT(send_respawn);
	API_FCT(gettext);
	API_FCT(get_node_or_nil);
	API_FCT(disconnect);
	API_FCT(find_nodes_near);
	API_FCT(get_meta);
	// FIXME: sound_play/stop/fade need ISoundManager porting
	API_FCT(get_server_info);
	API_FCT(get_item_def);
	API_FCT(get_node_def);
	API_FCT(get_privilege_list);
	API_FCT(get_builtin_path);
	API_FCT(get_language);
	API_FCT(get_csm_restrictions);
	API_FCT(send_damage);
	API_FCT(place_node);
	API_FCT(dig_node);
	API_FCT(get_inventory);
	API_FCT(set_keypress);
	API_FCT(drop_selected_item);
	API_FCT(get_objects_inside_radius);
	API_FCT(make_screenshot);
	API_FCT(interact);
	API_FCT(send_inventory_fields);
	API_FCT(send_nodemeta_fields);
	API_FCT(send_raw_packet);
	API_FCT(send_raw_mtp_packet);
	API_FCT(get_peer_id);
	API_FCT(read_schematic);
	API_FCT(serialize_schematic);
	API_FCT(read_file);
	API_FCT(decode_image);
	API_FCT(write_file);
	API_FCT(get_dir_list);
	API_FCT(create_client_entity);
	API_FCT(detach);
	API_FCT(reattach);
}

void ModApiClient::InitializeSSCSM(lua_State *L, int top)
{
	API_FCT(get_current_modname);
	API_FCT(get_modpath);
	API_FCT(get_modpath_real);
	API_FCT(print);
	API_FCT(get_builtin_path);
}
