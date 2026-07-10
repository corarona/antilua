local function get_wall(width, depth, height)
	height = height or 4
	local a1 = math.floor(width / 2) * -1
	local a2 = math.ceil(width / 2) - 1
	local b1 = math.floor(depth / 2) * -1
	local b2 = math.ceil(depth / 2) - 1
	local rt = {}
	for y = 1, height do
		for i = a1, a2 do
			table.insert(rt, ws.dircoord(b2, y, i))
			table.insert(rt, ws.dircoord(b1, y, i))
		end
		for i = b1, b2 do
			table.insert(rt, ws.dircoord(i, y, a2))
			table.insert(rt, ws.dircoord(i, y, a1))
		end
	end
	return rt
end

ws.rg("WallIn", { category = "Place", setting = "place_wallin", description = "Place walls inside tunnels",
	on_step = function(self)
		local width = tonumber(core.settings:get(self.setting .. ".width")) or 8
		local depth = tonumber(core.settings:get(self.setting .. ".depth")) or 8
		local height = tonumber(core.settings:get(self.setting .. ".height")) or 4
		local poss = get_wall(width, depth, height)
		for k, v in pairs(poss) do
			core.place_node(v)
		end
	end,
	delay = 0.5,
	cheat_settings = {
		width = { type = "number", default = 8, min = 2, max = 50 },
		depth = { type = "number", default = 8, min = 2, max = 50 },
		height = { type = "number", default = 4, min = 1, max = 20 },
	},
})

local skypltfrm_nd
local skypltfrm_glassmode

ws.rg("SkyPltfrm", { category = "Place", setting = "place_skypltfrm", description = "Build sky platform",
	on_step = function(self)
		local width = tonumber(core.settings:get(self.setting .. ".width")) or 5
		local n = math.floor(width / 2)
		if not skypltfrm_nd then skypltfrm_nd = core.localplayer:get_wielded_item():get_name() end
		for i = -n, n do
			local obpos = ws.dircoord(0, -2, i)
			ws.place(ws.dircoord(0, -1, i), skypltfrm_nd, 7)
			if skypltfrm_glassmode and obpos.x % 8 == 0 and obpos.z % 8 == 0 then
				ws.place(obpos, 'mcl_ocean:sea_lantern', 5)
				ws.place(ws.dircoord(0, -3, i), 'mcl_core:obsidian', 6)
			else
				ws.place(obpos, 'mcl_core:obsidian', 6)
			end
		end
	end,
	on_start = function(self)
		skypltfrm_nd = core.localplayer:get_wielded_item():get_name()
		if skypltfrm_nd:find('glass') then skypltfrm_glassmode = true end
	end,
	on_stop = function(self)
		skypltfrm_nd = nil
	end,
	cheat_settings = {
		width = { type = "number", default = 5, min = 1, max = 30 },
	},
})

local function get_nodes_over_air(pos, range, nodes)
	local nds = core.find_nodes_near(pos, range, nodes)
	local rt = {}
	for k, v in ipairs(nds) do
		local under = vector.add(v, vector.new(0, -1, 0))
		local un = core.get_node_or_nil(under)
		if un and un.name == "air" then table.insert(rt, v) end
	end
	return rt
end

ws.rg("PCeiling", { category = "Place", setting = "pceiling", description = "Place ceiling above you",
	on_step = function(self)
		if not self._node then return end
		local range = tonumber(core.settings:get(self.setting .. ".range")) or 4
		local lp = ws.dircoord(0, 0, 0)
		local nds = get_nodes_over_air(lp, range, nlist.get(nlist.selected))
		for k, v in pairs(nds) do
			local pos = ws.dircoord(0, -1, 0, v)
			ws.place(pos, self._node)
		end
	end,
	on_start = function(self)
		self._node = core.localplayer:get_wielded_item():get_name()
	end,
	on_start = function(self)
		multiscaff_node = core.localplayer:get_wielded_item():get_name()
		-- started notification handled by lifecycle hook
	end,
	cheat_settings = {
		range = { type = "number", default = 4, min = 1, max = 20 },
	},
})
