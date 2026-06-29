// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "lua_api/l_base.h"

class AlApiClientMap : public ModApiBase
{
private:
	// get_nodes_in_area(p1, p2)
	static int l_get_nodes_in_area(lua_State *L);

public:
	static void Initialize(lua_State *L, int top);
};
