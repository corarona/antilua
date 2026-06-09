local modpath = core.get_modpath(core.get_current_modname())

local litematica = {pos1={x=nil,y=nil,z=nil}, pos2={x=nil,y=nil,z=nil}}
local place_nodes = {}

local function deserialize_workaround(content)
	local nodes, err = core.deserialize(content, true)
	if err then
		core.log("warning", "litematica: deserialize: " .. err)
	end
	return nodes or {}
end

local function get_texture_by_name(name)
	local def = core.get_node_def(name)
	if def and def.tiles and def.tiles[1] and def.tiles[1] ~= "" then
		return def.tiles[1]
	end
	return "unknown_node.png"
end

local function add_preview_particle(pos, node_name)
	local tex = get_texture_by_name(node_name)
	if tex == "unknown_node.png" then return end
	core.add_particle({
		pos = vector.new(math.floor(pos.x), math.floor(pos.y), math.floor(pos.z)),
		velocity = {x=0, y=0, z=0},
		acceleration = {x=0, y=0, z=0},
		expirationtime = 9999,
		size = 1,
		collisiondetection = false,
		collision_removal = false,
		vertical = false,
		texture = tex,
		glow = 14,
	})
end

-- Only add a particle if the target isn't already in place
local function add_preview_if_needed(pos, node_name)
	local current = core.get_node_or_nil(pos)
	if current and current.name == node_name then
		return  -- already correct, no particle
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

local hud_id = nil

local function update_hud()
	if not core.localplayer then return end
	if #place_nodes == 0 then
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
	-- Truncate to top 15
	local lines = {"Missing:"}
	local total = 0
	for i = 1, math.min(#sorted, 15) do
		local s = sorted[i]
		local short = s.name:match("[^:]+$") or s.name
		table.insert(lines, short .. ": " .. s.count)
		total = total + s.count
	end
	if #sorted > 15 then
		table.insert(lines, "... +" .. (#sorted - 15) .. " more")
	end
	table.insert(lines, "Total: " .. total)

	local text = table.concat(lines, "\n")

	if hud_id then
		core.localplayer:hud_change(hud_id, "text", text)
	else
		hud_id = core.localplayer:hud_add({
			hud_elem_type = "text",
			position = {x = 1, y = 0.5},
			offset = {x = -10, y = -200},
			alignment = {x = 1, y = 0},
			scale = {x = 100, y = 100},
			number = 0xFFFFFF,
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



core.register_chatcommand("liteload", {
	description = "Load schematic. $ for litematica_output setting, file:<path> for MTS file from disk.",
	func = function(param)
		if param == "" then
			return false, "Need an argument to load"
		end
		local pos = vector.round(core.localplayer:get_pos())
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
			return true
		end

		if param == "$" then
			value = core.settings:get("litematica_output") or "{}"
		else
			value = param
		end
		local count = load_schematic_nodes(value, pos)
		if not count then
			return false, "Failed to load schematic"
		end
		return true
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

core.register_chatcommand("litepos1", {
	description = "Set pos1",
	func = function(param)
		litematica.pos1 = vector.round(core.localplayer:get_pos())
		ws.notify("pos1 set", ws.NOTIFY_INFO)
		pos_marker(litematica.pos1, "worldedit_pos1.png")
	end,
})

core.register_chatcommand("litepos2", {
	description = "Set pos2",
	func = function(param)
		litematica.pos2 = vector.round(core.localplayer:get_pos())
		ws.notify("pos2 set", ws.NOTIFY_INFO)
		pos_marker(litematica.pos2, "worldedit_pos2.png")
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

local function litematica_serialize(pos1, pos2)
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

core.register_chatcommand("litesave", {
	description = "Save the current Litematica region to litematica_output setting",
	func = function(param)
		if litematica.pos1 ~= nil and litematica.pos2 ~= nil then
			local schem, count = litematica_serialize(litematica.pos1, litematica.pos2)
			local mts_data = core.serialize_schematic(schem, "mts")
			local b64 = core.encode_base64(mts_data)
			core.settings:set("litematica_output", b64)
			ws.notify("Saved " .. count .. " nodes to litematica_output", ws.NOTIFY_INFO)
		end
	end,
})

-- Auto miner bot: walks to the nearest unplaced node and places it
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

	sbots.register_bot("LitematicaBot", {
		moving_target = true,
		stand_waiting = true,
		landing_distance = 3,
		cheat_settings = {
			place_cooldown = { type = "number", default = 0.1, min = 0, max = 5 },
		},
		find_pos = function(self, pos)
			if #place_nodes == 0 then return end
			local closest_dist_sq
			local px, py, pz = pos.x, pos.y, pos.z
			self._current_entry = nil
			for _, entry in ipairs(place_nodes) do
				if entry.name == "air" then goto skip_find end
				if not has_item(entry.name) then goto skip_find end
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
			if self._current_entry then
				return vector.new(
					self._current_entry.x,
					self._current_entry.y,
					self._current_entry.z
				)
			end
		end,
		update_pos = function(self, pos)
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
			self._current_entry = nil
			return self:find_pos(pos)
		end,
		do_pos = function(self, pos)
			if not self._current_entry then return true end
			local cooldown = tonumber(core.settings:get("litematicabot.place_cooldown")) or 0.5
			if self._last_place_time and os.clock() - self._last_place_time < cooldown then
				return false
			end
			if ws.place(self._current_entry, self._current_entry.name) then
				self._last_place_time = os.clock()
				for i = #place_nodes, 1, -1 do
					if place_nodes[i] == self._current_entry then
						table.remove(place_nodes, i)
						break
					end
				end
			end
			self._current_entry = nil
			self.target_pos = nil
			update_hud()
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
