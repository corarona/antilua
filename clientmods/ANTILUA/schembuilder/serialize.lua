function sort_pos(pos1, pos2)
	pos1 = vector.copy(pos1)
	pos2 = vector.copy(pos2)
	if pos1.x > pos2.x then pos2.x, pos1.x = pos1.x, pos2.x end
	if pos1.y > pos2.y then pos2.y, pos1.y = pos1.y, pos2.y end
	if pos1.z > pos2.z then pos2.z, pos1.z = pos1.z, pos2.z end
	return pos1, pos2
end

function schembuilder_serialize(pos1, pos2)
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
	params = "[name]",
	description = "Save the current region to data/schematics/<name>.mts",
	func = function(param)
		if schembuilder.pos1 ~= nil and schembuilder.pos2 ~= nil then
			local name = param ~= "" and param or ("build_" .. os.date("%Y%m%d_%H%M%S"))
			local schem, count = schembuilder_serialize(schembuilder.pos1, schembuilder.pos2)
			local mts_data = core.serialize_schematic(schem, "mts")
			local filepath = core.get_data_path() .. "schematics/" .. name .. ".mts"
			local ok = core.write_file(filepath, mts_data)
			if ok then
				ws.notify("Saved " .. count .. " nodes to " .. filepath, ws.NOTIFY_INFO)
			else
				ws.notify("Failed to write " .. filepath, ws.NOTIFY_ERROR)
			end
		end
	end,
})
