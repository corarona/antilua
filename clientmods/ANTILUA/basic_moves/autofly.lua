autofly = {}
autofly.tpos = nil
autofly.atpos = nil
autofly.follow_name = nil

local function find_closest_player()
	local lp = core.localplayer
	if not lp then return end
	local pos = lp:get_pos()
	local closest_pos, closest_name, closest_dist
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 500)) do
		if obj:is_player() and not obj:is_local_player() then
			local op = obj:get_pos()
			local dist = vector.distance(pos, op)
			if not closest_pos or dist < closest_dist then
				closest_pos = op
				closest_name = obj:get_name()
				closest_dist = dist
			end
		end
	end
	return closest_pos, closest_name
end

-- The follow target is a 500-radius object scan, which is expensive on busy
-- servers. Rescan at most once per second and reuse the cached result between
-- scans so autopilot doesn't re-scan every step (0.2s).
local follow_scan_time = 0
local follow_cache_pos, follow_cache_name

local function resolve_follow_target()
	local now = (core.get_us_time() or 0) / 1000000
	if now - follow_scan_time >= 1.0 then
		follow_scan_time = now
		follow_cache_pos, follow_cache_name = find_closest_player()
	end
	return follow_cache_pos, follow_cache_name
end

local function resolve_target(mode)
	if mode == "follow" then
		local pos, name = resolve_follow_target()
		autofly.follow_name = name
		return pos
	end
	autofly.follow_name = nil
	return poi.last_pos
end

local function read_settings(self)
	return {
		mode = core.settings:get(self.setting .. ".mode") or "3d_aim",
		landing = tonumber(core.settings:get(self.setting .. ".landing_distance")) or 15,
		speed = tonumber(core.settings:get(self.setting .. ".speed")) or 1.0,
		alt_hold = core.settings:get_bool(self.setting .. ".altitude_hold"),
		alt = tonumber(core.settings:get(self.setting .. ".altitude")) or 10,
		avoid = core.settings:get(self.setting .. ".avoid_obstacles") ~= "false",
	}
end

local function compute_tpos(mode, target, lp)
	if mode == "2d_aim" then
		return vector.new(target.x, lp.y, target.z)
	elseif mode == "nether" then
		return vector.new(target.x / 8, lp.y, target.z / 8)
	end
	return target
end

-- First solid node below the player (water counts, so hover works over
-- oceans). A single downward raycast replaces the old per-node scan.
local function find_ground_y(lp, max_y)
	local ray = core.raycast(
		{x = lp.x, y = lp.y - 1, z = lp.z},
		{x = lp.x, y = lp.y - max_y, z = lp.z},
		false, true
	)
	for point in ray do
		if point.type == "node" then
			local nd = core.get_node_or_nil(point.under)
			if nd and nd.name ~= "air" and nd.name ~= "ignore" then
				return point.under.y
			end
		end
	end
end

local function altitude_adjust(lp, target_y, threshold, step)
	if not target_y then return end
	if lp.y < target_y - threshold then
		core.localplayer:set_pos(vector.add(lp, {x = 0, y = step, z = 0}))
	elseif lp.y > target_y + threshold then
		core.localplayer:set_pos(vector.add(lp, {x = 0, y = -step, z = 0}))
	end
end

-- Passable == air or ignore (unloaded/map edge). Solid nodes block flight.
local function is_solid(pos)
	local nd = core.get_node_or_nil(pos)
	if not nd then return false end
	return nd.name ~= "air" and nd.name ~= "ignore"
end

-- Obstacles are probed along the actual flight path (the horizontal vector
-- from the player to the target) rather than ws.dircoord, which buckets yaw
-- into N/S/E/W and can point up to 45° away from the true heading on
-- diagonals. `fwd` is a unit vector in that direction, `side` perpendicular.
local function obstacle_avoidance(lp)
	local target = autofly.tpos or autofly.atpos or poi.last_pos
	if not target then return end
	local d = vector.direction(lp, target)
	if d.x == 0 and d.z == 0 then return end
	local len = math.sqrt(d.x * d.x + d.z * d.z)
	local fwd = { x = d.x / len, z = d.z / len }
	local side = { x = -fwd.z, z = fwd.x }

	local ahead = vector.add(lp, { x = fwd.x, y = 0, z = fwd.z })
	if not is_solid(ahead) then return end
	local up = vector.add(ahead, { x = 0, y = 1, z = 0 })
	if not is_solid(up) then
		core.localplayer:set_pos(up)
		return
	end
	-- Descend into dips: straight ahead is blocked but below-forward is open
	-- (e.g. flying at a plateau edge), so drop instead of hitting the wall.
	local down = vector.add(ahead, { x = 0, y = -1, z = 0 })
	if not is_solid(down) then
		core.localplayer:set_pos(down)
		return
	end
	for _, s in ipairs({1, -1}) do
		local aside = vector.add(lp, { x = side.x * s, y = 0, z = side.z * s })
		local beyond = vector.add(ahead, { x = side.x * s, y = 0, z = side.z * s })
		if not is_solid(aside) and not is_solid(beyond) then
			core.localplayer:set_pos(beyond)
			return
		end
	end
end

local function execute_movement(self, s, dst, lp)
	-- Follow mode tracks a moving player: it should keep approaching, not
	-- switch off the moment we get close. Arrival only applies to POI modes.
	if dst <= s.landing and s.mode ~= "follow" then
		core.localplayer:set_pitch(0)
		core.settings:set_bool("continuous_forward", false)
		core.settings:set_bool(self.setting, false)
		autofly.arrived = true
		ws.notify("Arrived at " .. (poi.last_name or ws.pos_to_string(autofly.tpos)), ws.NOTIFY_SUCCESS)
		return
	end
	if not core.settings:get_bool("continuous_forward") then return end
	if s.mode == "3d_velocity" then
		local dir = vector.direction(lp, autofly.tpos)
		core.localplayer:set_velocity(vector.multiply(dir,
			core.localplayer:get_movement_speed().walk / 10 * s.speed))
	else
		ws.aim(autofly.tpos)
	end
end

ws.rg("Autopilot", {
	category = "Movement",
	setting = "autopilot",
	description = "Automatic flight with obstacle avoidance",
	on_step = function(self, dtime)
		local s = read_settings(self)
		local target = resolve_target(s.mode)
		if not target then
			-- Don't hover forever in follow mode when the target is gone.
			if s.mode == "follow" then
				self._no_target = (self._no_target or 0) + (dtime or 0)
				if self._no_target > 15 then
					autofly.follow_name = nil
					core.settings:set_bool(self.setting, false)
					ws.notify("Follow target lost", ws.NOTIFY_WARNING)
				end
			end
			return
		end
		self._no_target = nil

		local lp = ws.dircoord(0, 0, 0)
		autofly.tpos = compute_tpos(s.mode, target, lp)
		local dst = vector.distance(lp, autofly.tpos)

		-- Hover mode: altitude above ground
		if s.mode == "hover" then
			local gy = find_ground_y(lp, 100)
			if gy then altitude_adjust(lp, gy + s.alt, 0.5, 0.3) end
		end

		-- Obstacle avoidance
		if s.avoid and s.mode ~= "3d_velocity" then
			obstacle_avoidance(lp)
		end

		-- Altitude hold (not for hover or 3d_velocity)
		if s.alt_hold and s.mode ~= "3d_velocity" and s.mode ~= "hover" then
			local gy = find_ground_y(lp, 200)
			if gy then altitude_adjust(lp, gy + s.alt, 1, 1) end
		end

		execute_movement(self, s, dst, lp)
	end,
	on_start = function(self)
		autofly.arrived = nil
		self._no_target = nil
		follow_scan_time = 0
		follow_cache_pos, follow_cache_name = nil, nil
		local mode = core.settings:get(self.setting .. ".mode") or "3d_aim"
		self._mode = mode
		if mode ~= "follow" and (not poi.last_pos or not poi.last_name) then
			return false, "Select a poi first (.waypoints or the ~ palette)."
		end
		local speed = tonumber(core.settings:get(self.setting .. ".speed")) or 1.0
		local lp = ws.dircoord(0, 0, 0)
		if poi.last_pos then
			autofly.tpos = table.copy(poi.last_pos)
		end

		self._phys_prev = core.localplayer:get_physics_override()
		core.localplayer:set_physics_override({ speed = speed })

		autofly.atpos = nil
		if mode == "2d_aim" then
			autofly.atpos = table.copy(poi.last_pos)
			autofly.tpos = vector.new(poi.last_pos.x, lp.y, poi.last_pos.z)
			local tdst = vector.distance(autofly.tpos, poi.last_pos)
			local label = "Target " .. math.floor(tdst) .. "m "
				.. (autofly.tpos.y < poi.last_pos.y and "below" or "above")
				.. " actual target '" .. poi.last_name .. "'"
			poi.display(autofly.tpos, label)
			core.settings:set_bool("continuous_forward", true)
		elseif mode == "nether" then
			autofly.tpos = vector.new(poi.last_pos.x / 8, lp.y, poi.last_pos.z / 8)
			core.settings:set_bool("continuous_forward", true)
			core.settings:set_bool("pitch_move", true)
		elseif mode == "3d_velocity" then
			core.localplayer:set_physics_override({ gravity = 0, speed = speed })
		end

		if mode == "hover" then
			core.settings:set_bool("continuous_forward", true)
			core.settings:set_bool("pitch_move", true)
		end

		if mode ~= "2d_aim" then
			poi.display(autofly.tpos, poi.last_name)
		end
	end,
	on_stop = function(self)
		-- Clean up using the mode that was active during the run, not the
		-- setting, which may have been changed mid-flight.
		local mode = self._mode or core.settings:get(self.setting .. ".mode") or "3d_aim"
		self._mode = nil
		if self._phys_prev then
			core.localplayer:set_physics_override(self._phys_prev)
			self._phys_prev = nil
		end
		if mode == "2d_aim" and autofly.atpos then
			poi.display(autofly.atpos, poi.last_name)
			ws.aim(autofly.atpos)
		end
		autofly.atpos = nil
		follow_scan_time = 0
		follow_cache_pos, follow_cache_name = nil, nil
	end,
	daughters = {"continuous_forward", "pitch_move", "flight_hud", "freelook"},
	cheat_settings = {
		mode = { type = "enum", default = "3d_aim",
			values = {"3d_aim", "2d_aim", "3d_velocity", "nether", "follow", "hover"},
			labels = {"Direct line", "Horizontal aim", "Zero-gravity",
				"Nether portal", "Follow player", "Hover"} },
		landing_distance = { type = "number", default = 15, min = 1, max = 100 },
		speed = { type = "number", default = 1.0, min = 0.1, max = 10 },
		altitude_hold = { type = "bool", default = false },
		altitude = { type = "number", default = 10, min = 1, max = 100 },
		avoid_obstacles = { type = "bool", default = true },
		autoengage = { type = "bool", default = true },
	},
})

-- Auto-engage autopilot when the user presses forward while a POI is
-- selected. Gated behind autopilot.autoengage so other mods toggling
-- continuous_forward don't silently start an autopilot run.
local cf_was_on = false
local function maybe_autoengage()
	local cf_on = core.settings:get_bool("continuous_forward")
	if cf_on and not cf_was_on and not core.settings:get_bool("autopilot")
			and not autofly.arrived and poi.last_pos
			and core.settings:get_bool("autopilot.autoengage") then
		core.settings:set_bool("autopilot", true)
	end
	cf_was_on = cf_on
end
core.register_globalstep(maybe_autoengage)
core.register_on_disconnect(function() cf_was_on = false end)

function autofly.warp(name)
	local pos = poi.get_waypoint(name)
	if not pos then return false end
	if ws.get_dimension(pos) == "void" then return false end
	core.localplayer:set_pos(pos)
	return true
end

local function go_to(pos, name)
	poi.last_pos = pos
	poi.last_name = name
	autofly.arrived = nil
	core.settings:set_bool("autopilot", true)
end

poi.register_transport("Autopilot", function(pos, name) go_to(pos, name) end)
