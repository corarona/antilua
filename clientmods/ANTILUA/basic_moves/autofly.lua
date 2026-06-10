autofly={}
autofly.tpos=nil
autofly.atpos=nil
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

ws.rg("Autopilot", {
	category = "Movement",
	setting = "autopilot",
	on_step = function(self)
		local mode = core.settings:get(self.setting .. ".mode") or "3d_aim"
		local landing = tonumber(core.settings:get(self.setting .. ".landing_distance")) or 15
		local speed = tonumber(core.settings:get(self.setting .. ".speed")) or 1.0
		local alt_hold = core.settings:get_bool(self.setting .. ".altitude_hold") == true
		local alt = tonumber(core.settings:get(self.setting .. ".altitude")) or 10
		local avoid = core.settings:get_bool(self.setting .. ".avoid_obstacles") ~= false

		-- Determine target: POI waypoint or follow player
		local target
		if mode == "follow" then
			target, autofly.follow_name = find_closest_player()
			if not target then
				autofly.follow_name = nil
				return
			end
		else
			target = poi.last_pos
			if not target then return end
			autofly.follow_name = nil
		end

		local lp = ws.dircoord(0, 0, 0)
		local dst

		if mode == "2d_aim" then
			autofly.tpos = vector.new(target.x, lp.y, target.z)
			dst = vector.distance(lp, autofly.tpos)
		elseif mode == "nether" then
			autofly.tpos = vector.new(target.x / 8, lp.y, target.z / 8)
			dst = vector.distance(lp, autofly.tpos)
		else
			autofly.tpos = target
			dst = vector.distance(lp, target)
		end

		-- Obstacle avoidance: check block ahead, try to go around
		if avoid and mode ~= "3d_velocity" then
			local ahead = ws.dircoord(1, 0, 0)
			local nd = core.get_node_or_nil(ahead)
			if nd and nd.name ~= "air" then
				-- Try stepping up
				local up = ws.dircoord(1, 1, 0)
				local nu = core.get_node_or_nil(up)
				if nu and nu.name == "air" then
					core.localplayer:set_pos(up)
				else
					-- Try going around sideways (then forward)
					for _, side in ipairs({-1, 1}) do
						local aside = ws.dircoord(0, 0, side)
						local na = core.get_node_or_nil(aside)
						if na and na.name == "air" then
							local beyond = ws.dircoord(1, 0, side)
							local nb = core.get_node_or_nil(beyond)
							if nb and nb.name == "air" then
								core.localplayer:set_pos(beyond)
								break
							end
						end
					end
				end
			end
		end

		-- Altitude hold: maintain height above ground
		if alt_hold and mode ~= "3d_velocity" then
			local below = ws.dircoord(0, -1, 0)
			for check_y = 2, alt do
				local check = {x = below.x, y = lp.y - check_y, z = below.z}
				local nd = core.get_node_or_nil(check)
				if nd and nd.name ~= "air" then
					local target_y = check.y + alt
					if lp.y < target_y - 1 then
						core.localplayer:set_pos(vector.add(lp, {x=0, y=1, z=0}))
					elseif lp.y > target_y + 1 then
						core.localplayer:set_pos(vector.add(lp, {x=0, y=-1, z=0}))
					end
					break
				end
			end
		end

		-- Movement
		if mode == "3d_velocity" then
			if dst > landing and core.settings:get_bool("continuous_forward", false) then
				local dir = vector.direction(lp, target)
				core.localplayer:set_velocity(vector.multiply(dir,
					core.localplayer:get_movement_speed().walk / 10 * speed))
			else
				core.localplayer:set_pitch(0)
				core.settings:set_bool(self.setting, false)
			end
		else
			if dst > landing and core.settings:get_bool("continuous_forward", false) then
				ws.aim(autofly.tpos)
			else
				core.localplayer:set_pitch(0)
				core.settings:set_bool("continuous_forward", false)
				core.settings:set_bool(self.setting, false)
			end
		end
	end,
	on_start = function(self)
		local mode = core.settings:get(self.setting .. ".mode") or "3d_aim"
		-- Follow mode doesn't need a preselected waypoint
		if mode ~= "follow" and (not poi.last_pos or not poi.last_name) then
			return false, "Select a poi first."
		end
		local speed = tonumber(core.settings:get(self.setting .. ".speed")) or 1.0
		local lp = ws.dircoord(0, 0, 0)
		autofly.tpos = table.copy(poi.last_pos)

		-- Override movement speed
		core.localplayer:set_physics_override({ speed = speed })

		if mode == "2d_aim" then
			autofly.atpos = table.copy(poi.last_pos)
			autofly.tpos = vector.new(poi.last_pos.x, lp.y, poi.last_pos.z)
			local tdst = vector.distance(autofly.tpos, poi.last_pos)
			local label = "Target " .. math.floor(tdst) .. "m " ..
				(autofly.tpos.y < poi.last_pos.y and "below" or "above") ..
				" actual target '" .. poi.last_name .. "'"
			poi.display(autofly.tpos, label)
			core.settings:set_bool("continuous_forward", true)
		elseif mode == "nether" then
			autofly.tpos = vector.new(poi.last_pos.x / 8, lp.y, poi.last_pos.z / 8)
			core.settings:set_bool("continuous_forward", true)
			core.settings:set_bool("pitch_move", true)
		elseif mode == "3d_velocity" then
			core.localplayer:set_physics_override({ gravity = 0, speed = speed })
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
		mode = { type = "string", default = "3d_aim" },
		landing_distance = { type = "number", default = 15, min = 1, max = 100 },
		speed = { type = "number", default = 1.0, min = 0.1, max = 10 },
		altitude_hold = { type = "bool", default = false },
		altitude = { type = "number", default = 10, min = 1, max = 100 },
		avoid_obstacles = { type = "bool", default = true },
	},
})

-- Watch continuous_forward: if turned on with a waypoint selected, enable autopilot
local cf_was_on = false
core.register_globalstep(function()
	if not poi.last_pos then return end
	local cf_on = core.settings:get_bool("continuous_forward")
	if cf_on and not cf_was_on and not core.settings:get_bool("autopilot") then
		core.settings:set_bool("autopilot", true)
	end
	cf_was_on = cf_on
end)

function autofly.warp(name)
	local pos = autofly.get_waypoint(name)
	if pos then
		if ws.get_dimension(pos) == "void" then return false end
		core.localplayer:set_pos(pos)
		return true
	end
end

local function go_to(pos, name)
	poi.last_pos = pos
	poi.last_name = name
	core.settings:set_bool("autopilot", true)
end

poi.register_transport("Autopilot", function(pos, name) go_to(pos, name) end)
