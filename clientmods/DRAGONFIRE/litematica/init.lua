local modpath = core.get_modpath(core.get_current_modname())

local litematica = {pos1={x=nil,y=nil,z=nil}, pos2={x=nil,y=nil,z=nil}}

local function deserialize_workaround(content)
	local nodes, err = core.deserialize(content, true)
	if err then
		core.log("warning", "litematica: deserialize: " .. err)
	end
	return nodes or {}
end

local function get_texture_by_name(name)
	local def = core.get_node_def(name)
	if not def then return "unknown_node.png" end
	local tt = def.tiles or def.overlay_tiles or def.special_tiles
	if not tt or #tt == 0 then return "unknown_node.png" end
	local tex = tt[1]
	if type(tex) == "table" and tex.name then
		return tex.name
	end
	return tex or "unknown_node.png"
end

local function litematica_particle(pos, texture, size, collision)
	core.add_particle({
		pos = vector.new(math.floor(pos.x), math.floor(pos.y), math.floor(pos.z)),
		velocity = {x=0, y=0, z=0},
		acceleration = {x=0, y=0, z=0},
		expirationtime = 9999,
		size = size,
		collisiondetection = collision,
		collision_removal = collision,
		vertical = false,
		texture = texture,
		glow = 14,
	})
end

local function add_node(pos, node)
	litematica_particle(pos, get_texture_by_name(node.name), 9, true)
end

local function load_schematic(value)
	local content = value:match("^5:(.*)$")
	if not content then
		return nil
	end
	return deserialize_workaround(content)
end

local function load_mts_data(mts_data)
	local ok, schem = pcall(core.read_schematic, mts_data, {})
	if not ok or not schem or not schem.data then
		return nil
	end
	local nodes = {}
	for _, entry in ipairs(schem.data) do
		table.insert(nodes, {x=0, y=0, z=0, name=entry.name, param1=entry.param1, param2=entry.param2})
	end
	return nodes
end

local function litematica_deserialize(origin_pos, value)
	local count = load_schematic_data(value, origin_pos)
	if count then
		return count
	end
	-- Fall back to WorldEdit string format directly (not detected as MTS)
	local nodes = load_schematic(value)
	if not nodes then return nil end
	if #nodes == 0 then return #nodes end
	place_nodes = nodes

	local origin_x, origin_y, origin_z = origin_pos.x, origin_pos.y, origin_pos.z
	for i, entry in ipairs(nodes) do
		entry.x, entry.y, entry.z = origin_x + entry.x, origin_y + entry.y, origin_z + entry.z
		add_node(entry, entry)
	end
	ws.notify("Loaded " .. #nodes .. " nodes", ws.NOTIFY_INFO)
	return #nodes
end

ws.rg("PlaceLiteM", {
	category = "Place",
	setting = "placelitem",
	on_step = function(self, dtime)
		if #place_nodes == 0 then return end
		local pp = vector.round(core.localplayer:get_pos())
		local range = tonumber(core.settings:get("placelitem.range")) or 4
		local check_inv = core.settings:get_bool("placelitem.require_item", false)
		for i = #place_nodes, 1, -1 do
			local entry = place_nodes[i]
			if math.abs(entry.x - pp.x) <= range
			and math.abs(entry.y - pp.y) <= range
			and math.abs(entry.z - pp.z) <= range then
				local pos = vector.new(entry.x, entry.y, entry.z)
				if ws.can_place_at(pos) then
					if check_inv then
						local had_item = false
						if ws.switch_to_item then
							had_item = ws.switch_to_item(entry.name)
						end
						if not had_item then
							goto continue
						end
					end
					ws.place(pos, entry.name)
					table.remove(place_nodes, i)
				end
			end
			::continue::
		end
	end,
	cheat_settings = {
		range = { type = "number", default = 4, min = 1, max = 20 },
		require_item = { type = "bool", default = false },
	},
})

local function load_schematic_data(value, pos)
	if not value or value == "" then
		return nil, "No data"
	end
	-- Try MTS format (base64)
	local raw = core.decode_base64(value)
	if raw then
		local ok, schem = pcall(core.read_schematic, raw, {})
		if ok and schem and schem.data then
			place_nodes = {}
			for _, entry in ipairs(schem.data) do
				local node = {x=pos.x + (entry.x or 0), y=pos.y + (entry.y or 0), z=pos.z + (entry.z or 0), name=entry.name, param1=entry.param1, param2=entry.param2}
				table.insert(place_nodes, node)
				add_node(node, node)
			end
			ws.notify("Loaded " .. #place_nodes .. " nodes from MTS", ws.NOTIFY_INFO)
			return #place_nodes
		end
	end
	-- Fall back to WorldEdit string format
	local count = litematica_deserialize(pos, value)
	if count then
		return count
	end
	return nil, "Failed to load schematic"
end

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
				local node = {x=pos.x + (entry.x or 0), y=pos.y + (entry.y or 0), z=pos.z + (entry.z or 0), name=entry.name, param1=entry.param1, param2=entry.param2}
				table.insert(place_nodes, node)
				add_node(node, node)
			end
			ws.notify("Loaded " .. #place_nodes .. " nodes from " .. filepath, ws.NOTIFY_INFO)
			return true
		end

		if param == "$" then
			value = core.settings:get("litematica_output") or "{}"
		else
			value = param
		end
		local count, err = load_schematic_data(value, pos)
		if not count then
			return false, err or "Failed to load schematic"
		end
		return true
	end,
})

core.register_chatcommand("litepos1", {
	description = "Set pos1",
	func = function(param)
		litematica.pos1 = vector.round(core.localplayer:get_pos())
		ws.notify("pos1 set", ws.NOTIFY_INFO)
		litematica_particle(litematica.pos1, "worldedit_pos1.png", 3, false)
	end,
})

core.register_chatcommand("litepos2", {
	description = "Set pos2",
	func = function(param)
		litematica.pos2 = vector.round(core.localplayer:get_pos())
		ws.notify("pos2 set", ws.NOTIFY_INFO)
		litematica_particle(litematica.pos2, "worldedit_pos2.png", 5, false)
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
