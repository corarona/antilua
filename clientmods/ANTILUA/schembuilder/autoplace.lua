ws.rg("AutoSchemPlace", {
	category = "Place",
	setting = "autoschemplace",
	description = "Auto-place schematic nodes within range using strategy system",
	on_step = function(self, dtime)
		if #place_nodes == 0 then
			if hud_id then
				core.localplayer:hud_remove(hud_id)
				hud_id = nil
			end
			return
		end
		local pp = core.localplayer:get_pos()
		if not pp then return end

		local range = tonumber(core.settings:get("autoschemplace.range")) or 4
		local strat_name = core.settings:get("autoschemplace.place_strategy") or "closest"
		local strat = schembuilder.placer.strategies[strat_name] or schembuilder.placer.strategies.closest
		local item_cache = self._item_cache or schembuilder.placer.make_item_cache()
		self._item_cache = item_cache

		local has_item = function(name) return item_cache.has(name) end
		local is_allowed = function(name)
			local mode = core.settings:get("autoschemplace.filter_mode") or "all"
			local list = core.settings:get("autoschemplace.filter_list") or "schembuilder"
			return schembuilder.placer.is_node_allowed(name, mode, list)
		end

		local placer_state = self._placer_state or {}
		self._placer_state = placer_state

		-- Find target from nodes within range
		local candidates = {}
		for i, entry in ipairs(place_nodes) do
			if entry.name ~= "air" and has_item(entry.name) and is_allowed(entry.name) then
				local dx = entry.x - pp.x
				local dy = entry.y - pp.y
				local dz = entry.z - pp.z
				if dx*dx + dy*dy + dz*dz <= range*range then
					table.insert(candidates, i)
				end
			end
		end

		if #candidates == 0 then
			-- Try supply chests
			local closest_key, closest_dsq
			for key, cpos in pairs(supply_chests) do
				local dx = cpos.x - pp.x
				local dy = cpos.y - pp.y
				local dz = cpos.z - pp.z
				local dsq = dx*dx + dy*dy + dz*dz
				if not closest_dsq or dsq < closest_dsq then
					closest_dsq = dsq
					closest_key = key
				end
			end
			if closest_key then
				-- Loot supply chest
				local items = schembuilder.placer.get_needed_items(place_nodes)
				if #items > 0 then
					local lrange = tonumber(core.settings:get("schematic_looter.range")) or 5
					ws.loot_list(items, lrange, 64)
				end
			end
			return
		end

		-- Pick target using strategy
		local idx = schembuilder.placer.find_target(strat, place_nodes, pp, has_item, is_allowed, placer_state)
		if not idx then return end
		local target_entry = place_nodes[idx]

		local opts = {
			batch_size = tonumber(core.settings:get("autoschemplace.batch_size")) or 4,
			range = range,
			cooldown = 0,
			strategy_name = strat_name,
			filter_mode = core.settings:get("autoschemplace.filter_mode") or "all",
			filter_list = core.settings:get("autoschemplace.filter_list") or "schembuilder",
			item_cache = item_cache,
		}

		local placed = schembuilder.placer.execute_batch(placer_state, target_entry, pp, place_nodes, opts)
		if placed > 0 then
			update_hud()
			save_job()
		end
	end,
	on_start = function(self)
		self._placer_state = {}
		self._item_cache = nil
		core.after(0.2, update_hud)
	end,
	on_stop = function(self)
		if hud_id then
			core.localplayer:hud_remove(hud_id)
			hud_id = nil
		end
	end,
	cheat_settings = {
		range = { type = "number", default = 4, min = 1, max = 20 },
		batch_size = { type = "number", default = 4, min = 1, max = 64 },
		place_strategy = { type = "enum", default = "closest",
			values = {"closest", "layer", "top_to_bottom", "column", "by_material", "random", "cluster"} },
		filter_mode = { type = "enum", default = "all", values = {"all", "include", "exclude"} },
		filter_list = { type = "string", default = "schembuilder" },
	},
})
