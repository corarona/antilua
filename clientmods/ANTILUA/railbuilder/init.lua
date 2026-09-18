-- RailBuilder: builds a straight golden-rail line on redstone supports with
-- periodic light posts and nether portal stations. Materials are restocked
-- from named shulker kits kept in the ender chest (sbots.refill_materials).
--
-- Layout per column along the build direction:
--   rail_y        golden rail
--   rail_y - 1    support (block of redstone per redstone_sparsity, else
--                 existing solid ground, else any other block, redstone as
--                 fallback when nothing else is carried)
--   rail_y + 3    light block (every light_every columns, light_source >=
--                 min_light picked from the inventory)
-- Every station_every columns a nether portal (4x5 obsidian frame) is built
-- beside the line and decorated with leftover nodes from the station kit.

local RAIL = "mcl_minecarts:golden_rail"
-- Rails switch to the _on variant when powered (by the redstone block below
-- or by neighbouring powered rails), both count as the finished rail.
local RAIL_ON = "mcl_minecarts:golden_rail_on"
local RAIL_NAMES = { [RAIL] = true, [RAIL_ON] = true }
local REDSTONE = "mcl_redstone_torch:redstoneblock"
local OBSIDIAN = "mcl_core:obsidian"
local FLINT = "mcl_fire:flint_and_steel"
local PORTAL_NODE = "mcl_portals:portal"

local WANT_RAIL = 32
local WANT_REDSTONE = 32
local WANT_LIGHT = 4
local WANT_OBSIDIAN = 14
local WANT_FLINT = 1

local DIRS = {
	["+x"] = {x = 1, z = 0},
	["-x"] = {x = -1, z = 0},
	["+z"] = {x = 0, z = 1},
	["-z"] = {x = 0, z = -1},
}

local FILLER_PREF = {
	"mcl_core:cobblestone",
	"mcl_core:stone",
	"mcl_core:dirt",
	"mcl_nether:netherrack",
	"mcl_deepslate:deepslate",
	"mcl_core:andesite",
}

local DECO_EXCLUDE = {
	[RAIL] = true,
	[REDSTONE] = true,
	[OBSIDIAN] = true,
	[FLINT] = true,
}

local function is_airlike(name)
	return name == nil or name == "air" or name == "ignore"
end

local function is_buildable_at(pos)
	local nd = core.get_node_or_nil(pos)
	if not nd then return false end
	local def = core.get_node_def(nd.name)
	return nd.name == "air" or (def and def.buildable_to)
end

local function is_solid_at(pos)
	local nd = core.get_node_or_nil(pos)
	if not nd or nd.name == "ignore" then return false end
	local def = core.get_node_def(nd.name)
	return def and def.walkable
end

local function find_filler()
	local inv = core.get_inventory("current_player")
	if not inv then return nil end
	for _, name in ipairs(FILLER_PREF) do
		if ws.count_item(name) > 0 then return name end
	end
	local best, best_count
	for _, stack in ipairs(inv.main) do
		if not stack:is_empty() then
			local name = stack:get_name()
			local def = core.get_item_def(name)
			if def and def.type == "node"
					and not DECO_EXCLUDE[name]
					and not name:find("shulker_box", 1, true)
					and not name:find("chest", 1, true)
					and not name:find("torch", 1, true)
					and not name:find("rail", 1, true) then
				if not best_count or stack:get_count() > best_count then
					best, best_count = name, stack:get_count()
				end
			end
		end
	end
	return best
end

local function find_deco_item()
	local inv = core.get_inventory("current_player")
	if not inv then return nil end
	for _, stack in ipairs(inv.main) do
		if not stack:is_empty() then
			local name = stack:get_name()
			local def = core.get_item_def(name)
			if def and def.type == "node" and not DECO_EXCLUDE[name]
					and not name:find("shulker_box", 1, true)
					and not name:find("chest", 1, true)
					and not name:find("torch", 1, true)
					and not name:find("door", 1, true)
					and not name:find("bed", 1, true)
					and not name:find("rail", 1, true) then
				return name
			end
		end
	end
	return nil
end

sbots.register_bot("RailBuilder", {
	description = "Builds a golden rail line on redstone with lights and portal stations",
	movement = "walk",
	stand_waiting = true,
	landing_distance = 1.2,

	on_activate = function(self)
		if not core.get_item_def(RAIL) then
			ws.notify("RailBuilder: golden rail not found (mineclonia?)", ws.NOTIFY_ERROR)
			return false
		end
		local lp = core.localplayer and core.localplayer:get_pos()
		if not lp then return false end
		self.dir = DIRS[core.settings:get("railbuilder.direction") or "+x"] or DIRS["+x"]
		local m = core.settings:get("railbuilder.portal_side") == "left" and -1 or 1
		self.side = {x = self.dir.z * m, z = -self.dir.x * m}
		self.side_offset = math.max(1, tonumber(core.settings:get("railbuilder.side_offset")) or 3)
		self.sparsity = math.max(1, tonumber(core.settings:get("railbuilder.redstone_sparsity")) or 1)
		self.light_every = math.max(1, tonumber(core.settings:get("railbuilder.light_every")) or 8)
		self.light_above = math.max(1, tonumber(core.settings:get("railbuilder.light_above")) or 3)
		self.min_light = tonumber(core.settings:get("railbuilder.min_light")) or 10
		self.station_every = tonumber(core.settings:get("railbuilder.station_every")) or 200
		self.spare_kit = core.settings:get_bool("railbuilder.spare_kit", true)
		self._kit_items = {
			railkit = core.settings:get("railbuilder.rail_kit_item") or "",
			stationkit = core.settings:get("railbuilder.station_kit_item") or "",
		}
		self.rail_y = math.floor(lp.y + 0.5)
		self.origin = {x = math.floor(lp.x + 0.5), z = math.floor(lp.z + 0.5)}
		self.cursor = 0
		self._build_done = false
		self._station = nil
		self._stations_done = {}
		self._refill = nil
		self._refill_fails = 0
		self._refill_cooldown = nil
		self._kit_supplies = {}
		self._pickaxe_warned = false
		sbots.set_status("RailBuilder", "building")
	end,

	on_deactivate = function(self)
		self._refill = nil
		self._station = nil
	end,

	find_pos = function(self, pos)
		-- While building: stand still. After a column is done: step onto it.
		if self._build_done then
			local b = self:column_base(self.cursor)
			return {x = b.x + 0.5, y = self.rail_y, z = b.z + 0.5}
		end
		return pos
	end,

	do_pos = function(self, pos)
		if self._refill then return false end
		if self._build_done then
			local b = self:column_base(self.cursor)
			local center = {x = b.x + 0.5, y = self.rail_y, z = b.z + 0.5}
			self._move_wait = (self._move_wait or 0) + 1
			-- Advance when close enough to the finished column, or after a
			-- short wait: walking is only for loading terrain, placement has
			-- no reach limit, so never let a blocked walk stall the line.
			if vector.distance(pos, center) < 1.3 or (self._move_wait > 15) then
				self.cursor = self.cursor + 1
				self._build_done = false
				self._move_wait = 0
				sbots.set_status("RailBuilder", "col " .. self.cursor)
				return true
			end
			return false
		end
		self._move_wait = 0
		local done = self:column_work(self.cursor)
		if done then
			self._col_stall = 0
			self._build_done = true
			return true
		end
		self._col_stall = (self._col_stall or 0) + 1
		if self._col_stall > 40 then
			-- Placement keeps failing despite materials; skip the column
			-- instead of stalling forever.
			self._col_stall = 0
			self._build_done = true
			ws.notify("RailBuilder: column " .. self.cursor .. " stuck, skipping",
				ws.NOTIFY_WARNING)
		end
		return false
	end,

	do_step = function(self, dtime)
		if self._refill then
			core.settings:set_bool("continuous_forward", false)
			self.stage = 2
			local ok, st = pcall(self._refill.step, self._refill, dtime)
			if not ok then
				self._refill = nil
				ws.notify("RailBuilder: restock error (" .. tostring(st) .. ")",
					ws.NOTIFY_ERROR)
				core.settings:set_bool("railbuilder", false)
				return
			end
			if st == "active" then
				sbots.set_status("RailBuilder", "restock: " .. tostring(self._refill.status))
				return
			end
			local done = st == "done"
			local job = self._refill
			self._refill = nil
			if not done then
				ws.notify("RailBuilder: restock failed (" .. tostring(job.error) .. ")",
					ws.NOTIFY_ERROR)
				core.settings:set_bool("railbuilder", false)
				return
			end
			if next(job.missing) then
				self._refill_fails = (self._refill_fails or 0) + 1
				if self._refill_fails >= 3 then
					ws.notify("RailBuilder: restock keeps coming up short, stopping",
						ws.NOTIFY_ERROR)
					core.settings:set_bool("railbuilder", false)
					return
				end
				ws.notify("RailBuilder: some materials unavailable", ws.NOTIFY_WARNING)
				self._refill_cooldown = 5
			else
				self._refill_fails = 0
			end
		end

		if self._refill_cooldown and self._refill_cooldown > 0 then
			self._refill_cooldown = self._refill_cooldown - dtime
			return
		end

		if not self._build_done then
			-- Standing to build: kill the walk strategy's one-frame forward
			-- lag so the bot does not drift while placing.
			core.settings:set_bool("continuous_forward", false)
		end

		if not sbots.ensure_pickaxe() and not self._pickaxe_warned then
			self._pickaxe_warned = true
			ws.notify("RailBuilder: no pickaxe in the hotbar", ws.NOTIFY_WARNING)
		end

		local items, kit = self:refill_needed()
		if items then
			self.stage = 2
			self._refill = sbots.refill_materials({
				kit = kit,
				kit_item = self._kit_items[kit] or "",
				items = items,
				avoid = self:avoid_columns(),
				spare_kit = self.spare_kit,
			})
		end
	end,

	----------------------------------------------------------------------------
	-- Geometry
	----------------------------------------------------------------------------

	column_base = function(self, idx)
		return {
			x = self.origin.x + self.dir.x * idx,
			z = self.origin.z + self.dir.z * idx,
		}
	end,

	avoid_columns = function(self)
		local out = {}
		for i = self.cursor - 2, self.cursor + 8 do
			local b = self:column_base(i)
			table.insert(out, {x = b.x, z = b.z})
		end
		return out
	end,

	refill_needed = function(self)
		-- Portal stations first: obsidian and flint must be there when due.
		for i = self.cursor, self.cursor + 4 do
			if i > 0 and self.station_every > 0 and i % self.station_every == 0
					and not self._stations_done[i] then
				local items = self:station_wants()
				if sbots.missing_item(items) then
					return items, "stationkit"
				end
			end
		end
		local items = self:rail_wants()
		if sbots.missing_item(items) then
			return items, "railkit"
		end
		return nil
	end,

	-- Only demand materials the kit actually carries (learned from the last
	-- drain), so a kit without, say, light blocks never stalls the restock.
	kit_has = function(self, kit, name)
		local supplies = self._kit_supplies[kit]
		if not supplies then return true end
		return supplies[name] == true
	end,

	rail_wants = function(self)
		local items = {}
		if self:kit_has("railkit", RAIL) then
			items[RAIL] = WANT_RAIL
		end
		if self:kit_has("railkit", REDSTONE) then
			items[REDSTONE] = WANT_REDSTONE
		end
		-- Lights are opportunistic: restock when none are left, and only if
		-- the kit supplies them.
		local lname = ws.find_light_block(self.min_light)
		if lname and ws.count_item(lname) < 1 and self:kit_has("railkit", lname) then
			items[lname] = WANT_LIGHT
		end
		return items
	end,

	station_wants = function(self)
		local items = {}
		if self:kit_has("stationkit", OBSIDIAN) then
			items[OBSIDIAN] = WANT_OBSIDIAN
		end
		if self:kit_has("stationkit", FLINT) then
			items[FLINT] = WANT_FLINT
		end
		return items
	end,

	----------------------------------------------------------------------------
	-- Column building (one operation per call, returns true when complete)
	----------------------------------------------------------------------------

	column_work = function(self, idx)
		local b = self:column_base(idx)
		local rail_pos = {x = b.x, y = self.rail_y, z = b.z}
		local sup_pos = {x = b.x, y = self.rail_y - 1, z = b.z}

		-- 1. Clear head room and the rail voxel.
		for _, p in ipairs({
			{x = b.x, y = self.rail_y + 2, z = b.z},
			{x = b.x, y = self.rail_y + 1, z = b.z},
		}) do
			local nd = core.get_node_or_nil(p)
			if nd and not is_airlike(nd.name) then
				local def = core.get_node_def(nd.name)
				if (def and def.light_source or 0) == 0 and ws.is_diggable(p) then
					ws.dig(p)
					return false
				end
			end
		end
		local rnode = core.get_node_or_nil(rail_pos)
		if rnode and not is_airlike(rnode.name) and not RAIL_NAMES[rnode.name] then
			if ws.is_diggable(rail_pos) then
				ws.dig(rail_pos)
			end
			return false
		end

		-- 2. Support: redstone on sparsity columns or when nothing else fits,
		-- existing solid ground is reused, other blocks fill the rest.
		if not is_solid_at(sup_pos) then
			local name
			if idx % self.sparsity == 0 then
				name = REDSTONE
			else
				name = find_filler() or REDSTONE
			end
			if ws.count_item(name) < 1 then
				return false
			end
			ws.place(sup_pos, name)
			return false
		end

		-- 3. Rail on top of the support (powered _on variant counts as done).
		if not rnode or not RAIL_NAMES[rnode.name] then
			if ws.count_item(RAIL) < 1 then return false end
			ws.place(rail_pos, RAIL)
			return false
		end

		-- 4. Light post every light_every columns.
		if idx % self.light_every == 0 then
			local lp = {x = b.x, y = self.rail_y - 1 + self.light_above, z = b.z}
			if is_buildable_at(lp) then
				local lname = ws.find_light_block(self.min_light)
				if lname then
					ws.place(lp, lname)
					return false
				end
			end
		end

		-- 5. Portal station.
		if self.station_every > 0 and idx > 0 and idx % self.station_every == 0
				and not self._stations_done[idx] then
			return self:station_work(idx)
		end

		return true
	end,

	----------------------------------------------------------------------------
	-- Portal stations
	----------------------------------------------------------------------------

	station_layout = function(self, idx)
		local b0 = self:column_base(idx)
		local list = {}
		local interior_bottoms = {}
		for j = 0, 3 do
			local bx = b0.x + self.dir.x * j + self.side.x * self.side_offset
			local bz = b0.z + self.dir.z * j + self.side.z * self.side_offset
			table.insert(list, {pos = {x = bx, y = self.rail_y - 1, z = bz}, frame = true})
			table.insert(list, {pos = {x = bx, y = self.rail_y + 3, z = bz}, frame = true})
			local interior = (j == 1 or j == 2)
			for y = 0, 2 do
				local p = {x = bx, y = self.rail_y + y, z = bz}
				table.insert(list, {pos = p, frame = not interior})
				if interior and y == 0 then
					table.insert(interior_bottoms, p)
				end
			end
		end
		-- Decoration spots between the rail line and the portal.
		local deco = {}
		for j = -1, 4 do
			for lat = 1, self.side_offset - 1 do
				table.insert(deco, {
					x = b0.x + self.dir.x * j + self.side.x * lat,
					z = b0.z + self.dir.z * j + self.side.z * lat,
				})
			end
		end
		return list, interior_bottoms, deco
	end,

	station_work = function(self, idx)
		local st = self._station
		if not st or st.idx ~= idx then
			local list, interior_bottoms, deco = self:station_layout(idx)
			st = {idx = idx, list = list, interior_bottoms = interior_bottoms,
				deco = deco, deco_i = 1, i = 1, phase = "clear", lights = 0}
			self._station = st
			sbots.set_status("RailBuilder", "station " .. idx)
		end

		if st.phase == "clear" then
			while st.i <= #st.list do
				local e = st.list[st.i]
				st.i = st.i + 1
				local nd = core.get_node_or_nil(e.pos)
				if nd and not is_airlike(nd.name) then
					if e.frame and nd.name ~= OBSIDIAN then
						ws.dig(e.pos)
						return false
					elseif not e.frame and not is_buildable_at(e.pos) then
						ws.dig(e.pos)
						return false
					end
				end
			end
			st.phase = "frame"
			st.i = 1
			return false
		end

		if st.phase == "frame" then
			while st.i <= #st.list do
				local e = st.list[st.i]
				st.i = st.i + 1
				if e.frame then
					local nd = core.get_node_or_nil(e.pos)
					if is_airlike(nd and nd.name) then
						if ws.count_item(OBSIDIAN) < 1 then
							ws.notify("RailBuilder: out of obsidian", ws.NOTIFY_WARNING)
							st.phase = "deco"
							return false
						end
						ws.place(e.pos, OBSIDIAN)
						return false
					end
				end
			end
			st.phase = "light"
			return false
		end

		if st.phase == "light" then
			local bottom = st.interior_bottoms[1]
			local nd = bottom and core.get_node_or_nil(bottom)
			if nd and nd.name == PORTAL_NODE then
				st.phase = "deco"
				return false
			end
			if st.lights >= 6 or not ws.switch_to_item(FLINT) then
				if st.lights > 0 then
					ws.notify("RailBuilder: portal did not light", ws.NOTIFY_WARNING)
				end
				st.phase = "deco"
				return false
			end
			-- Fire is placed at the pointed node above the clicked one; the
			-- fire node constructs the portal.
			local target = st.interior_bottoms[st.lights % 2 + 1]
			if is_buildable_at(target) then
				core.interact("activate", {
					type = "node",
					under = {x = target.x, y = target.y - 1, z = target.z},
					above = target,
				})
				st.lights = st.lights + 1
			end
			return false
		end

		if st.phase == "deco" then
			while st.deco_i <= #st.deco do
				local col = st.deco[st.deco_i]
				st.deco_i = st.deco_i + 1
				local item = find_deco_item()
				if not item then break end
				for y = self.rail_y + 1, self.rail_y - 3, -1 do
					local p = {x = col.x, y = y, z = col.z}
					if is_solid_at(p) then
						local above = {x = p.x, y = y + 1, z = p.z}
						if is_buildable_at(above) and ws.place(above, item) then
							return false
						end
						break
					end
				end
			end
			st.phase = "done"
			return false
		end

		self._stations_done[idx] = true
		self._station = nil
		return true
	end,

	cheat_settings = {
		direction = { type = "enum", default = "+x", values = {"+x", "-x", "+z", "-z"} },
		redstone_sparsity = { type = "number", default = 1, min = 1, max = 10 },
		light_every = { type = "number", default = 8, min = 1, max = 32 },
		light_above = { type = "number", default = 3, min = 1, max = 8 },
		min_light = { type = "number", default = 10, min = 4, max = 15 },
		station_every = { type = "number", default = 200, min = 0, max = 1000 },
		portal_side = { type = "enum", default = "right", values = {"right", "left"} },
		side_offset = { type = "number", default = 3, min = 1, max = 6 },
		rail_kit_item = { type = "string", default = "" },
		station_kit_item = { type = "string", default = "" },
		spare_kit = { type = "bool", default = true },
	},
})
