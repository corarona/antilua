function get_preview_texture(name)
	local def = core.get_node_def(name)
	if not def then return "unknown_node.png" end

	local tex = def.inventory_image
	if tex and tex ~= "" then
		return tex
	end

	if def.tiles and def.tiles[1] and def.tiles[1] ~= "" then
		tex = def.tiles[1]
		-- Strip composite modifiers to get the base texture
		local base = tex:match("^([^%[%^]+)")
		if base and base ~= "" then
			return base
		end
		-- If nothing left after stripping, use the raw modifier text
		local mod = tex:match("%[(.-)%]")
		if mod then
			-- e.g. "[combine:16x16:-1,0=unknown_node.png" -> unknown_node.png
			local file = mod:match("=([^,]+)")
			if file then return file end
		end
	end

	return "unknown_node.png"
end

function add_preview_particle(pos, node_name)
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
function add_preview_if_needed(pos, node_name)
	local current = core.get_node_or_nil(pos)
	if current and current.name == node_name then
		return
	end
	add_preview_particle(pos, node_name)
end
