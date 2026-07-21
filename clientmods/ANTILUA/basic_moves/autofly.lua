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

local function read_settings(self)
	return {
		mode = core.settings:get(self.setting .. ".mode") or "3d_aim",
		landing = tonumber(core.settings:get(self.setting .. ".landing_distance")) or 15,
		speed = tonumber(core.settings:get(self.setting .. ".speed")) or 1.0,
		alt_hold = core.settings:get_bool(self.setting .. ".altitude_hold"),
		alt = tonumber(core.settings:get(self.setting .. ".altitude")) or 10,
		avoid = core.settings:get_bool(self.setting .. ".avoid_obstacles") ~= false,
	}
end

local function resolve_target(mode)
	if mode == "follow" then
		local pos, name = find_closest_player()
		autofly.follow_name = name
		return pos
	end
	autofly.follow_name = nil
	return poi.last_pos
end

local function compute_tpos(mode, target, lp)
	if mode == "2d_aim" then
		return vector.new(target.x, lp.y, target.z)
	elseif mode == "nether" then
		return vector.new(target.x / 8, lp.y, target.z / 8)
	end
	return target
end

local function find_ground_y(lp, max_y)
	for dy = 2, max_y do
		local check = {x = lp.x, y = lp.y - dy, z = lp.z}
		local nd = core.get_node_or_nil(check)
		if nd and nd.name ~= "air" then
			return check.y
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

local function obstacle_avoidance(lp)
	local ahead = ws.dircoord(1, 0, 0)
	local nd = core.get_node_or_nil(ahead)
	if not (nd and nd.name ~= "air") then return end
	local up = ws.dircoord(1, 1, 0)
	if core.get_node_or_nil(up) and core.get_node_or_nil(up).name == "air" then
		core.localplayer:set_pos(up)
		return
	end
	for _, side in ipairs({-1, 1}) do
		local aside = ws.dircoord(0, 0, side)
		local beyond = ws.dircoord(1, 0, side)
		if core.get_node_or_nil(aside) and core.get_node_or_nil(aside).name == "air"
				and core.get_node_or_nil(beyond) and core.get_node_or_nil(beyond).name == "air" then
			core.localplayer:set_pos(beyond)
			return
		end
	end
end

local function execute_movement(self, s, dst, target, lp)
	if dst <= s.landing then
		core.localplayer:set_pitch(0)
		core.settings:set_bool("continuous_forward", false)
		core.settings:set_bool(self.setting, false)
		autofly.arrived = true
		return
	end
	if not core.settings:get_bool("continuous_forward") then return end
	if s.mode == "3d_velocity" then
		local dir = vector.direction(lp, target)
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
	on_step = function(self)
		local s = read_settings(self)
		local target = resolve_target(s.mode)
		if not target then return end

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
			local gy = find_ground_y(lp, s.alt)
			if gy then altitude_adjust(lp, gy + s.alt, 1, 1) end
		end

		execute_movement(self, s, dst, target, lp)
	end,
	on_start = function(self)
		autofly.arrived = nil
		local mode = core.settings:get(self.setting .. ".mode") or "3d_aim"
		if mode ~= "follow" and (not poi.last_pos or not poi.last_name) then
			return false, "Select a poi first."
		end
		local speed = tonumber(core.settings:get(self.setting .. ".speed")) or 1.0
		local lp = ws.dircoord(0, 0, 0)
		autofly.tpos = table.copy(poi.last_pos)

		core.localplayer:set_physics_override({ speed = speed })

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
		local mode = core.settings:get(self.setting .. ".mode") or "3d_aim"
		core.localplayer:set_physics_override({ speed = 1, gravity = 1 })
		if mode == "2d_aim" then
			poi.display(autofly.atpos, poi.last_name)
			ws.aim(autofly.atpos)
		end
	end,
	daughters = {"continuous_forward", "pitch_move", "flight_hud", "freelook"},
	cheat_settings = {
		mode = { type = "enum", default = "3d_aim", values = {"3d_aim", "2d_aim", "3d_velocity", "nether", "follow", "hover"} },
		landing_distance = { type = "number", default = 15, min = 1, max = 100 },
		speed = { type = "number", default = 1.0, min = 0.1, max = 10 },
		altitude_hold = { type = "bool", default = false },
		altitude = { type = "number", default = 10, min = 1, max = 100 },
		avoid_obstacles = { type = "bool", default = true },
	},
})

local cf_was_on = false
core.register_globalstep(function()
	if not poi.last_pos or autofly.arrived then return end
	local cf_on = core.settings:get_bool("continuous_forward")
	if cf_on and not cf_was_on and not core.settings:get_bool("autopilot") then
		core.settings:set_bool("autopilot", true)
	end
	cf_was_on = cf_on
end)

function autofly.warp(name)
	local pos = poi.get_waypoint(name)
	if pos then
		if ws.get_dimension(pos) == "void" then return false end
		core.localplayer:set_pos(pos)
		return true
	end
end

local function go_to(pos, name)
	poi.last_pos = pos
	poi.last_name = name
	autofly.arrived = nil
	core.settings:set_bool("autopilot", true)
end

poi.register_transport("Autopilot", function(pos, name) go_to(pos, name) end)
