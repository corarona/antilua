-- ItemCollector bot — collects dropped items using sbots, deposits into chests

local initial_counts = {}  -- item_name → total_count at activation

local function snapshot_inv()
	local inv = core.get_inventory("current_player")
	if not inv then return end
	initial_counts = {}
	for _, stack in ipairs(inv.main) do
		if not stack:is_empty() then
			local name = stack:get_name()
			initial_counts[name] = (initial_counts[name] or 0) + stack:get_count()
		end
	end
end

local function get_excess_slots()
	local inv = core.get_inventory("current_player")
	if not inv then return {} end
	local current_counts = {}
	for _, stack in ipairs(inv.main) do
		if not stack:is_empty() then
			local name = stack:get_name()
			current_counts[name] = (current_counts[name] or 0) + stack:get_count()
		end
	end
	local slots = {}
	local seen_excess = {}
	for i, stack in ipairs(inv.main) do
		if not stack:is_empty() then
			local name = stack:get_name()
			if name ~= "mcl_chests:chest" and name ~= "mcl_chests:chest_trapped"
					and not name:find("^mcl_shulker") then
				local init_total = initial_counts[name] or 0
				if current_counts[name] > init_total and not seen_excess[name] then
					table.insert(slots, {idx = i, name = name,
						count = stack:get_count(),
						excess = current_counts[name] - init_total})
					seen_excess[name] = true
				end
			end
		end
	end
	return slots
end

local function place_chest_nearby(lp)
	local chest_item = "mcl_chests:chest"
	if not ws.switch_to_item(chest_item) then return nil end

	local rlp = vector.round(lp)
	-- Air above solid node
	for dy = 0, -3, -1 do
	for dx = -2, 2 do
	for dz = -2, 2 do
		local p = vector.add(rlp, {x = dx, y = dy, z = dz})
		local node = core.get_node_or_nil(p)
		if node and (core.get_item_def(node.name) or {}).walkable then
			local above = vector.offset(p, 0, 1, 0)
			if (core.get_node_or_nil(above) or {}).name == "air" then
				ws.place(above, chest_item)
				return above
			end
		end
	end
	end
	end
	-- Fallback: any air node
	for dx = -2, 2 do
	for dz = -2, 2 do
	for dy = 0, -2, -1 do
		local p = vector.add(rlp, {x = dx, y = dy, z = dz})
		if (core.get_node_or_nil(p) or {}).name == "air" then
			ws.place(p, chest_item)
			return p
		end
	end
	end
	end
	return nil
end

sbots.register_bot("ItemCollector", {
	description = "Collect dropped items and deposit into chests",
	movement = "walk",
	stand_waiting = true,
	landing_distance = 1.5,
	find_pos = function(self, pos)
		if self._deposit_phase then return nil end
		local range = tonumber(core.settings:get("item_collector.collect_range")) or 6
		local closest, closest_d = nil, math.huge
		for _, obj in pairs(core.get_objects_inside_radius(pos, range)) do
			if obj:get_name() == "__builtin:item" then
				local d = vector.distance(pos, obj:get_pos())
				if d < closest_d then closest, closest_d = obj, d end
			end
		end
		if not closest then return nil end
		return closest:get_pos()
	end,
	do_pos = function(self, pos)
		local range = tonumber(core.settings:get("item_collector.collect_range")) or 6
		for _, obj in pairs(core.get_objects_inside_radius(pos, range)) do
			if obj:get_name() == "__builtin:item" and
					vector.distance(pos, obj:get_pos()) < 2 then
				return false
			end
		end
		return true
	end,
	do_step = function(self, dtime)
		if self._deposit_phase then
			if self._deposit_phase == 1 then
				local lp = core.localplayer:get_pos()
				if not lp then return end
				core.settings:set_bool("continuous_forward", false)
				local cp = place_chest_nearby(lp)
				if not cp then
					return
				end
				self._chest_pos = cp
				self._deposit_pending = get_excess_slots()
				self._deposit_phase = 2
			end
			if self._deposit_phase == 2 then
				if #self._deposit_pending == 0 then
					self._deposit_phase = nil
					self._chest_pos = nil
					return
				end
				local slot = table.remove(self._deposit_pending)
				local cloc = "nodemeta:" .. self._chest_pos.x .. "," .. self._chest_pos.y .. "," .. self._chest_pos.z
				ws.move_stack("current_player", "main", slot.idx, cloc, "main", slot.idx)
			end
			return
		end

		local inv = core.get_inventory("current_player")
		if inv then
			local free = 0
			for _, stack in ipairs(inv.main) do
				if stack:is_empty() then free = free + 1 end
			end
			if free <= 2 and #get_excess_slots() > 0 then
				self._deposit_phase = 1
				self.stage = 0
			end
		end
	end,
	on_activate = function(self)
		snapshot_inv()
	end,
	cheat_settings = {
		collect_range = { type = "number", default = 6, min = 2, max = 20 },
	},
})
