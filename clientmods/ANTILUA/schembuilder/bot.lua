-- SchemBuilder bot: walks to the nearest unplaced node and places it
if sbots and sbots.register_bot then
	local _item_cache = {}
	local _item_cache_time = 0

	-- Find a safe stand position near a target block so the player's head
	-- doesn't end up inside another block (to-be-placed or existing).
	local function compute_safe_stand_pos(target, nodes)
		local standing_candidates = {
			{x = 0, y = -2, z = 0},
			{x = 1, y = -1, z = 0},
			{x = -1, y = -1, z = 0},
			{x = 0, y = -1, z = 1},
			{x = 0, y = -1, z = -1},
			{x = 1, y = -2, z = 0},
			{x = -1, y = -2, z = 0},
			{x = 0, y = -2, z = 1},
			{x = 0, y = -2, z = -1},
		}

		-- Build a set of to-be-placed block positions for fast lookup
		local place_set = {}
		for _, entry in ipairs(nodes) do
			if entry.name ~= "air" then
				local key = entry.x .. "," .. entry.y .. "," .. entry.z
				place_set[key] = true
			end
		end

		for _, off in ipairs(standing_candidates) do
			local sx = target.x + off.x
			local sy = target.y + off.y
			local sz = target.z + off.z
			local head_y = sy + 1

			-- Check if a to-be-placed block occupies the head space
			if not place_set[sx .. "," .. head_y .. "," .. sz] then
				-- Check if an existing solid node is at the head space
				local node
				if core.get_node_or_nil then
					node = core.get_node_or_nil({x = sx, y = head_y, z = sz})
				end
				local blocked = node and node.name ~= "air"
					and node.name ~= "ignore"
					and (not core.registered_nodes or not core.registered_nodes[node.name]
						or not core.registered_nodes[node.name].buildable_to)
				if not blocked then
					return {x = sx, y = sy, z = sz}
				end
			end
		end
		return nil
	end

	local function has_item(name)
		local now = os.clock()
		if now - _item_cache_time > 0.3 then
			_item_cache = {}
			_item_cache_time = now
			if core.localplayer then
				local inv = core.get_inventory("current_player")
				if inv then
					for _, stack in ipairs(inv.main) do
						if not stack:is_empty() then
							_item_cache[stack:get_name()] = true
						end
					end
				end
			end
		end
		return _item_cache[name] or false
	end

	local function is_node_allowed(name)
		local mode = core.settings:get("schembuilderbot.filter_mode") or "all"
		if mode == "all" then return true end
		if not nlist then return true end
		local list_name = core.settings:get("schembuilderbot.filter_list") or "schembuilder"
		local items = nlist.get(list_name)
		if not items then return true end
		for _, item in ipairs(items) do
			if item == name then
				return mode == "include"
			end
		end
		return mode == "exclude"
	end

	local strategies = {}
	local function register_strategy(name, impl)
		strategies[name] = impl
	end

	register_strategy("closest", {
		find_target = function(nodes, pos, has_item, is_allowed)
			local px, py, pz = pos.x, pos.y, pos.z
			local best_idx, best_dist_sq
			for i, entry in ipairs(nodes) do
				if entry.name ~= "air" and has_item(entry.name) and is_allowed(entry.name) then
					local dx = entry.x - px
					local dy = entry.y - py
					local dz = entry.z - pz
					local dist_sq = dx*dx + dy*dy + dz*dz
					if not best_dist_sq or dist_sq < best_dist_sq then
						best_dist_sq = dist_sq
						best_idx = i
					end
				end
			end
			return best_idx
		end,
	})

	register_strategy("layer", {
		find_target = function(nodes, pos, has_item, is_allowed)
			local px, py, pz = pos.x, pos.y, pos.z
			local by_y = {}
			for i, entry in ipairs(nodes) do
				if entry.name ~= "air" and has_item(entry.name) and is_allowed(entry.name) then
					local y = entry.y
					by_y[y] = by_y[y] or {}
					table.insert(by_y[y], {index = i, entry = entry})
				end
			end
			local ys = {}
			for y, _ in pairs(by_y) do
				table.insert(ys, y)
			end
			table.sort(ys)
			if #ys == 0 then return nil end
			local target_y = ys[1]
			local best_idx, best_dist_sq
			for _, item in ipairs(by_y[target_y]) do
				local dx = item.entry.x - px
				local dy = item.entry.y - py
				local dz = item.entry.z - pz
				local dist_sq = dx*dx + dy*dy + dz*dz
				if not best_dist_sq or dist_sq < best_dist_sq then
					best_dist_sq = dist_sq
					best_idx = item.index
				end
			end
			return best_idx
		end,
		max_batch_y = function(pos) return pos.y end,
		get_needed_items = function(nodes, state)
			if not state or not state.target then return nil end
			local target_y = state.target.y
			local seen = {}
			local items = {}
			for _, entry in ipairs(nodes) do
				if entry.y >= target_y and entry.y <= target_y + 2
					and entry.name ~= "air" and entry.name ~= "ignore"
					and not seen[entry.name] then
					seen[entry.name] = true
					table.insert(items, entry.name)
				end
			end
			return items
		end,
	})

	register_strategy("top_to_bottom", {
		find_target = function(nodes, pos, has_item, is_allowed)
			local px, py, pz = pos.x, pos.y, pos.z
			local by_y = {}
			for i, entry in ipairs(nodes) do
				if entry.name ~= "air" and has_item(entry.name) and is_allowed(entry.name) then
					local y = entry.y
					by_y[y] = by_y[y] or {}
					table.insert(by_y[y], {index = i, entry = entry})
				end
			end
			local ys = {}
			for y, _ in pairs(by_y) do
				table.insert(ys, y)
			end
			table.sort(ys, function(a, b) return a > b end)
			if #ys == 0 then return nil end
			local target_y = ys[1]
			local best_idx, best_dist_sq
			for _, item in ipairs(by_y[target_y]) do
				local dx = item.entry.x - px
				local dy = item.entry.y - py
				local dz = item.entry.z - pz
				local dist_sq = dx*dx + dy*dy + dz*dz
				if not best_dist_sq or dist_sq < best_dist_sq then
					best_dist_sq = dist_sq
					best_idx = item.index
				end
			end
			return best_idx
		end,
		max_batch_y = function(pos) return pos.y end,
		get_needed_items = function(nodes, state)
			if not state or not state.target then return nil end
			local target_y = state.target.y
			local seen = {}
			local items = {}
			for _, entry in ipairs(nodes) do
				if entry.y == target_y and entry.name ~= "air" and entry.name ~= "ignore" and not seen[entry.name] then
					seen[entry.name] = true
					table.insert(items, entry.name)
				end
			end
			return items
		end,
	})

	register_strategy("column", {
		find_target = function(nodes, pos, has_item, is_allowed)
			local px, py, pz = pos.x, pos.y, pos.z
			local by_col = {}
			for i, entry in ipairs(nodes) do
				if entry.name ~= "air" and has_item(entry.name) and is_allowed(entry.name) then
					local key = entry.x .. "," .. entry.z
					by_col[key] = by_col[key] or {}
					table.insert(by_col[key], {index = i, entry = entry})
				end
			end
			local best_col, best_dist_sq
			for _, col in pairs(by_col) do
				local e = col[1].entry
				local dx = e.x - px
				local dz = e.z - pz
				local dist_sq = dx*dx + dz*dz
				if not best_dist_sq or dist_sq < best_dist_sq then
					best_dist_sq = dist_sq
					best_col = col
				end
			end
			if not best_col then return nil end
			local best_idx, best_y
			for _, item in ipairs(best_col) do
				if not best_y or item.entry.y < best_y then
					best_y = item.entry.y
					best_idx = item.index
				end
			end
			return best_idx
		end,
		get_needed_items = function(nodes, state)
			if not state or not state.target then return nil end
			local key = state.target.x .. "," .. state.target.z
			local seen = {}
			local items = {}
			for _, entry in ipairs(nodes) do
				local ek = entry.x .. "," .. entry.z
				if ek == key and entry.name ~= "air" and entry.name ~= "ignore" and not seen[entry.name] then
					seen[entry.name] = true
					table.insert(items, entry.name)
				end
			end
			return items
		end,
	})

	register_strategy("by_material", {
		find_target = function(nodes, pos, has_item, is_allowed)
			local px, py, pz = pos.x, pos.y, pos.z
			local by_name = {}
			for i, entry in ipairs(nodes) do
				if entry.name ~= "air" and has_item(entry.name) and is_allowed(entry.name) then
					local n = entry.name
					by_name[n] = by_name[n] or {}
					table.insert(by_name[n], {index = i, entry = entry})
				end
			end
			local best_group, best_count
			for _, group in pairs(by_name) do
				if not best_count or #group > best_count then
					best_count = #group
					best_group = group
				end
			end
			if not best_group then return nil end
			local best_idx, best_dist_sq
			for _, item in ipairs(best_group) do
				local dx = item.entry.x - px
				local dy = item.entry.y - py
				local dz = item.entry.z - pz
				local dist_sq = dx*dx + dy*dy + dz*dz
				if not best_dist_sq or dist_sq < best_dist_sq then
					best_dist_sq = dist_sq
					best_idx = item.index
				end
			end
			return best_idx
		end,
		batch_filter = function(entry, state)
			return entry.name == state.target.name
		end,
		get_needed_items = function(nodes, state)
			if not state or not state.target then return nil end
			return {state.target.name}
		end,
	})

	register_strategy("random", {
		find_target = function(nodes, pos, has_item, is_allowed)
			local candidates = {}
			for i, entry in ipairs(nodes) do
				if is_allowed(entry.name) then
					table.insert(candidates, i)
				end
			end
			if #candidates == 0 then return nil end
			return candidates[math.random(1, #candidates)]
		end,
		get_needed_items = function() return {} end,
		batch_filter = function() return true end,
	})

	local function pick_random_block()
		local inv = core.get_inventory("current_player")
		if not inv or not inv.main then return nil end
		local pool, total = {}, 0
		for _, stack in ipairs(inv.main) do
			if not stack:is_empty() then
				local name = stack:get_name()
				if core.get_node_def(name) then
					local count = stack:get_count()
					pool[name] = (pool[name] or 0) + count
					total = total + count
				end
			end
		end
		if total == 0 then return nil end
		local r = math.random(1, total)
		local acc = 0
		for name, count in pairs(pool) do
			acc = acc + count
			if r <= acc then return name end
		end
		return nil
	end

	sbots.register_bot("SchemBuilderBot", {
		description = "Bot that builds schematics",
		moving_target = true,
		stand_waiting = true,
		landing_distance = 3,
		cheat_settings = {
			place_cooldown = { type = "number", default = 0.1, min = 0, max = 5 },
			batch_size = { type = "number", default = 8, min = 1, max = 64 },
			place_strategy = { type = "enum", default = "closest", values = {"closest", "layer", "top_to_bottom", "column", "by_material", "random"} },
			filter_mode = { type = "string", default = "all" },
			filter_list = { type = "string", default = "schembuilder" },
		},
		find_pos = function(self, pos)
			if #place_nodes == 0 then return end
			local px, py, pz = pos.x, pos.y, pos.z
			self._current_entry = nil
			self._strat_state = nil

			local name = core.settings:get("schembuilderbot.place_strategy") or "closest"
			local strat = strategies[name] or strategies.closest

			local idx = strat.find_target(place_nodes, pos, has_item, is_node_allowed)
			if idx then
				self._current_entry = place_nodes[idx]
				local target = place_nodes[idx]
				self._strat_state = {
					target = target,
					max_batch_y = strat.max_batch_y and strat.max_batch_y(pos),
				}
				self._is_supply_target = nil
				-- Layer strategy: place 3 layers at once
				if name == "layer" then
					self._strat_state.max_batch_y = target.y + 2
				end
				-- Compute a safe stand position so the player's head isn't in a block
				local safe = compute_safe_stand_pos(target, place_nodes)
				if safe then
					return vector.new(safe.x, safe.y, safe.z)
				end
				return vector.new(target.x, target.y - 1, target.z)
			end

			-- No buildable nodes found, try nearest supply chest
			local closest_key, closest_dist_sq2
			for key, cpos in pairs(supply_chests) do
				local dx = cpos.x - px
				local dy = cpos.y - py
				local dz = cpos.z - pz
				local dist_sq = dx*dx + dy*dy + dz*dz
				if not closest_dist_sq2 or dist_sq < closest_dist_sq2 then
					closest_dist_sq2 = dist_sq
					closest_key = key
				end
			end
			if closest_key then
				self._current_entry = supply_chests[closest_key]
				self._is_supply_target = true
				return supply_chests[closest_key]
			end
		end,
		update_pos = function(self, pos)
			if self._is_supply_target then
				return self._current_entry
			end
			if self._current_entry then
				local found = false
				for _, e in ipairs(place_nodes) do
					if e == self._current_entry then
						found = true
						break
					end
				end
				if found and has_item(self._current_entry.name) then
					return self._current_entry
				end
			end
			self._is_supply_target = nil
			self._current_entry = nil
			return self:find_pos(pos)
		end,
		do_pos = function(self, pos)
			if not self._current_entry then return true end

			if self._is_supply_target then
				self._is_supply_target = nil
				self._current_entry = nil
				local items
				local strat_name = core.settings:get("schembuilderbot.place_strategy") or "closest"
				local strat = strategies[strat_name] or strategies.closest
				if strat.get_needed_items then
					items = strat.get_needed_items(place_nodes, self._strat_state)
				end
				if not items then
					items = {}
					local seen = {}
					for _, entry in ipairs(place_nodes) do
						if entry.name ~= "air" and entry.name ~= "ignore" and not seen[entry.name] then
							seen[entry.name] = true
							table.insert(items, entry.name)
						end
					end
				end
				if #items > 0 then
					local range = tonumber(core.settings:get("schematic_looter.range")) or 5
					ws.loot_list(items, range, 64)
				end
				self.target_pos = nil
				return true
			end

			local cooldown = tonumber(core.settings:get("schembuilderbot.place_cooldown")) or 0.1
			if self._last_place_time and os.clock() - self._last_place_time < cooldown then
				return false
			end
			local batch = tonumber(core.settings:get("schembuilderbot.batch_size")) or 8
			local range = tonumber(core.settings:get("placelitem.range")) or 4
			local strat_name = core.settings:get("schembuilderbot.place_strategy") or "closest"
			local strat = strategies[strat_name] or strategies.closest
			local is_random = strat_name == "random"
			local px, py, pz = pos.x, pos.y, pos.z
			local placed = 0

			-- Place the primary target first
			local target_entry = self._current_entry
			-- Dig any existing node at the target position first
			local tpos = {x = target_entry.x, y = target_entry.y, z = target_entry.z}
			local existing = core.get_node_or_nil(tpos)
			if existing and existing.name ~= "air" and existing.name ~= "ignore" then
				if ws.dig then
					ws.dig(tpos)
				end
			end
			local place_item = is_random and pick_random_block() or target_entry.name
			if place_item and ws.place(target_entry, place_item) then
				self._last_place_time = os.clock()
				for i = #place_nodes, 1, -1 do
					if place_nodes[i] == target_entry then
						table.remove(place_nodes, i)
						break
					end
				end
				placed = 1
			else
				local node = core.get_node_or_nil(target_entry)
				if node and (is_random and node.name ~= "air" or node.name == target_entry.name) then
					for i = #place_nodes, 1, -1 do
						if place_nodes[i] == target_entry then
							table.remove(place_nodes, i)
							break
						end
					end
				end
			end
			self._current_entry = nil

			-- Also place nearby nodes in the same tick
			if placed > 0 and #place_nodes > 0 then
				local max_y = self._strat_state and self._strat_state.max_batch_y
				for i = #place_nodes, 1, -1 do
					if placed >= batch then break end
					local entry = place_nodes[i]
					if entry.name ~= "air" and (not max_y or entry.y <= max_y) and is_node_allowed(entry.name) then
						if not strat.batch_filter or strat.batch_filter(entry, self._strat_state) then
							local dx = entry.x - px
							local dy = entry.y - py
							local dz = entry.z - pz
							if dx*dx + dy*dy + dz*dz <= range*range then
								local batch_item = is_random and pick_random_block() or entry.name
								if batch_item then
									local epos = {x = entry.x, y = entry.y, z = entry.z}
									local enode = core.get_node_or_nil(epos)
									if enode and enode.name ~= "air" and enode.name ~= "ignore" then
										if ws.dig then ws.dig(epos) end
									end
								end
								if batch_item and ws.place(entry, batch_item) then
									table.remove(place_nodes, i)
									placed = placed + 1
								else
									local node = core.get_node_or_nil(entry)
									if node and (is_random and node.name ~= "air" or node.name == entry.name) then
										table.remove(place_nodes, i)
									end
								end
							end
						end
					end
				end
			end

			self.target_pos = nil
			update_hud()
			save_job()
			return true
		end,
		do_step = function(self, dtime)
			-- If target was placed by PlaceLiteM, reset
			if self._current_entry then
				local found = false
				for _, e in ipairs(place_nodes) do
					if e == self._current_entry then
						found = true
						break
					end
				end
				if not found then
					self._current_entry = nil
					self.stage = 0
				end
			end
		end,
	})
end
