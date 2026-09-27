-- Oysterity base scout: scores candidate sites from the persisted big map
-- (flatness, water nearby, distance from spawn, no obvious player builds).
-- Run through the pipe:
--   skills/playing-the-game/scripts/send_lua.py skills/oysterity/scripts/find_base.lua
-- Tuning goes through client settings (the sandbox has no os.getenv), e.g.
--   run_lua("core.settings:set('oysterity_base_radius', '800')")
--   oysterity_base_center   "x,z" scan centre (default: player position)
--   oysterity_base_radius   scan radius in nodes (default 600)
--   oysterity_base_step     grid step in nodes (default 16)
--   oysterity_spawn         "x,z" spawn point to stay away from (default 0,0)
--   oysterity_base_avoid    "x,z;x,z" known player bases to penalise
--   oysterity_base_top      how many candidates to return (default 5)

local lp = core.localplayer
if not lp then
	return {ok = false, error = "no local player yet (not joined)"}
end

local bm = core.al_bigmap
if not bm or not bm.get_pixel then
	return {ok = false, error = "core.al_bigmap unavailable (enable_minimap off?)"}
end

local function setting(name)
	local value = core.settings:get(name)
	return value or ""
end

local function setting_num(name, default)
	return tonumber(setting(name)) or default
end

local function setting_pos(name)
	local x, z = setting(name):match("^%s*(-?%d+)%s*,%s*(-?%d+)%s*$")
	if not x then
		return nil
	end
	return {x = tonumber(x), z = tonumber(z)}
end

local pos = lp:get_pos()
local center = setting_pos("oysterity_base_center")
	or {x = math.floor(pos.x / 16) * 16, z = math.floor(pos.z / 16) * 16}
local spawn = setting_pos("oysterity_spawn") or {x = 0, z = 0}
local radius = setting_num("oysterity_base_radius", 600)
local step = setting_num("oysterity_base_step", 16)
local top = setting_num("oysterity_base_top", 5)

local avoid = {}
for entry in setting("oysterity_base_avoid"):gmatch("[^;]+") do
	local x, z = entry:match("^%s*(-?%d+)%s*,%s*(-?%d+)%s*$")
	if x then
		avoid[#avoid + 1] = {x = tonumber(x), z = tonumber(z)}
	end
end

local BUILT_NODES = {
	["mcl_chests:chest"] = true,
	["mcl_chests:trapped_chest"] = true,
	["mcl_chests:ender_chest"] = true,
	["mcl_colorblocks:color"] = true,
	["mcl_torches:torch"] = true,
	["mcl_stairs:stone_stairs"] = true,
	["mcl_farming:field"] = true,
}

local function is_water(name)
	return name ~= nil and (name:find("water") ~= nil or name:find("ocean") ~= nil)
end

local function height_at(x, z)
	local px = bm.get_pixel(x, z)
	if not px then
		return nil
	end
	return px
end

local function score_site(x, z)
	local center_px = height_at(x, z)
	if not center_px then
		return nil
	end
	if is_water(center_px.node) then
		return nil
	end

	local h = center_px.height
	if h < 3 or h > 110 then
		return nil  -- beach or mountain: not a practical first base
	end

	-- Flatness: height spread over a 3x3 sample, all of it mapped.
	local heights, water, built = {}, 0, 0
	local complete = true
	for dx = -1, 1 do
		for dz = -1, 1 do
			local px = height_at(x + dx * step, z + dz * step)
			if not px then
				complete = false
			else
				heights[#heights + 1] = px.height
				if is_water(px.node) then
					water = water + 1
				elseif BUILT_NODES[px.node] then
					built = built + 1
				end
			end
		end
	end
	if #heights < 5 then
		return nil
	end

	local minh, maxh = heights[1], heights[1]
	for _, v in ipairs(heights) do
		minh = math.min(minh, v)
		maxh = math.max(maxh, v)
	end
	local spread = maxh - minh
	local flat = math.max(0, 100 - spread * 12)
	if not complete then
		flat = flat * 0.6
	end

	local d_spawn = math.floor(math.sqrt((x - spawn.x) ^ 2 + (z - spawn.z) ^ 2))
	local score = flat
	score = score + math.min(d_spawn / 30, 20)          -- away from spawn
	score = score + math.min(water * 8, 20)             -- water nearby
	score = score - math.min(built * 25, 75)            -- other people's work
	for _, a in ipairs(avoid) do
		local d = math.sqrt((x - a.x) ^ 2 + (z - a.z) ^ 2)
		if d < 64 then
			score = score - 40
		end
	end
	if center_px.air_count and center_px.air_count > 0 then
		score = score - 5   -- not a clean surface
	end

	return {
		x = x,
		y = h,
		z = z,
		score = math.floor(score),
		flat = math.floor(flat),
		height_spread = spread,
		water_near = water,
		builds_near = built,
		dist_from_spawn = d_spawn,
		dist_from_player = math.floor(math.sqrt((x - pos.x) ^ 2 + (z - pos.z) ^ 2)),
		node = center_px.node,
	}
end

local candidates, sampled, total = {}, 0, 0
for x = center.x - radius, center.x + radius, step do
	for z = center.z - radius, center.z + radius, step do
		total = total + 1
		local site = score_site(x, z)
		if site then
			sampled = sampled + 1
			candidates[#candidates + 1] = site
		end
	end
end

table.sort(candidates, function(a, b) return a.score > b.score end)

local out = {}
for i = 1, math.min(top, #candidates) do
	local site = candidates[i]
	-- First waypoint on the way there, so the walk is not a beeline into
	-- terrain; agent.open_target(n) picks safe intermediate spots.
	local dx, dz = site.x - pos.x, site.z - pos.z
	local len = math.max(1, math.sqrt(dx * dx + dz * dz))
	site.first_waypoint = {
		x = math.floor(pos.x + dx / len * 32),
		z = math.floor(pos.z + dz / len * 32),
	}
	out[i] = site
end

return {
	ok = true,
	name = lp:get_name(),
	player = {x = math.floor(pos.x), y = math.floor(pos.y), z = math.floor(pos.z)},
	center = center,
	radius = radius,
	step = step,
	spawn = spawn,
	avoid = avoid,
	mapped_fraction = total > 0 and math.floor(sampled / total * 100) or 0,
	sites_considered = sampled,
	candidates = out,
	hint = "walk with goto(pos,'walk'); use run_lua agent.open_target(8) for a safe "
		.. "intermediate target, then set-base once you have cleared the area",
}
