-- Shared bot factory for schembuilder bots
-- Used by: SchemBuilderBot (walk), RhythmBuildBot (teleport)
if sbots and sbots.register_bot then
	function schembuilder.create_bot(name, description, movement_type, extra_opts)
		extra_opts = extra_opts or {}
		local item_cache = schembuilder.placer.make_item_cache()
		local strategies = schembuilder.placer.strategies

		local function has_item(name)
			return item_cache.has(name)
		end

		local function is_node_allowed(name)
			local mode = core.settings:get(name .. ".filter_mode") or "all"
			local list_name = core.settings:get(name .. ".filter_list") or "schembuilder"
			return schembuilder.placer.is_node_allowed(name, mode, list_name)
		end

		sbots.register_bot(description, {
			description = description,
			movement = movement_type,
			stand_waiting = true,
			landing_distance = 3,
			cheat_settings = {
				place_cooldown = { type = "number", default = 0.1, min = 0, max = 5 },
				batch_size = { type = "number", default = 8, min = 1, max = 64 },
				range = { type = "number", default = 4, min = 1, max = 20 },
				place_strategy = { type = "enum", default = "cluster", values = {"closest", "layer", "top_to_bottom", "column", "by_material", "random", "cluster"} },
				filter_mode = { type = "string", default = "all" },
				filter_list = { type = "string", default = "schembuilder" },
			},
			setting = name:lower(),
			find_pos = function(self, pos)
				if #place_nodes == 0 then return end
				local px, py, pz = pos.x, pos.y, pos.z
				self._current_entry = nil
				self._strat_state = nil
				local setting_pref = self._setting or name:lower()

				local strat_name = core.settings:get(setting_pref .. ".place_strategy") or "cluster"
				local strat = strategies[strat_name] or strategies.closest

				local idx = schembuilder.placer.find_target(strat, place_nodes, pos, has_item, is_node_allowed, self)
				if idx then
					self._current_entry = place_nodes[idx]
					local target = place_nodes[idx]
					self._strat_state = {
						target = target,
						max_batch_y = strat.max_batch_y and strat.max_batch_y(pos),
					}
					self._is_supply_target = nil
					if strat_name == "layer" then
						self._strat_state.max_batch_y = target.y + 2
					end
					local safe
					if strat.find_stand_pos then
						safe = strat.find_stand_pos(place_nodes, pos, self)
					else
						safe = schembuilder.placer.compute_safe_stand_pos(target, place_nodes)
					end
					if safe then
						return vector.new(safe.x, safe.y, safe.z)
					end
					return vector.new(target.x, target.y - 1, target.z)
				end

				local chest = schembuilder.placer.find_closest_supply_chest(pos)
				if chest then
					self._current_entry = chest
					self._is_supply_target = true
					return chest
				end
			end,
			update_pos = function(self, pos)
				if self._is_supply_target then
					return self._current_entry
				end
				if self._cluster_state then
					if self._cluster_stand_pos then
						local has_work = false
						for _, e in ipairs(self._cluster_state.entries) do
							if e.name ~= "air" and has_item(e.name) then
								has_work = true
								break
							end
						end
						if has_work then
							return self._cluster_stand_pos
						end
					end
					self._cluster_state = nil
					self._cluster_stand_pos = nil
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
					local setting_pref = self._setting or name:lower()
					local strat_name = core.settings:get(setting_pref .. ".place_strategy") or "cluster"
					local strat = strategies[strat_name] or strategies.closest
					local items
					if strat.get_needed_items then
						items = strat.get_needed_items(place_nodes, self._strat_state, self)
					end
					if not items then
						items = schembuilder.placer.get_needed_items(place_nodes)
					end
					if #items > 0 then
						local range = tonumber(core.settings:get("schematic_looter.range")) or 5
						ws.loot_list(items, range, 64)
					end
					self.target_pos = nil
					return true
				end

				local setting_pref = self._setting or name:lower()
				local placer_state = {
					_last_place_time = self._last_place_time,
					_strat_state = self._strat_state,
					_cluster_state = self._cluster_state,
					_cluster_stand_pos = self._cluster_stand_pos,
				}
				local opts = {
					batch_size = tonumber(core.settings:get(setting_pref .. ".batch_size")) or 8,
					range = tonumber(core.settings:get(setting_pref .. ".range")) or 4,
					cooldown = tonumber(core.settings:get(setting_pref .. ".place_cooldown")) or 0.1,
					strategy_name = core.settings:get(setting_pref .. ".place_strategy") or "cluster",
					filter_mode = core.settings:get(setting_pref .. ".filter_mode") or "all",
					filter_list = core.settings:get(setting_pref .. ".filter_list") or "schembuilder",
					item_cache = item_cache,
				}
				local placed = schembuilder.placer.execute_batch(placer_state, self._current_entry, pos, place_nodes, opts)

				self._last_place_time = placer_state._last_place_time
				self._strat_state = placer_state._strat_state
				self._cluster_state = placer_state._cluster_state
				self._cluster_stand_pos = placer_state._cluster_stand_pos
				self._current_entry = nil
				self.target_pos = nil
				return true
			end,
			do_step = function(self, dtime)
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
				if self._cluster_state then
					local i = #self._cluster_state.entries
					while i >= 1 do
						local ce = self._cluster_state.entries[i]
						local found = false
						for _, e in ipairs(place_nodes) do
							if e == ce then found = true; break end
						end
						if not found then
							table.remove(self._cluster_state.entries, i)
						end
						i = i - 1
					end
				end
			end,
		})
	end
end
