-- Oysterity Nether Railway Network
-- Finds nearest rail portal on the Oysterity Minecraft server
-- and sets a waypoint at it.

local RAIL_PORTAL_SPACING = 200
local RAIL_PORTAL_MAX = 3800
local RAIL_RINGS = {420, 666, 1337, 2666, 3860}
local RAIL_PORTAL_Y_NETHER = -28946.5
local RAIL_PORTAL_Y_OVERWORLD = 1

local function ring_perimeter_point(R, d)
	local side = math.floor(d / (2 * R))
	local offset = d % (2 * R)
	if side == 0 then
		return R, -R + offset
	elseif side == 1 then
		return R - offset, R
	elseif side == 2 then
		return -R, R - offset
	else
		return -R + offset, -R
	end
end

local function find_nearest_rail_portal(nx, nz)
	local best_dsq = math.huge
	local best_x, best_z = 0, 0

	for n = -19, 19 do
		local ax, az = n * RAIL_PORTAL_SPACING, 0
		local dsq = (nx - ax)^2 + (nz - az)^2
		if dsq < best_dsq then
			best_dsq = dsq
			best_x, best_z = ax, az
		end
		ax, az = 0, n * RAIL_PORTAL_SPACING
		dsq = (nx - ax)^2 + (nz - az)^2
		if dsq < best_dsq then
			best_dsq = dsq
			best_x, best_z = ax, az
		end
	end

	for _, R in ipairs(RAIL_RINGS) do
		local perimeter = 8 * R
		for d = 0, perimeter - RAIL_PORTAL_SPACING, RAIL_PORTAL_SPACING do
			local px, pz = ring_perimeter_point(R, d)
			local dsq = (nx - px)^2 + (nz - pz)^2
			if dsq < best_dsq then
				best_dsq = dsq
				best_x, best_z = px, pz
			end
		end
	end
	return best_x, best_z
end

core.register_chatcommand("oy_railportal", {
	params = "[x,[y,]z]",
	description = "Find nearest oysterity nether railway portal. Uses current pos if no args.",
	func = function(param)
		local x, y, z
		local is_nether = false

		if param == nil or param == "" then
			local pos = core.localplayer:get_pos()
			if not pos then
				return false, "Could not get player position."
			end
			x, y, z = pos.x, pos.y, pos.z
		else
			param = param:gsub(",", " ")
			local parts = {}
			for p in param:gmatch("%S+") do
				table.insert(parts, p)
			end
			if #parts == 2 then
				x = tonumber(parts[1])
				z = tonumber(parts[2])
				y = nil
			elseif #parts >= 3 then
				x = tonumber(parts[1])
				y = tonumber(parts[2])
				z = tonumber(parts[3])
			else
				return false, "Usage: .railportal [x,[y,]z]"
			end
			if not x or not z then
				return false, "Invalid coordinates."
			end
		end

		if y then
			is_nether = y < -20000
		end

		if not is_nether then
			x = x / 8
			z = z / 8
		end

		local px, pz = find_nearest_rail_portal(x, z)

		if is_nether then
			x, z = px, pz
			y = RAIL_PORTAL_Y_NETHER
		else
			x = math.floor(px * 8)
			z = math.floor(pz * 8)
			y = RAIL_PORTAL_Y_OVERWORLD
		end

		local pos = {x = x, y = y, z = z}
		local dim = is_nether and "Nether" or "Overworld"

		poi.set_waypoint(pos, "Rail Portal")
		poi.display_waypoint("Rail Portal")

		return true, dim .. " Rail Portal at " .. x .. ", " .. y .. ", " .. z
	end,
})