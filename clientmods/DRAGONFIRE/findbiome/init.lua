local water_level = 1
--tonumber(minetest.get_mapgen_setting("water_level"))

-- Calculate the maximum playable limit
local mapgen_limit = 31007
--tonumber(minetest.get_mapgen_setting("mapgen_limit"))
local chunksize = 5
--tonumber(minetest.get_mapgen_setting("chunksize"))
local playable_limit = math.max(mapgen_limit - (chunksize + 1) * 16, 0)

-- Parameters
-------------

-- Resolution of search grid in nodes.
local res = 64
-- Number of points checked in the square search grid (edge * edge).
local checks = 128 * 128

-- End of parameters
--------------------

-- Direction table

local dirs = {
	{x = 0, y = 0, z = 1},
	{x = -1, y = 0, z = 0},
	{x = 0, y = 0, z = -1},
	{x = 1, y = 0, z = 0},
}

-- Returns true if pos is within the world boundaries
local function is_in_world(pos)
	return not (math.abs(pos.x) > playable_limit or math.abs(pos.y) > playable_limit or math.abs(pos.z) > playable_limit)
end


local function find_biome(pos, biomes)
	pos = vector.round(pos)
	-- Pos: Starting point for biome checks. This also sets the y co-ordinate for all
	-- points checked, so the suitable biomes must be active at this y.

	-- Initial variables

	local edge_len = 1
	local edge_dist = 0
	local dir_step = 0
	local dir_ind = 1
	local success
	local spawn_pos
	local biome_ids

	-- Get next position on square search spiral
	local function next_pos()
		if edge_dist == edge_len then
			edge_dist = 0
			dir_ind = dir_ind + 1
			if dir_ind == 5 then
				dir_ind = 1
			end
			dir_step = dir_step + 1
			edge_len = math.floor(dir_step / 2) + 1
		end

		local dir = dirs[dir_ind]
		local move = vector.multiply(dir, res)

		edge_dist = edge_dist + 1

		return vector.add(pos, move)
	end

	-- Position search
	local function search()
		local attempt = 1
		while attempt < 3 do
			for iter = 1, checks do
				local biome_data = minetest.get_biome_data(pos)
				-- Sometimes biome_data is nil
				local biome = biome_data and biome_data.biome
				for id_ind = 1, #biome_ids do
					local biome_id = biome_ids[id_ind]
					pos = adjust_pos_to_biome_limits(pos, biome_id)
					local spos = table.copy(pos)
					if biome == biome_id then
						local good_spawn_height = pos.y <= water_level + 16 and pos.y >= water_level
						local spawn_y = minetest.get_spawn_level(spos.x, spos.z)
						if spawn_y then
							spawn_pos = {x = spos.x, y = spawn_y, z = spos.z}
						elseif not good_spawn_height then
							spawn_pos = {x = spos.x, y = spos.y, z = spos.z}
						elseif attempt >= 2 then
							spawn_pos = {x = spos.x, y = spos.y, z = spos.z}
						end
						if spawn_pos then
							local _,outside = adjust_pos_to_biome_limits(spawn_pos, biome_id)
							if is_in_world(spawn_pos) and not outside then
								return true
							end
						end
					end
				end

				pos = next_pos()
			end
			attempt = attempt + 1
		end
		return false
	end

	-- Table of suitable biomes
	biome_ids = {}
	for i=1, #biomes do
		local id = minetest.get_biome_id(biomes[i])
		if not id then
			return nil, false
		end
		table.insert(biome_ids, id)
	end
	success = search()

	return spawn_pos, success

end
