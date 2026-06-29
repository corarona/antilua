// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "al_client_map.h"
#include "l_internal.h"
#include "common/c_converter.h"
#include "common/c_content.h"
#include "client/client.h"
#include "client/clientmap.h"
#include "constants.h"
#include "map.h"
#include "nodedef.h"

// get_nodes_in_area(p1, p2) -> { {x,y,z,name,param1,param2}, ... }
int AlApiClientMap::l_get_nodes_in_area(lua_State *L)
{
	NO_MAP_LOCK_REQUIRED;

	v3s16 p1 = read_v3s16(L, 1);
	v3s16 p2 = read_v3s16(L, 2);
	sortBoxVerticies(p1, p2);

	Client *client = getClient(L);
	const NodeDefManager *ndef = client->getNodeDefManager();
	Map &map = client->getEnv().getMap();

	s64 volume = (s64)(p2.X - p1.X + 1) * (p2.Y - p1.Y + 1) * (p2.Z - p1.Z + 1);
	if (volume > static_cast<s64>(MAX_WORKING_VOLUME)) {
		throw LuaError("Area volume exceeds allowed value of "
			+ std::to_string(MAX_WORKING_VOLUME));
	}

	lua_newtable(L);
	int table_idx = lua_gettop(L);
	u32 index = 0;

	map.forEachNodeInArea(p1, p2, [&](v3s16 pos, MapNode n) -> bool {
		content_t c = n.getContent();
		if (c == CONTENT_AIR || c == CONTENT_IGNORE)
			return true;

		lua_newtable(L);
		// position
		lua_pushinteger(L, pos.X);
		lua_setfield(L, -2, "x");
		lua_pushinteger(L, pos.Y);
		lua_setfield(L, -2, "y");
		lua_pushinteger(L, pos.Z);
		lua_setfield(L, -2, "z");
		// name
		lua_pushstring(L, ndef->get(c).name.c_str());
		lua_setfield(L, -2, "name");
		// param1
		lua_pushinteger(L, n.getParam1());
		lua_setfield(L, -2, "param1");
		// param2
		lua_pushinteger(L, n.getParam2());
		lua_setfield(L, -2, "param2");

		lua_rawseti(L, table_idx, ++index);
		return true;
	});

	return 1;
}

void AlApiClientMap::Initialize(lua_State *L, int top)
{
	API_FCT(get_nodes_in_area);
}
