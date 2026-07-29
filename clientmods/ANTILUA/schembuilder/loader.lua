function load_schematic(value)
	local content = value:match("^5:(.*)$")
	if not content then
		return nil
	end
	return deserialize_workaround(content)
end

function load_schematic_nodes(value, pos)
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
				if entry.name ~= "air" and entry.prob ~= 0 then
					table.insert(nodes, {
						x = pos.x + (entry.x or 0),
						y = pos.y + (entry.y or 0),
						z = pos.z + (entry.z or 0),
						name = entry.name,
						param2 = entry.param2 or 0,
					})
				end
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
			if entry.name ~= "air" then
				entry.x, entry.y, entry.z = ox + entry.x, oy + entry.y, oz + entry.z
				table.insert(place_nodes, entry)
				add_preview_if_needed(entry, entry.name)
			end
		end
		if #place_nodes > 0 then
			ws.notify("Loaded " .. #place_nodes .. " nodes", ws.NOTIFY_INFO)
			core.after(0.1, update_hud)
		end
		return #place_nodes
	end

	return nil
end
