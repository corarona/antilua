-- CC0/Unlicense Emilia & cora 2020
-- place: world-building/block-placement cheats (renamed from scaffold)

local mpath = core.get_modpath(core.get_current_modname())
dofile(mpath .. "/spongebot.lua")

local function mscaffold(self)
	if not self._node then return end
	local width = tonumber(core.settings:get("scaffold.width")) or 5
	local depth = tonumber(core.settings:get("scaffold.depth")) or 1
	local above = tonumber(core.settings:get("scaffold.above")) or 0
	local npt = tonumber(core.settings:get("scaffold.npt")) or ws.get_nodes_per_tick() or 25
	local y_from = -depth
	local y_to = -1
	if above > 0 then
		y_from = above
		y_to = above + depth
	end
	local n = math.floor(width / 2)
	local placed = 0
	for fo = -2, 2 do
		for i = -n, n do
			for j = y_from, y_to do
				if placed >= npt then return end
				local p = ws.dircoord(fo, j, i)
				local nd = p and core.get_node_or_nil(p)
				if nd and ws.can_place_at(p) then
					ws.place(p, self._node)
					placed = placed + 1
				end
			end
		end
	end
end

ws.rg('MultiScaff', { category = 'Place', setting = 'scaffold', description = "Build scaffold beneath you",
	on_step = function(self, dtime)
		if tps_client and tonumber(tps_client.ping) and tps_client.ping > (tonumber(core.settings:get("scaffold.ping_tolerance")) or 1500) then return end
		mscaffold(self)
	end,
	on_start = function(self)
		self._node = core.localplayer:get_wielded_item():get_name()
	end,
	cheat_settings = {
		width = { type = "number", default = 5, min = 1, max = 50 },
		depth = { type = "number", default = 1, min = 1, max = 20 },
		above = { type = "number", default = 0, min = 0, max = 20 },
		npt = { type = "number", default = 25, min = 1, max = 500 },
		ping_tolerance = { type = "number", default = 1500, min = 0, max = 5000 },
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
		local npt = tonumber(core.settings:get("scaffold.npt")) or ws.get_nodes_per_tick() or 25
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
		local npt = tonumber(core.settings:get("scaffold.npt")) or ws.get_nodes_per_tick() or 25
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

ws.rg("AutoTower", { category = "Place", setting = "autotower",
	description = "Build towers: stack hotbar blocks onto exposed matching blocks",
	on_step = function(self, dtime)
		local range = tonumber(core.settings:get(self.setting .. ".range")) or 5
		local npt = tonumber(core.settings:get(self.setting .. ".npt")) or 25
		local down = core.settings:get_bool(self.setting .. ".down", false)
		local random = core.settings:get_bool(self.setting .. ".random", false)
		local inv = core.get_inventory("current_player")
		if not inv then return end
		-- Collect node types present in the hotbar (slots 1-9), weighted by stack count
		local wanted = {}   -- name -> total count
		for i = 1, 9 do
			local stack = inv.main[i]
			if stack and not stack:is_empty() then
				local name = stack:get_name()
				local def = core.get_item_def(name)
				if def and def.type == "node" then
					wanted[name] = (wanted[name] or 0) + stack:get_count()
				end
			end
		end
		local names, weights, total = {}, {}, 0
		for name, count in pairs(wanted) do
			names[#names + 1] = name
			total = total + count
			weights[#weights + 1] = total
		end
		if #names == 0 then return end
		local pick_weighted = function()
			local r = math.random(total)
			for i, w in ipairs(weights) do
				if r <= w then return names[i] end
			end
			return names[#names]
		end
		local lp = ws.dircoord(0, 0, 0)
		local found = core.find_nodes_near(lp, range, names, true)
		local dy = down and -1 or 1
		local placed = 0
		for i, p in ipairs(found) do
			if placed >= npt then break end
			local tgt = vector.add(p, {x = 0, y = dy, z = 0})
			-- Never place into the space the player occupies
			if not (tgt.x == lp.x and tgt.z == lp.z and (tgt.y == lp.y or tgt.y == lp.y + 1)) then
				local nd = core.get_node_or_nil(p)
				if nd and wanted[nd.name] and ws.can_place_at(tgt) then
					local name = random and pick_weighted() or nd.name
					if ws.place(tgt, {name}) then placed = placed + 1 end
				end
			end
		end
	end,
	cheat_settings = {
		down = { type = "bool", default = false },
		random = { type = "bool", default = false },
		range = { type = "number", default = 5, min = 1, max = 20 },
		npt = { type = "number", default = 25, min = 1, max = 500 },
	},
})





