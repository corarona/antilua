-- CC0/Unlicense Emilia & cora 2020
-- place: world-building/block-placement cheats (renamed from scaffold)

local mpath = core.get_modpath(core.get_current_modname())
dofile(mpath .. "/spongebot.lua")

local function mscaffold(self, f, npt)
	npt = npt or ws.get_nodes_per_tick()
	if not self._node then return end
	local width = tonumber(core.settings:get("scaffold.width")) or 5
	local depth = tonumber(core.settings:get("scaffold.depth")) or 1
	local above = tonumber(core.settings:get("scaffold.above")) or 0
	local yf = -depth
	local yt = -1
	if above > 0 then
		yf = above
		yt = above + depth
	end
	local n = math.floor(width / 2)
	local placed = 0
	for fo = -2, 2 do
		for i = -n, n do
			for j = yf, yt do
				if placed >= npt then return end
				local p = ws.dircoord(fo, j, i)
				local nd = p and core.get_node_or_nil(p)
				if nd then
					ws.place(p, {self._node})
					placed = placed + 1
				end
			end
		end
	end
end

ws.rg('MultiScaff', { category = 'Place', setting = 'scaffold', description = "Build scaffold beneath you",
	on_step = function(self, dtime)
		if tps_client and tonumber(tps_client.ping) and tps_client.ping > (tps_client and tps_client.ping_tolerance or 0.5) then return end
		mscaffold(self, 0, ws.get_nodes_per_tick())
	end,
	on_start = function(self)
		self._node = core.localplayer:get_wielded_item():get_name()
	end,
	cheat_settings = {
		width = { type = "number", default = 5, min = 1, max = 50 },
		depth = { type = "number", default = 1, min = 1, max = 20 },
		above = { type = "number", default = 0, min = 0, max = 20 },
	},
})





ws.rg("RandomScaff", { category = "Place", setting = "place_rnd",
	description = "Place random block scaffold",
	on_step = function(self, dtime)
		if not core.localplayer then return end
		local tgt = vector.add(core.localplayer:get_pos(), {x = 0, y = -1, z = 0})
		if not ws.inside_constraints(tgt) then return end
		local below = ws.dircoord(0, -1, 0)
		local n = core.get_node_or_nil(below)
		local nl = nlist.get('randomscaffold')
		table.shuffle(nl)
		if n and not ws.in_list(n.name, nl) then
			ws.dig_if_able(below)
			ws.place_if_needed(nl, below)
		end
	end,
})




ws.rg("BlockSources", {
	category = "Place",
	setting = "block_sources",
	description = "Block liquid sources while placing",
	on_step = function(self)
		local block_water = core.settings:get_bool(self.setting .. ".block_water", true)
		local block_lava = core.settings:get_bool(self.setting .. ".block_lava", true)
		local block_nether_lava = core.settings:get_bool(self.setting .. ".block_nether_lava", true)
		local use_wielded = core.settings:get_bool(self.setting .. ".use_wielded", false)
		local npt = ws.get_nodes_per_tick()
		local lp = ws.dircoord(0, 0, 0)
		local targets = {}
		if block_water then
			for _, v in ipairs({"mcl_core:water_source", "mcl_core:water_flowing"}) do
				table.insert(targets, v)
			end
		end
		if block_lava then
			for _, v in ipairs({"mcl_core:lava_source", "mcl_core:lava_flowing"}) do
				table.insert(targets, v)
			end
		end
		if block_nether_lava then
			for _, v in ipairs({"mcl_nether:nether_lava_source", "mcl_nether:nether_lava_flowing"}) do
				table.insert(targets, v)
			end
		end
		if #targets == 0 then return end
		local positions = core.find_nodes_near(lp, 5, targets, true)
		for i, p in pairs(positions) do
			if i > npt then return end
			if use_wielded then
				ws.place(p, self._node)
			else
				core.place_node(p)
			end
		end
	end,
	on_start = function(self)
		self._node = core.localplayer:get_wielded_item():get_name()
		if not self._node then return true end
	end,
	cheat_settings = {
		block_water = { type = "bool", default = true },
		block_lava = { type = "bool", default = true },
		block_nether_lava = { type = "bool", default = true },
		use_wielded = { type = "bool", default = false },
	},
})

ws.rg("PlaceOn", { category = "Place", setting = "placeon", description = "Place blocks on top of exposed surfaces",
	on_step = function(self)
		local range = tonumber(core.settings:get(self.setting .. ".range")) or 5
		local npt = ws.get_nodes_per_tick()
		local use_wielded = core.settings:get_bool(self.setting .. ".use_wielded", true)
		local node
		if use_wielded then
			local it = core.localplayer:get_wielded_item()
			if it:is_empty() or it.type ~= "node" then return end
			node = it:get_name()
		else
			node = core.settings:get(self.setting .. ".node") or "mcl_core:dirt_with_grass"
		end
		local lp = ws.dircoord(0, 0, 0)
		local positions = core.find_nodes_near_under_air_except(lp, range, {node}, true)
		for i, p in ipairs(positions) do
			if i > npt then break end
			ws.place(vector.add(p, {x = 0, y = 1, z = 0}), {node})
		end
	end,
	cheat_settings = {
		use_wielded = { type = "bool", default = true },
		range = { type = "number", default = 5, min = 1, max = 20 },
		node = { type = "string", default = "mcl_core:dirt_with_grass" },
	},
})





