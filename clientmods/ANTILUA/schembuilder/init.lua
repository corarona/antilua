local modpath = core.get_modpath(core.get_current_modname())

local schembuilder = {pos1={x=nil,y=nil,z=nil}, pos2={x=nil,y=nil,z=nil}}
local place_nodes = {}
local supply_chests = {}

local storage
if type(core.get_mod_storage) == "function" then
	local ok, mod = pcall(core.get_mod_storage, "schembuilder")
	if ok then storage = mod end
end

local function save_job()
	if not storage then return end
	local data = core.write_json(place_nodes)
	storage:set_string("job_data", data or "[]")
end

local function load_job()
	if not storage then return false end
	local data = storage:get_string("job_data")
	if data and data ~= "" then
		local ok, nodes = pcall(core.parse_json, data)
		if ok and type(nodes) == "table" and #nodes > 0 then
			place_nodes = nodes
			return true
		end
	end
	return false
end

local function clear_job()
	if not storage then return end
	storage:set_string("job_data", "")
end

local function chest_key(pos)
	return math.floor(pos.x) .. "," .. math.floor(pos.y) .. "," .. math.floor(pos.z)
end

local function clear_supply_chests()
	supply_chests = {}
end

local function add_supply_chest(pos)
	supply_chests[chest_key(pos)] = {x = math.floor(pos.x), y = math.floor(pos.y), z = math.floor(pos.z)}
end

local function deserialize_workaround(content)
	local nodes, err = core.deserialize(content, true)
	if err then
		core.log("warning", "schembuilder: deserialize: " .. err)
	end
	return nodes or {}
end

local function get_preview_texture(name)
	local def = core.get_node_def(name)
	if def then
		if def.tiles and def.tiles[1] and def.tiles[1] ~= "" then
			local tex = def.tiles[1]
			if tex:find("%^") then
				tex = tex:match("^([^%^]+)")
			end
			return tex
		end
		if def.inventory_image and def.inventory_image ~= "" then
			return def.inventory_image
		end
	end
	return "unknown_node.png"
end

local function add_preview_particle(pos, node_name)
	local tex = get_preview_texture(node_name)
	if tex == "unknown_node.png" then return end
	core.add_particle({
		pos = vector.new(math.floor(pos.x), math.floor(pos.y), math.floor(pos.z)),
		velocity = {x=0, y=0, z=0},
		acceleration = {x=0, y=0, z=0},
		expirationtime = 9999,
		size = 12,
		collisiondetection = false,
		collision_removal = false,
		vertical = false,
		texture = tex .. "^[opacity:191",
		glow = 14,
	})
end

-- Only add a particle if the target isn't already in place
local function add_preview_if_needed(pos, node_name)
	local current = core.get_node_or_nil(pos)
	if current and current.name == node_name then
		return
	end
	add_preview_particle(pos, node_name)
end

local function load_schematic(value)
	local content = value:match("^5:(.*)$")
	if not content then
		return nil
	end
	return deserialize_workaround(content)
end

local function load_schematic_nodes(value, pos)
	if not value or value == "" then
		return nil
	end
	local nodes, count

	-- Try base64 MTS (new format)
	local raw = core.decode_base64(value)
	if raw and raw ~= "" then
		local ok, schem = pcall(core.read_schematic, raw, {})
		if ok and schem and schem.data then
			nodes = {}
			for _, entry in ipairs(schem.data) do
				if entry.name == "air" or entry.prob == 0 then
					goto skip
				end
				table.insert(nodes, {
					x = pos.x + (entry.x or 0),
					y = pos.y + (entry.y or 0),
					z = pos.z + (entry.z or 0),
					name = entry.name,
				})
				::skip::
			end
			count = #nodes
			if count > 0 then
				clear_supply_chests()
				place_nodes = nodes
				for _, n in ipairs(nodes) do add_preview_if_needed(n, n.name) end
				ws.notify("Loaded " .. count .. " nodes", ws.NOTIFY_INFO)
				core.after(0.1, update_hud)
			end
			return count
		end
	end

	-- Try WorldEdit string format (old format)
	local we_nodes = load_schematic(value)
	if we_nodes then
		clear_supply_chests()
		place_nodes = {}
		local ox, oy, oz = pos.x, pos.y, pos.z
		for _, entry in ipairs(we_nodes) do
			if entry.name == "air" then goto skip2 end
			entry.x, entry.y, entry.z = ox + entry.x, oy + entry.y, oz + entry.z
			table.insert(place_nodes, entry)
			add_preview_if_needed(entry, entry.name)
			::skip2::
		end
		if #place_nodes > 0 then
			ws.notify("Loaded " .. #place_nodes .. " nodes", ws.NOTIFY_INFO)
			core.after(0.1, update_hud)
		end
		return #place_nodes
	end

	return nil
end

local function format_per_item(count)
	local sh_size = 27 * 64
	local shulkers = math.floor(count / sh_size)
	local after_sh = count % sh_size
	local stacks = math.floor(after_sh / 64)
	local items = after_sh % 64

	local parts = {}
	if shulkers > 0 then
		table.insert(parts, shulkers .. "sh")
	end
	if stacks > 0 then
		table.insert(parts, stacks .. "s")
	end
	if items > 0 or #parts == 0 then
		table.insert(parts, items .. "i")
	end
	return table.concat(parts, ", ")
end

local hud_id = nil

local function update_hud()
	if not core.localplayer then return end
	if #place_nodes == 0 then
		clear_job()
		if hud_id then
			core.localplayer:hud_remove(hud_id)
			hud_id = nil
		end
		return
	end
	-- Count nodes by name
	local counts = {}
	for _, entry in ipairs(place_nodes) do
		local n = entry.name
		if n ~= "air" then
			counts[n] = (counts[n] or 0) + 1
		end
	end
	-- Build sorted list
	local sorted = {}
	for name, count in pairs(counts) do
		table.insert(sorted, {name = name, count = count})
	end
	table.sort(sorted, function(a, b) return a.count > b.count end)
	-- Truncate to top 45
	local lines = {"Missing:"}
	local total = 0
	for i = 1, math.min(#sorted, 45) do
		local s = sorted[i]
		table.insert(lines, format_per_item(s.count) .. " X " .. s.name)
		total = total + s.count
	end
	if #sorted > 45 then
		table.insert(lines, "... +" .. (#sorted - 45) .. " more")
	end
	table.insert(lines, "Total: " .. total)

	local text = table.concat(lines, "\n")

	if hud_id then
		core.localplayer:hud_change(hud_id, "text", text)
	else
		hud_id = core.localplayer:hud_add({
			hud_elem_type = "text",
			direction = 0,
			position = {x = 0.85, y = 0.05},
			alignment = {x = 1, y = 1},
			offset = {x = 0, y = 0},
			number = 0x00FF00,
			text = text,
		})
	end
end

ws.rg("PlaceLiteM", {
	category = "Place",
	setting = "placelitem",
	on_step = function(self, dtime)
		if #place_nodes == 0 then
			if hud_id then
				core.localplayer:hud_remove(hud_id)
				hud_id = nil
			end
			return
		end
		local pp = vector.round(core.localplayer:get_pos())
		local range = tonumber(core.settings:get("placelitem.range")) or 4

		local changed = false
		for i = #place_nodes, 1, -1 do
			local entry = place_nodes[i]
			if math.abs(entry.x - pp.x) <= range
			and math.abs(entry.y - pp.y) <= range
			and math.abs(entry.z - pp.z) <= range then
				local pos_v = vector.new(entry.x, entry.y, entry.z)
				if entry.name == "air" then
					local node = core.get_node_or_nil(pos_v)
					if node and node.name ~= "air" then
						ws.dig(pos_v)
						table.remove(place_nodes, i)
						changed = true
					end
				else
					if ws.place(pos_v, entry.name) then
						table.remove(place_nodes, i)
						changed = true
					end
				end
			end
			::continue::
		end
		if changed then
			update_hud()
			save_job()
		end
	end,
	on_start = function(self)
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
	},
})



local function do_schembuild(param, use_pos)
	if param == "" then
		return false, "Need an argument to load"
	end
	local pos = use_pos or (core.localplayer and vector.round(core.localplayer:get_pos()))
	if not pos then
		return false, "No position available"
	end
	local value

	-- file:<path> — load an MTS file from disk
	if param:match("^file:") then
		local filepath = param:sub(6)
		local ok, data = pcall(core.read_file, filepath)
		if not ok or not data then
			return false, "File not found: " .. filepath
		end
		local ok2, schem = pcall(core.read_schematic, data, {})
		if not ok2 or not schem or not schem.data then
			return false, "Failed to parse MTS file"
		end
		clear_supply_chests()
		place_nodes = {}
		for _, entry in ipairs(schem.data) do
			if entry.name == "air" or entry.prob == 0 then goto skip_file end
			local node = {x=pos.x + (entry.x or 0), y=pos.y + (entry.y or 0), z=pos.z + (entry.z or 0), name=entry.name}
			table.insert(place_nodes, node)
			add_preview_if_needed(node, node.name)
			::skip_file::
		end
		ws.notify("Loaded " .. #place_nodes .. " nodes from " .. filepath, ws.NOTIFY_INFO)
		core.after(0.1, update_hud)
		return true, nil, param
	end

	if param == "$" then
		value = core.settings:get("schembuilder_output") or "{}"
	else
		value = param
	end
	local count = load_schematic_nodes(value, pos)
	if not count then
		return false, "Failed to load schematic"
	end
	return true, nil, param
end

core.register_chatcommand("schembuild", {
	description = "Load schematic. $ for schembuilder_output setting, file:<path> for MTS file from disk.",
	func = function(param)
		local ok, err, save_param = do_schembuild(param)
		if ok then
			core.settings:set("schembuilder_resume_pos",
				vector.round(core.localplayer:get_pos()).x .. "," ..
				vector.round(core.localplayer:get_pos()).y .. "," ..
				vector.round(core.localplayer:get_pos()).z)
			core.settings:set("schembuilder_resume_param", save_param or param)
			if core.global_exists("poi") then
				local name
				if param:match("^file:") then
					name = param:gsub("^file:", ""):match("([^/\\]+)$")
				else
					name = "Schematic"
				end
				local pos = vector.round(core.localplayer:get_pos())
				poi.set_waypoint(pos, name)
				poi.set_group(name, "schembuilder")
			end
		end
		return ok, err
	end,
})

core.register_chatcommand("schemresume", {
	description = "Resume the last schematic build at the saved position without teleporting",
	func = function(param)
		local saved_pos = core.settings:get("schembuilder_resume_pos")
		local saved_param = core.settings:get("schembuilder_resume_param")
		if not saved_pos or not saved_param then
			return false, "No saved schematic to resume"
		end
		local px, py, pz = saved_pos:match("([^,]+),([^,]+),([^,]+)")
		if not px then
			return false, "Invalid saved position: " .. saved_pos
		end
		local pos = {x = tonumber(px), y = tonumber(py), z = tonumber(pz)}
		local ok, err = do_schembuild(saved_param, pos)
		if ok then
			return true, "Resumed schematic build at saved position"
		end
		return false, err or "Failed to resume schematic"
	end,
})

local function pos_marker(pos, texture)
	core.add_particle({
		pos = vector.new(math.floor(pos.x), math.floor(pos.y), math.floor(pos.z)),
		velocity = {x=0, y=0, z=0},
		acceleration = {x=0, y=0, z=0},
		expirationtime = PARTICLE_TTL,
		size = 0.5,
		collisiondetection = false,
		collision_removal = false,
		vertical = false,
		texture = texture,
		glow = 14,
	})
end

core.register_chatcommand("spos1", {
	description = "Set pos1",
	func = function(param)
		schembuilder.pos1 = vector.round(core.localplayer:get_pos())
		ws.notify("pos1 set", ws.NOTIFY_INFO)
		pos_marker(schembuilder.pos1, "worldedit_pos1.png")
	end,
})

core.register_chatcommand("spos2", {
	description = "Set pos2",
	func = function(param)
		schembuilder.pos2 = vector.round(core.localplayer:get_pos())
		ws.notify("pos2 set", ws.NOTIFY_INFO)
		pos_marker(schembuilder.pos2, "worldedit_pos2.png")
	end,
})

local function sort_pos(pos1, pos2)
	pos1 = vector.copy(pos1)
	pos2 = vector.copy(pos2)
	if pos1.x > pos2.x then pos2.x, pos1.x = pos1.x, pos2.x end
	if pos1.y > pos2.y then pos2.y, pos1.y = pos1.y, pos2.y end
	if pos1.z > pos2.z then pos2.z, pos1.z = pos1.z, pos2.z end
	return pos1, pos2
end

local function schembuilder_serialize(pos1, pos2)
	pos1, pos2 = sort_pos(pos1, pos2)
	local get_node = core.get_node_or_nil
	local pos = vector.new(pos1.x, 0, 0)
	local count = 0
	local result = {}
	while pos.x <= pos2.x do
		pos.y = pos1.y
		while pos.y <= pos2.y do
			pos.z = pos1.z
			while pos.z <= pos2.z do
				local node = get_node(pos)
				if node.name ~= "air" and node.name ~= "ignore" then
					count = count + 1
					result[count] = {
						x = pos.x - pos1.x,
						y = pos.y - pos1.y,
						z = pos.z - pos1.z,
						name = node.name,
						param1 = node.param1 ~= 0 and node.param1 or nil,
						param2 = node.param2 ~= 0 and node.param2 or nil,
					}
				end
				pos.z = pos.z + 1
			end
			pos.y = pos.y + 1
		end
		pos.x = pos.x + 1
	end

	-- Build a schematic table for core.serialize_schematic
	local schem = {
		size = {x = pos2.x - pos1.x + 1, y = pos2.y - pos1.y + 1, z = pos2.z - pos1.z + 1},
		data = {},
	}
	-- Fill all positions (air if no node was captured)
	local idx = 1
	local pos_iter = vector.new(pos1.x, 0, 0)
	while pos_iter.x <= pos2.x do
		pos_iter.y = pos1.y
		while pos_iter.y <= pos2.y do
			pos_iter.z = pos1.z
			while pos_iter.z <= pos2.z do
				local node = get_node(pos_iter)
				if node.name ~= "air" and node.name ~= "ignore" then
					schem.data[idx] = {
						name = node.name,
						prob = node.param1 ~= 0 and node.param1 * 2 or 254,
						param2 = node.param2 or 0,
					}
				else
					schem.data[idx] = {name = "air", prob = 0, param2 = 0}
				end
				idx = idx + 1
				pos_iter.z = pos_iter.z + 1
			end
			pos_iter.y = pos_iter.y + 1
		end
		pos_iter.x = pos_iter.x + 1
	end

	return schem, count
end

core.register_chatcommand("ssave", {
	description = "Save the current region to schembuilder_output setting",
	func = function(param)
		if schembuilder.pos1 ~= nil and schembuilder.pos2 ~= nil then
			local schem, count = schembuilder_serialize(schembuilder.pos1, schembuilder.pos2)
			local mts_data = core.serialize_schematic(schem, "mts")
			local b64 = core.encode_base64(mts_data)
			core.settings:set("schembuilder_output", b64)
			ws.notify("Saved " .. count .. " nodes to schembuilder_output", ws.NOTIFY_INFO)
		end
	end,
})

-- SchemBuilder bot: walks to the nearest unplaced node and places it
if sbots and sbots.register_bot then
	local _item_cache = {}
	local _item_cache_time = 0
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

	sbots.register_bot("SchemBuilderBot", {
		moving_target = true,
		stand_waiting = true,
		landing_distance = 3,
		cheat_settings = {
			place_cooldown = { type = "number", default = 0.1, min = 0, max = 5 },
			batch_size = { type = "number", default = 8, min = 1, max = 64 },
			strategy = { type = "string", default = "closest" },
			filter_mode = { type = "string", default = "all" },
			filter_list = { type = "string", default = "schembuilder" },
		},
		find_pos = function(self, pos)
			if #place_nodes == 0 then return end
			local px, py, pz = pos.x, pos.y, pos.z
			self._current_entry = nil

			local strategy = core.settings:get("schembuilderbot.strategy") or "closest"

			if strategy == "layer" then
				-- Group placeable nodes by Y level, pick lowest layer first
				local by_y = {}
				for i, entry in ipairs(place_nodes) do
					if entry.name ~= "air" and has_item(entry.name) and is_node_allowed(entry.name) then
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
				if #ys > 0 then
					local target_y = ys[1]
					local best_dist_sq
					for _, item in ipairs(by_y[target_y]) do
						local dx = item.entry.x - px
						local dy = item.entry.y - py
						local dz = item.entry.z - pz
						local dist_sq = dx*dx + dy*dy + dz*dz
						if not best_dist_sq or dist_sq < best_dist_sq then
							best_dist_sq = dist_sq
							self._current_entry = item.entry
						end
					end
				end
			else
				local closest_dist_sq

				for _, entry in ipairs(place_nodes) do
					if entry.name == "air" then goto skip_find end
					if not has_item(entry.name) then goto skip_find end
					if not is_node_allowed(entry.name) then goto skip_find end
					local dx = entry.x - px
					local dy = entry.y - py
					local dz = entry.z - pz
					local dist_sq = dx*dx + dy*dy + dz*dz
					if not closest_dist_sq or dist_sq < closest_dist_sq then
						closest_dist_sq = dist_sq
						self._current_entry = entry
					end
					::skip_find::
				end
			end

			if self._current_entry then
				self._is_supply_target = nil
				return vector.new(
					self._current_entry.x,
					self._current_entry.y,
					self._current_entry.z
				)
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
				local items = {}
				local seen = {}
				for _, entry in ipairs(place_nodes) do
					if entry.name ~= "air" and entry.name ~= "ignore" and not seen[entry.name] then
						seen[entry.name] = true
						table.insert(items, entry.name)
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
			local strategy = core.settings:get("schembuilderbot.strategy") or "closest"
			local px, py, pz = pos.x, pos.y, pos.z
			local placed = 0

			-- Place the primary target first
			if ws.place(self._current_entry, self._current_entry.name) then
				self._last_place_time = os.clock()
				for i = #place_nodes, 1, -1 do
					if place_nodes[i] == self._current_entry then
						table.remove(place_nodes, i)
						break
					end
				end
				placed = 1
			end
			self._current_entry = nil

			-- Also place nearby nodes in the same tick
			if placed > 0 and #place_nodes > 0 then
				for i = #place_nodes, 1, -1 do
					if placed >= batch then break end
					local entry = place_nodes[i]
					if entry.name ~= "air" and is_node_allowed(entry.name) and (strategy ~= "layer" or entry.y <= py) then
						local dx = entry.x - px
						local dy = entry.y - py
						local dz = entry.z - pz
						if dx*dx + dy*dy + dz*dz <= range*range then
							if ws.place(entry, entry.name) then
								table.remove(place_nodes, i)
								placed = placed + 1
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

-- SchematicLooter: scan nearby containers for items needed by the current schematic
ws.rg("SchematicLooter", {
	category = "Inventory",
	setting = "schematic_looter",
	delay = 1,
	on_step = function(self, dtime)
		if #place_nodes == 0 then return end
		local items = {}
		local seen = {}
		for _, entry in ipairs(place_nodes) do
			if entry.name ~= "air" and entry.name ~= "ignore" and not seen[entry.name] then
				seen[entry.name] = true
				table.insert(items, entry.name)
			end
		end
		if #items == 0 then return end
		local range = tonumber(core.settings:get("schematic_looter.range")) or 5
		local max_per = tonumber(core.settings:get("schematic_looter.max_per_scan")) or 16

		if core.localplayer then
			local pos = core.localplayer:get_pos()
			local minp = vector.offset(pos, -range, -range, -range)
			local maxp = vector.offset(pos, range, range, range)
			for _, cpos in ipairs(core.find_nodes_with_meta(minp, maxp)) do
				add_supply_chest(cpos)
			end
		end

		ws.loot_list(items, range, max_per)
	end,
	cheat_settings = {
		range = { type = "number", default = 5, min = 1, max = 20 },
		max_per_scan = { type = "number", default = 16, min = 1, max = 64 },
	},
})

core.register_chatcommand("schemclear", {
	description = "Clear the current schematic build and saved job data",
	func = function(param)
		place_nodes = {}
		clear_supply_chests()
		clear_job()
		if hud_id then
			core.localplayer:hud_remove(hud_id)
			hud_id = nil
		end
		ws.notify("Schematic build cleared", ws.NOTIFY_INFO)
		return true
	end,
})

-- Restore saved job on init and reconnect
local function restore_job()
	if load_job() and #place_nodes > 0 then
		for _, n in ipairs(place_nodes) do
			add_preview_if_needed(n, n.name)
		end
		core.after(0.1, update_hud)
	end
end

restore_job()

core.register_on_connect(function()
	restore_job()
end)
