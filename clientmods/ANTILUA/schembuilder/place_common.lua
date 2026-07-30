-- Shared placement engine for schembuilder
-- Used by: SchemBuilderBot, AutoSchemPlace, RhythmBuildBot
schembuilder.placer = {}
local has_nlist = rawget(_G, "nlist") and type(rawget(_G, "nlist").get) == "function"

local placer = schembuilder.placer

-- Item cache (per-caller, passed as state)
local function make_item_cache()
	local cache = {}
	local cache_time = 0
	return {
		has = function(name)
			local now = os.clock()
			if now - cache_time > 0.3 then
				cache = {}
				cache_time = now
				if core.localplayer then
					local inv = core.get_inventory("current_player")
					if inv then
						for _, stack in ipairs(inv.main) do
							if not stack:is_empty() then
								cache[stack:get_name()] = true
							end
						end
					end
				end
			end
			return cache[name] or false
		end,
	}
end

placer.make_item_cache = make_item_cache


-- Helpers

function placer.compute_safe_stand_pos(target, nodes)
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

		if not place_set[sx .. "," .. head_y .. "," .. sz] then
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

function placer.grid_cluster_nodes(nodes, cell_size)
	local clusters = {}
	for _, entry in ipairs(nodes) do
		if entry.name ~= "air" and entry.name ~= "ignore" then
			local cx = math.floor(entry.x / cell_size)
			local cy = math.floor(entry.y / cell_size)
			local cz = math.floor(entry.z / cell_size)
			local key = cx .. "," .. cy .. "," .. cz
			if not clusters[key] then
				clusters[key] = {entries = {}}
			end
			table.insert(clusters[key].entries, entry)
		end
	end
	for _, cl in pairs(clusters) do
		local sx, sy, sz = 0, 0, 0
		for _, e in ipairs(cl.entries) do
			sx = sx + e.x; sy = sy + e.y; sz = sz + e.z
		end
		local n = #cl.entries
		cl.centroid = {x = sx / n, y = sy / n, z = sz / n}
	end
	return clusters
end

function placer.find_best_stand_pos(cluster_entries, place_set, range, player_pos)
	if #cluster_entries == 0 then return nil end

	-- Compute cluster bounds and centroid
	local cx, cy, cz = 0, 0, 0
	local minx, miny, minz = math.huge, math.huge, math.huge
	local maxx, maxy, maxz = -math.huge, -math.huge, -math.huge
	for _, e in ipairs(cluster_entries) do
		cx = cx + e.x; cy = cy + e.y; cz = cz + e.z
		if e.x < minx then minx = e.x end
		if e.y < miny then miny = e.y end
		if e.z < minz then minz = e.z end
		if e.x > maxx then maxx = e.x end
		if e.y > maxy then maxy = e.y end
		if e.z > maxz then maxz = e.z end
	end
	local n = #cluster_entries
	cx, cy, cz = cx / n, cy / n, cz / n

	-- Expand bounds for the stand position search
	minx = minx - 1; miny = miny - 2; minz = minz - 1
	maxx = maxx + 1; maxy = maxy + 1; maxz = maxz + 1

	-- Pre-compute centroid distance square for quick comparison
	-- Instead of scoring each candidate against all entries, score against centroid
	local range_sq = range * range
	local px, py, pz = player_pos.x, player_pos.y, player_pos.z

	local best_pos, best_score

	for sy = miny, maxy do
		for sx = minx, maxx do
			for sz = minz, maxz do
				-- Only check perimeter positions (first/last row/col on each axis)
				-- This avoids checking interior positions that are likely inside the structure
				if sx == minx or sx == maxx or sy == miny or sy == maxy or sz == minz or sz == maxz then
					local head_key = sx .. "," .. (sy + 1) .. "," .. sz
					if not place_set[head_key] then
						local node
						if core.get_node_or_nil then
							node = core.get_node_or_nil({x = sx, y = sy + 1, z = sz})
						end
						local blocked = node and node.name ~= "air"
							and node.name ~= "ignore"
							and (not core.registered_nodes or not core.registered_nodes[node.name]
								or not core.registered_nodes[node.name].buildable_to)
						if not blocked then
							-- Score based on proximity to centroid (higher is better)
							local dx = sx - cx; local dy = sy - cy; local dz = sz - cz
							local score = range_sq / (1 + dx * dx + dy * dy + dz * dz)
							-- Tiebreaker: closer to player
							local pdx = sx - px; local pdy = sy - py; local pdz = sz - pz
							score = score + 0.5 / (1 + math.sqrt(pdx * pdx + pdy * pdy + pdz * pdz))
							if not best_score or score > best_score then
								best_score = score
								best_pos = {x = sx, y = sy, z = sz}
							end
						end
					end
				end
			end
		end
	end
	return best_pos
end

function placer.is_head_safe(player_pos, target_pos)
	local sx = math.floor(player_pos.x + 0.5)
	local sy = math.floor(player_pos.y + 0.5)
	local sz = math.floor(player_pos.z + 0.5)
	return not (target_pos.x == sx and target_pos.y == sy + 1 and target_pos.z == sz)
end

function placer.find_closest_supply_chest(pos)
	local px, py, pz = pos.x, pos.y, pos.z
	local closest_key, closest_dist_sq, closest_pos
	for key, cpos in pairs(supply_chests) do
		local dx = cpos.x - px
		local dy = cpos.y - py
		local dz = cpos.z - pz
		local dist_sq = dx*dx + dy*dy + dz*dz
		if not closest_dist_sq or dist_sq < closest_dist_sq then
			closest_dist_sq = dist_sq
			closest_key = key
			closest_pos = cpos
		end
	end
	if closest_key then
		-- Validate the chest still exists
		local node = core.get_node_or_nil(closest_pos)
		if not node or node.name == "air" then
			supply_chests[closest_key] = nil
			return nil
		end
		return closest_pos
	end
	return nil
end

function placer.get_needed_items(nodes)
	local items = {}
	local seen = {}
	for _, entry in ipairs(nodes) do
		if entry.name ~= "air" and entry.name ~= "ignore" and not seen[entry.name] then
			seen[entry.name] = true
			table.insert(items, entry.name)
		end
	end
	return items
end

function placer.is_node_allowed(name, filter_mode, filter_list)
	if filter_mode == "all" then return true end
	if not has_nlist then return true end
	local ok, items = pcall(nlist.get, filter_list)
	if not ok or not items then return true end
	for _, item in ipairs(items) do
		if item == name then
			return filter_mode == "include"
		end
	end
	return filter_mode == "exclude"
end

function placer.filter_nodes(nodes, pos, has_item, is_allowed)
	local filtered = {}
	local px, py, pz = pos.x, pos.y, pos.z
	for i, entry in ipairs(nodes) do
		if entry.name ~= "air" and has_item(entry.name) and is_allowed(entry.name) then
			local dx = entry.x - px
			local dy = entry.y - py
			local dz = entry.z - pz
			filtered[#filtered + 1] = {
				index = i,
				entry = entry,
				dist_sq = dx*dx + dy*dy + dz*dz,
			}
		end
	end
	return filtered
end

function placer.find_target(strategy, nodes, pos, has_item, is_allowed, state)
	if strategy == placer.strategies.cluster then
		return strategy.find_target(nodes, pos, has_item, is_allowed, state)
	end
	local filtered = placer.filter_nodes(nodes, pos, has_item, is_allowed)
	return strategy.find_target(filtered, pos, has_item, is_allowed, state)
end

-- Strategy system

placer.strategies = {}

function placer.register_strategy(name, impl)
	placer.strategies[name] = impl
end

placer.register_strategy("closest", {
	find_target = function(filtered, pos, has_item, is_allowed, state)
		local best
		for _, item in ipairs(filtered) do
			if not best or item.dist_sq < best.dist_sq then
				best = item
			end
		end
		return best and best.index
	end,
})

placer.register_strategy("layer", {
	find_target = function(filtered, pos, has_item, is_allowed, state)
		local by_y = {}
		for _, item in ipairs(filtered) do
			local y = item.entry.y
			by_y[y] = by_y[y] or {}
			table.insert(by_y[y], item)
		end
		local ys = {}
		for y, _ in pairs(by_y) do
			table.insert(ys, y)
		end
		table.sort(ys)
		if #ys == 0 then return nil end
		local best
		for _, item in ipairs(by_y[ys[1]]) do
			if not best or item.dist_sq < best.dist_sq then
				best = item
			end
		end
		return best and best.index
	end,
	max_batch_y = function(pos) return pos.y end,
})

placer.register_strategy("top_to_bottom", {
	find_target = function(filtered, pos, has_item, is_allowed, state)
		local by_y = {}
		for _, item in ipairs(filtered) do
			local y = item.entry.y
			by_y[y] = by_y[y] or {}
			table.insert(by_y[y], item)
		end
		local ys = {}
		for y, _ in pairs(by_y) do
			table.insert(ys, y)
		end
		table.sort(ys, function(a, b) return a > b end)
		if #ys == 0 then return nil end
		local best
		for _, item in ipairs(by_y[ys[1]]) do
			if not best or item.dist_sq < best.dist_sq then
				best = item
			end
		end
		return best and best.index
	end,
	max_batch_y = function(pos) return pos.y end,
})

placer.register_strategy("column", {
	find_target = function(filtered, pos, has_item, is_allowed, state)
		local px, pz = pos.x, pos.z
		local by_col = {}
		for _, item in ipairs(filtered) do
			local key = item.entry.x .. "," .. item.entry.z
			by_col[key] = by_col[key] or {}
			table.insert(by_col[key], item)
		end
		local best_col, best_col_dsq
		for _, col in pairs(by_col) do
			local e = col[1].entry
			local dx = e.x - px
			local dz = e.z - pz
			local dsq = dx*dx + dz*dz
			if not best_col_dsq or dsq < best_col_dsq then
				best_col_dsq = dsq
				best_col = col
			end
		end
		if not best_col then return nil end
		local best
		for _, item in ipairs(best_col) do
			if not best or item.entry.y < best.entry.y then
				best = item
			end
		end
		return best and best.index
	end,
})

placer.register_strategy("by_material", {
	find_target = function(filtered, pos, has_item, is_allowed, state)
		local by_name = {}
		for _, item in ipairs(filtered) do
			local n = item.entry.name
			by_name[n] = by_name[n] or {}
			table.insert(by_name[n], item)
		end
		local best_group
		for _, group in pairs(by_name) do
			if not best_group or #group > #best_group then
				best_group = group
			end
		end
		if not best_group then return nil end
		local best
		for _, item in ipairs(best_group) do
			if not best or item.dist_sq < best.dist_sq then
				best = item
			end
		end
		return best and best.index
	end,
	batch_filter = function(entry, state)
		return entry.name == state.target.name
	end,
})

placer.register_strategy("cluster", {
	find_target = function(nodes, pos, has_item, is_allowed, state)
		if state._cluster_state then
			local remaining = false
			for _, e in ipairs(state._cluster_state.entries) do
				if e.name ~= "air" and has_item(e.name) and is_allowed(e.name) then
					remaining = true
					break
				end
			end
			if not remaining then
				state._cluster_state = nil
			else
				local best_idx, best_dist_sq
				for i, entry in ipairs(nodes) do
					if entry.name ~= "air" and has_item(entry.name) and is_allowed(entry.name) then
						local in_cluster = false
						for _, ce in ipairs(state._cluster_state.entries) do
							if ce == entry then in_cluster = true; break end
						end
						if in_cluster then
							local dx = entry.x - pos.x
							local dy = entry.y - pos.y
							local dz = entry.z - pos.z
							local d2 = dx*dx + dy*dy + dz*dz
							if not best_dist_sq or d2 < best_dist_sq then
								best_dist_sq = d2
								best_idx = i
							end
						end
					end
				end
				return best_idx
			end
		end

		local range = tonumber(core.settings:get("schembuilder.range")) or 4
		local clusters = placer.grid_cluster_nodes(nodes, range)
		local best_key, best_dist_sq
		for key, cl in pairs(clusters) do
			local has_work = false
			for _, e in ipairs(cl.entries) do
				if e.name ~= "air" and has_item(e.name) and is_allowed(e.name) then
					has_work = true
					break
				end
			end
			if has_work then
				local dx = cl.centroid.x - pos.x
				local dy = cl.centroid.y - pos.y
				local dz = cl.centroid.z - pos.z
				local d2 = dx*dx + dy*dy + dz*dz
				if not best_dist_sq or d2 < best_dist_sq then
					best_dist_sq = d2
					best_key = key
				end
			end
		end

		if best_key then
			state._cluster_state = clusters[best_key]
			state._cluster_stand_pos = nil
			local best_idx, best_d2
			for i, entry in ipairs(nodes) do
				if entry.name ~= "air" and has_item(entry.name) and is_allowed(entry.name) then
					local in_cluster = false
					for _, ce in ipairs(state._cluster_state.entries) do
						if ce == entry then in_cluster = true; break end
					end
					if in_cluster then
						local dx = entry.x - pos.x
						local dy = entry.y - pos.y
						local dz = entry.z - pos.z
						local d2 = dx*dx + dy*dy + dz*dz
						if not best_d2 or d2 < best_d2 then
							best_d2 = d2
							best_idx = i
						end
					end
				end
			end
			return best_idx
		end
		return nil
	end,
	find_stand_pos = function(nodes, pos, state)
		if not state._cluster_state then return nil end
		local range = tonumber(core.settings:get("schembuilder.range")) or 4
		local place_set = {}
		for _, entry in ipairs(nodes) do
			if entry.name ~= "air" then
				place_set[entry.x .. "," .. entry.y .. "," .. entry.z] = true
			end
		end
		local best = placer.find_best_stand_pos(state._cluster_state.entries, place_set, range, pos)
		if best then
			state._cluster_stand_pos = best
		end
		return best
	end,
	batch_filter = function(entry, batch_state, placer_state)
		if not placer_state._cluster_state then return false end
		for _, ce in ipairs(placer_state._cluster_state.entries) do
			if ce == entry then return true end
		end
		return false
	end,
})

placer.register_strategy("random", {
	find_target = function(filtered, pos, has_item, is_allowed, state)
		if #filtered == 0 then return nil end
		return filtered[math.random(1, #filtered)].index
	end,
	batch_filter = function() return true end,
})


-- Core batch placement function
-- placer_state: { _last_place_time, _strat_state, _cluster_state, _cluster_stand_pos }
-- opts: { batch_size, range, cooldown, strategy_name, filter_mode, filter_list, item_cache }
-- Returns: number placed
function placer.execute_batch(placer_state, target_entry, player_pos, nodes, opts)
	local cooldown = tonumber(opts.cooldown) or 0.1
	if placer_state._last_place_time and core.get_us_time() / 1000000 - placer_state._last_place_time < cooldown then
		return 0
	end
	local batch = tonumber(opts.batch_size) or 4
	local range = tonumber(opts.range) or 4
	local strat_name = opts.strategy_name or "cluster"
	local strat = placer.strategies[strat_name] or placer.strategies.closest
	local filter_mode = opts.filter_mode or "all"
	local filter_list = opts.filter_list or "schembuilder"
	local item_cache = opts.item_cache or make_item_cache()

	local px, py, pz = player_pos.x, player_pos.y, player_pos.z
	local placed = 0
	local removed_entries = {}

	-- Place the primary target first
	-- Dig any existing node at the target position
	local tpos = {x = target_entry.x, y = target_entry.y, z = target_entry.z}
	local existing = core.get_node_or_nil(tpos)
	if existing and existing.name ~= "air" and existing.name ~= "ignore" then
		if ws.dig then
			ws.dig(tpos)
		end
	end
	local place_item = target_entry.name
	local place_fn
	if target_entry.param2 and target_entry.param2 ~= 0 then
		place_fn = function(p) core.place_node(p) end
	end
	if place_item and ws.place(target_entry, place_item, nil, place_fn) then
		placer_state._last_place_time = core.get_us_time() / 1000000
		for i = #nodes, 1, -1 do
			if nodes[i] == target_entry then
				table.insert(removed_entries, nodes[i])
				table.remove(nodes, i)
				break
			end
		end
		placed = 1
	else
		local node = core.get_node_or_nil(target_entry)
		if node and node.name == target_entry.name then
			for i = #nodes, 1, -1 do
				if nodes[i] == target_entry then
					table.insert(removed_entries, nodes[i])
					table.remove(nodes, i)
					break
				end
			end
		end
	end

	-- Also place nearby nodes in the same tick
	if placed > 0 and #nodes > 0 then
		local max_y = placer_state._strat_state and placer_state._strat_state.max_batch_y
		for i = #nodes, 1, -1 do
			if placed >= batch then break end
			local entry = nodes[i]
			if entry.name ~= "air" and (not max_y or entry.y <= max_y)
				and placer.is_node_allowed(entry.name, filter_mode, filter_list) then
				if not strat.batch_filter or strat.batch_filter(entry, placer_state._strat_state, placer_state) then
					local dx = entry.x - px
					local dy = entry.y - py
					local dz = entry.z - pz
					if dx*dx + dy*dy + dz*dz <= range*range then
						if placer.is_head_safe(player_pos, entry) then
							local batch_item = entry.name
							local batch_place_fn
							if entry.param2 and entry.param2 ~= 0 then
								batch_place_fn = function(p) core.place_node(p) end
							end
							if batch_item then
								local epos = {x = entry.x, y = entry.y, z = entry.z}
								local enode = core.get_node_or_nil(epos)
								if enode and enode.name ~= "air" and enode.name ~= "ignore" then
									if ws.dig then ws.dig(epos) end
								end
							end
							if batch_item and ws.place(entry, batch_item, nil, batch_place_fn) then
								table.insert(removed_entries, entry)
								table.remove(nodes, i)
								placed = placed + 1
							else
								local node = core.get_node_or_nil(entry)
								if node and node.name == entry.name then
									table.insert(removed_entries, entry)
									table.remove(nodes, i)
								end
							end
						end
					end
				end
			end
		end
	end

	-- Sync cluster state: remove placed entries
	if placer_state._cluster_state then
		local i = #placer_state._cluster_state.entries
		while i >= 1 do
			local ce = placer_state._cluster_state.entries[i]
			local found = false
			for _, e in ipairs(nodes) do
				if e == ce then found = true; break end
			end
			if not found then
				table.remove(placer_state._cluster_state.entries, i)
			end
			i = i - 1
		end
	end

	if #removed_entries > 0 then
		push_undo(removed_entries)
	end

	update_hud()
	save_job()
	return placed
end
