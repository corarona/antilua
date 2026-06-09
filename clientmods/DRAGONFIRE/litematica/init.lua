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
	local tt = def.tiles or def.overlay_tiles or def.special_tiles

	if tt[1] and tt[1].name then
		return tt[1].name
	else
		return tt[1]
	end
end

local function litematica_particle(pos, texture, size, collision)
	core.add_particle({
		pos = vector.new(math.modf(pos.x), math.modf(pos.y), math.modf(pos.z)),
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

local function litematica_allocate_with_nodes(origin_pos, nodes)
	local huge = math.huge
	local pos1x, pos1y, pos1z = huge, huge, huge
	local pos2x, pos2y, pos2z = -huge, -huge, -huge
	local origin_x, origin_y, origin_z = origin_pos.x, origin_pos.y, origin_pos.z
	for i, entry in ipairs(nodes) do
		local x, y, z = origin_x + entry.x, origin_y + entry.y, origin_z + entry.z
		if x < pos1x then pos1x = x end
		if y < pos1y then pos1y = y end
		if z < pos1z then pos1z = z end
		if x > pos2x then pos2x = x end
		if y > pos2y then pos2y = y end
		if z > pos2z then pos2z = z end
	end
	return vector.new(pos1x, pos1y, pos1z), vector.new(pos2x, pos2y, pos2z)
end

local place_nodes = {}
local function litematica_deserialize(origin_pos, value)
	local nodes = load_schematic(value)
	if not nodes then return nil end
	if #nodes == 0 then return #nodes end
	place_nodes = nodes

	local pos1, pos2 = litematica_allocate_with_nodes(origin_pos, nodes)

	local origin_x, origin_y, origin_z = origin_pos.x, origin_pos.y, origin_pos.z
	for i, entry in ipairs(nodes) do
		entry.x, entry.y, entry.z = origin_x + entry.x, origin_y + entry.y, origin_z + entry.z
		add_node(entry, entry)
	end
	return #nodes
end

ws.rg("PlaceLiteM", {
	category = "Place",
	setting = "placelitem",
	on_step = function(self, dtime)
		if #place_nodes == 0 then return end
		local pp = vector.round(core.localplayer:get_pos())
		for i = #place_nodes, 1, -1 do
			local entry = place_nodes[i]
			if math.abs(entry.x - pp.x) <= 4
			and math.abs(entry.y - pp.y) <= 4
			and math.abs(entry.z - pp.z) <= 4 then
				local pos = vector.new(entry.x, entry.y, entry.z)
				if ws.can_place_at(pos) then
					ws.place(pos, entry.name)
					table.remove(place_nodes, i)
				end
			end
		end
	end,
})

core.register_chatcommand("liteload", {
	description = "Load nodes as particles from WorldEdit schematic arguments in position of the player as the origin\nDoes not support loading external files\nUse $ as the parameter to load from the litematica_output setting.",
	func = function(param)
		local value
		if param ~= "" then
			value = param
			if param == "$" then
				value = core.settings:get("litematica_output") or "{}"
			end
			local pos = {x=math.floor(core.localplayer:get_pos().x+0.5),
			y=math.floor(core.localplayer:get_pos().y+0.5),
			z=math.floor(core.localplayer:get_pos().z+0.5)}

			local count = litematica_deserialize(pos, value)
			print(count)
			return true
		else
			return false, "Need an argument to load"
		end
	end,
})

core.register_chatcommand("litepos1", {
	description = "Set pos1",
	func = function(param)
		litematica.pos1 = {x=math.floor(core.localplayer:get_pos().x+0.5),y=math.floor(core.localplayer:get_pos().y+0.5),z=math.floor(core.localplayer:get_pos().z+0.5)}
		print("pos1 set")
		litematica_particle(litematica.pos1, "worldedit_pos1.png", 3, false)
	end,
})

core.register_chatcommand("litepos2", {
	description = "Set pos2",
	func = function(param)
		litematica.pos2 = {x=math.floor(core.localplayer:get_pos().x+0.5),y=math.floor(core.localplayer:get_pos().y+0.5),z=math.floor(core.localplayer:get_pos().z+0.5)}
		print("pos2 set")
		litematica_particle(litematica.pos2, "worldedit_pos2.png", 5, false)
	end,
})

local function sort_pos(pos1, pos2)
	pos1 = vector.copy(pos1)
	pos2 = vector.copy(pos2)
	if pos1.x > pos2.x then
		pos2.x, pos1.x = pos1.x, pos2.x
	end
	if pos1.y > pos2.y then
		pos2.y, pos1.y = pos1.y, pos2.y
	end
	if pos1.z > pos2.z then
		pos2.z, pos1.z = pos1.z, pos2.z
	end
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
	result = core.serialize(result)
	return "5:" .. result, count
end

core.register_chatcommand("litesave", {
	description = "Save the current Litematica region to \"litematica_output\" setting",
	parse = function(param)
		if param == "" then
			return false
		end
		if not check_filename(param) then
			return false, S("Disallowed file name: @1", param)
		end
		return true, param
	end,
	func = function(param)
		if litematica.pos1 ~= nil and litematica.pos2 ~= nil then
			local result, count = litematica_serialize(litematica.pos1,
					litematica.pos2)
			core.settings:set("litematica_output", result)
			core.display_chat_message("Saved to \"litematica_output\" setting")
		end
	end,
})
