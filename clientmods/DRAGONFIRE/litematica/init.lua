--[[local function get_setting_bool(name, default) -- Copied from Climate API
	local value = minetest.settings:get_bool(name)
	if type(value) == "nil" then value = default end
	return minetest.is_yes(value)
end]]
--LOTS OF CODE IS COPIED FROM WORLDEDIT MOD

local modpath = minetest.get_modpath(minetest.get_current_modname())


local litematica = {pos1={x=nil,y=nil,z=nil}, pos2={x=nil,y=nil,z=nil}}
local node_names = minetest.parse_json(minetest.settings:get("litematica_node_names") or "[]")
if next(node_names) == nil then
	node_names = {"mcl_amethyst:calcite","mcl_amethyst:amethyst_block","mcl_amethyst:large_amethyst_bud","mcl_amethyst:medium_amethyst_bud","mcl_amethyst:small_amethyst_bud"}
end
--minetest.log(string.format("[litematica] %d nodes", #node_names))
--minetest.log(string.format("[litematica] %s", dump(node_names)))

local texture_names = minetest.parse_json(minetest.settings:get("litematica_texture_names") or "[]")
if next(texture_names) == nil then
	texture_names = {"mcl_amethyst_calcite_block.png","mcl_amethyst_amethyst_block.png","mcl_amethyst_amethyst_bud_large.png","mcl_amethyst_amethyst_bud_medium.png","mcl_amethyst_amethyst_bud_small.png"}
end
--minetest.log(string.format("[litematica] %d textures", #texture_names))
--minetest.log(string.format("[litematica] %s", dump(texture_names)))

local litefile = minetest.settings:get("litematica_file")
local modstorage = minetest.get_mod_storage("litematica")

local function deserialize_workaround(content)
	local nodes, err
	if not minetest.global_exists("jit") then
		nodes, err = minetest.deserialize(content, true)
	elseif not content:match("^%s*return%s*{") then
		-- The data doesn't look like we expect it to so we can't apply the workaround.
		-- hope for the best
		minetest.log("warning", "WorldEdit: deserializing data but can't apply LuaJIT workaround")
		nodes, err = minetest.deserialize(content, true)
	else
		-- XXX: This is a filthy hack that works surprisingly well
		-- in LuaJIT, `minetest.deserialize` will fail due to the register limit
		nodes = {}
		content = content:gsub("^%s*return%s*{", "", 1):gsub("}%s*$", "", 1) -- remove the starting and ending values to leave only the node data
		-- remove string contents strings while preserving their length
		local escaped = content:gsub("\\\\", "@@"):gsub("\\\"", "@@"):gsub("(\"[^\"]*\")", function(s) return string.rep("@", #s) end)
		local startpos, startpos1 = 1, 1
		local endpos
		local entry
		while true do -- go through each individual node entry (except the last)
			startpos, endpos = escaped:find("}%s*,%s*{", startpos)
			if not startpos then
				break
			end
			local current = content:sub(startpos1, startpos)
			entry, err = minetest.deserialize("return " .. current, true)
			if not entry then
				break
			end
			table.insert(nodes, entry)
			startpos, startpos1 = endpos, endpos
		end
		if not err then
			entry = minetest.deserialize("return " .. content:sub(startpos1), true) -- process the last entry
			table.insert(nodes, entry)
		end
	end
	if err then
		minetest.log("warning", "WorldEdit: deserialize: " .. err)
	end
	return nodes
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
	return vector.new(pos1x, pos1y, pos1z), vector.new(pos2x, pos2y, pos2z), #nodes
end

local function get_texture_by_name(name)
	local def = minetest.get_node_def(name)
	local tt = def.tiles or def.overlay_tiles or def.special_tiles

	if tt[1] and tt[1].name then
		return tt[1].name
	else
		return tt[1]
	end
end

local function litematica_read_header(value)
	if value:find("^[0-9]+[,:]") then
		local header_end = value:find(":", 1, true)
		local header = value:sub(1, header_end - 1):split(",")
		local version = tonumber(header[1])
		table.remove(header, 1)
		local content = value:sub(header_end + 1)
		return version, header, content
	end
	-- Old versions that didn't include a header with a version number
	if value:find("([+-]?%d+)%s+([+-]?%d+)%s+([+-]?%d+)") and not value:find("%{") then -- List format
		return 3, nil, value
	elseif value:find("^[^\"']+%{%d+%}") then
		if value:find("%[\"meta\"%]") then -- Meta flat table format
			return 2, nil, value
		end
		return 1, nil, value -- Flat table format
	elseif value:find("%{") then -- Raw nested table format
		return 4, nil, value
	end
	return nil
end

local function add_node(pos, node)
  minetest.add_particle({
	pos = vector.new(math.modf(pos.x), math.modf(pos.y), math.modf(pos.z)),
	velocity = {x=0, y=0, z=0},
	acceleration = {x=0, y=0, z=0},
	--  ^ Spawn particle at pos with velocity and acceleration
	expirationtime = 9999,
	--  ^ Disappears after expirationtime seconds
	size = 9,
	collisiondetection = true,
	--  ^ collisiondetection: if true collides with physical objects
	collision_removal = true,
	--  ^ collision_removal: if true then particle is removed when it collides,
	--  ^ requires collisiondetection = true to have any effect
	vertical = false,
	--  ^ vertical: if true faces player using y axis only
	texture = get_texture_by_name(node.name),
	--  ^ Uses texture (string)
	glow = 14
	--  ^ optional, specify particle self-luminescence in darkness
  })
end

local function load_schematic(value)
  local version, _, content = litematica_read_header(value)
	local nodes = {}
	if version == 1 or version == 2 then -- Original flat table format
		local tables = minetest.deserialize(content, true)
		if not tables then return nil end

		-- Transform the node table into an array of nodes
		for i = 1, #tables do
			for j, v in pairs(tables[i]) do
				if type(v) == "table" then
					tables[i][j] = tables[v[1]]
				end
			end
		end
		nodes = tables[1]

		if version == 1 then --original flat table format
			for i, entry in ipairs(nodes) do
				local pos = entry[1]
				entry.x, entry.y, entry.z = pos.x, pos.y, pos.z
				entry[1] = nil
				local node = entry[2]
				entry.name, entry.param1, entry.param2 = node.name, node.param1, node.param2
				entry[2] = nil
			end
		end
	elseif version == 3 then -- List format
		for x, y, z, name, param1, param2 in content:gmatch(
				"([+-]?%d+)%s+([+-]?%d+)%s+([+-]?%d+)%s+" ..
				"([^%s]+)%s+(%d+)%s+(%d+)[^\r\n]*[\r\n]*") do
			param1, param2 = tonumber(param1), tonumber(param2)
			table.insert(nodes, {
				x = tonumber(x),
				y = tonumber(y),
				z = tonumber(z),
				name = name,
				param1 = param1 ~= 0 and param1 or nil,
				param2 = param2 ~= 0 and param2 or nil,
			})
		end
	elseif version == 4 or version == 5 then -- Nested table format
		nodes = deserialize_workaround(content)
	else
		return nil
	end
	nodes = deserialize_workaround(content)
	return nodes
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
		-- Entry acts as both position and node
		add_node(entry, entry)
	end
	return #nodes
end

ws.rg("PlaceLiteM", "Place", "placelitem", function()
	if #place_nodes == 0 then return end
	local pp = minetest.localplayer:get_pos()
	for x = -4, 4 do for y = -4, 4 do for z = -4, 4 do
		local p = vector.add(pp, vector.new(x, y, z))
		for i, entry in pairs(place_nodes) do
			if vector.equals(p, vector.new(entry.x, entry.y, entry.z)) then
				ws.place(p, entry.node)
			end
		end
	end	end end
end)

minetest.register_chatcommand("liteload", {
	description = "Load nodes as particles from WorldEdit schematic arguments in position of the player as the origin\nDoes not support loading external files\nUse $ as the parameter to load from the litematica_output setting.",
	func = function(param)
		local value
		if param ~= "" then
			local value = param
			if param == "$" then
				value = minetest.settings:get("litematica_output") or "{}"
			end
			local pos = {x=math.floor(minetest.localplayer:get_pos().x+0.5),
			y=math.floor(minetest.localplayer:get_pos().y+0.5),
			z=math.floor(minetest.localplayer:get_pos().z+0.5)}

			local count = litematica_deserialize(pos, value)
			print(count)
			return true
		else
			return false, "Need an argument to load"
		end
	end,
})

minetest.register_chatcommand("litepos1", {
	description = "Set pos1",
	func = function(param)
		  litematica.pos1 = {x=math.floor(minetest.localplayer:get_pos().x+0.5),y=math.floor(minetest.localplayer:get_pos().y+0.5),z=math.floor(minetest.localplayer:get_pos().z+0.5)}
		  print("pos1 set")
	  minetest.add_particle({
		pos = vector.new(math.modf(litematica.pos1.x), math.modf(litematica.pos1.y), math.modf(litematica.pos1.z)),
		velocity = {x=0, y=0, z=0},
		acceleration = {x=0, y=0, z=0},
		--  ^ Spawn particle at pos with velocity and acceleration
		expirationtime = 9999,
		--  ^ Disappears after expirationtime seconds
		size = 3,
		collisiondetection = false,
		--  ^ collisiondetection: if true collides with physical objects
		collision_removal = false,
		--  ^ collision_removal: if true then particle is removed when it collides,
		--  ^ requires collisiondetection = true to have any effect
		vertical = false,
		--  ^ vertical: if true faces player using y axis only
		texture = "worldedit_pos1.png",
		--  ^ Uses texture (string)
		glow = 14
		--  ^ optional, specify particle self-luminescence in darkness
	  })
	end,
})

minetest.register_chatcommand("litepos2", {
	description = "Set pos2",
	func = function(param)
		  litematica.pos2 = {x=math.floor(minetest.localplayer:get_pos().x+0.5),y=math.floor(minetest.localplayer:get_pos().y+0.5),z=math.floor(minetest.localplayer:get_pos().z+0.5)}
		  print("pos2 set")
	  minetest.add_particle({
		pos = vector.new(math.modf(litematica.pos2.x), math.modf(litematica.pos2.y), math.modf(litematica.pos2.z)),
		velocity = {x=0, y=0, z=0},
		acceleration = {x=0, y=0, z=0},
		--  ^ Spawn particle at pos with velocity and acceleration
		expirationtime = 9999,
		--  ^ Disappears after expirationtime seconds
		size = 5,
		collisiondetection = false,
		--  ^ collisiondetection: if true collides with physical objects
		collision_removal = false,
		--  ^ collision_removal: if true then particle is removed when it collides,
		--  ^ requires collisiondetection = true to have any effect
		vertical = false,
		--  ^ vertical: if true faces player using y axis only
		texture = "worldedit_pos2.png",
		--  ^ Uses texture (string)
		glow = 14
		--  ^ optional, specify particle self-luminescence in darkness
	  })
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

	--worldedit.keep_loaded(pos1, pos2)

	local get_node, get_meta, hash_node_position =
		minetest.get_node_or_nil, minetest.get_meta, minetest.hash_node_position

	-- Find the positions which have metadata
	local has_meta = {}
	local meta_positions = minetest.find_nodes_with_meta(pos1, pos2)
	for i = 1, #meta_positions do
		has_meta[hash_node_position(meta_positions[i])] = true
	end

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

					local meta
					--[[if has_meta[hash_node_position(pos)] then
						meta = get_meta(pos):to_table()

						-- Convert metadata item stacks to item strings
						for _, invlist in pairs(meta.inventory) do
							for index = 1, #invlist do
								local itemstack = invlist[index]
								if itemstack.to_string then
									invlist[index] = itemstack:to_string()
								end
							end
						end
					end
		  ]]
					result[count] = {
						x = pos.x - pos1.x,
						y = pos.y - pos1.y,
						z = pos.z - pos1.z,
						name = node.name,
						param1 = node.param1 ~= 0 and node.param1 or nil,
						param2 = node.param2 ~= 0 and node.param2 or nil,
						meta = meta,
					}
				end
				pos.z = pos.z + 1
			end
			pos.y = pos.y + 1
		end
		pos.x = pos.x + 1
	end
	-- Serialize entries
	result = minetest.serialize(result)
	return "5:" .. result, count
end

minetest.register_chatcommand("litesave", {
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
		  --detect_misaligned_schematic(name, litematica.pos1, litematica.pos2)
	  minetest.settings:set("litematica_output", result)
		  minetest.display_chat_message("Saved to \"litematica_output\" setting")
		end
	end,
})
