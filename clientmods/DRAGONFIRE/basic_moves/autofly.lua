autofly={}
autofly.tpos=nil
autofly.atpos=nil

ws.rg("Autopilot", {
	category = "Movement",
	setting = "autopilot",
	on_step = function(self)
		if not poi.last_pos then return end
		local mode = core.settings:get(self.setting .. ".mode") or "3d_aim"
		local landing = tonumber(core.settings:get(self.setting .. ".landing_distance")) or 15
		local lp = ws.dircoord(0, 0, 0)
		local dst

		if mode == "2d_aim" then
			autofly.tpos = vector.new(poi.last_pos.x, lp.y, poi.last_pos.z)
			dst = vector.distance(lp, autofly.tpos)
		elseif mode == "nether" then
			autofly.tpos = vector.new(poi.last_pos.x / 8, lp.y, poi.last_pos.z / 8)
			dst = vector.distance(lp, autofly.tpos)
		else
			autofly.tpos = poi.last_pos
			dst = vector.distance(lp, autofly.tpos)
		end

		if mode == "3d_velocity" then
			if dst > landing and minetest.settings:get_bool("continuous_forward", false) then
				local dir = vector.direction(lp, poi.last_pos)
				minetest.localplayer:set_velocity(vector.multiply(dir,
					minetest.localplayer:get_movement_speed().walk / 10))
			else
				minetest.settings:set_bool(self.setting, false)
			end
		else
			if dst > landing and minetest.settings:get_bool("continuous_forward", false) then
				ws.aim(autofly.tpos)
				if mode == "nether" then
					if autofly.set_info then autofly.set_info(dst) end
				end
			else
				minetest.settings:set_bool("continuous_forward", false)
				if mode ~= "2d_aim" then
					minetest.settings:set_bool(self.setting, false)
				end
			end
		end
	end,
	on_start = function(self)
		if not poi.last_pos or not poi.last_name then
			return false, "Select a poi first."
		end
		local mode = core.settings:get(self.setting .. ".mode") or "3d_aim"
		local lp = ws.dircoord(0, 0, 0)
		autofly.tpos = table.copy(poi.last_pos)

		if mode == "2d_aim" then
			autofly.atpos = table.copy(poi.last_pos)
			autofly.tpos = vector.new(poi.last_pos.x, lp.y, poi.last_pos.z)
			local tdst = vector.distance(autofly.tpos, poi.last_pos)
			local label = "Target " .. math.floor(tdst) .. "m " ..
				(autofly.tpos.y < poi.last_pos.y and "below" or "above") ..
				" actual target '" .. poi.last_name .. "'"
			poi.display(autofly.tpos, label)
			minetest.settings:set_bool("continuous_forward", true)
		elseif mode == "nether" then
			autofly.tpos = vector.new(poi.last_pos.x / 8, lp.y, poi.last_pos.z / 8)
			if autofly.set_info then autofly.set_info(dst or 0) end
			minetest.settings:set_bool("continuous_forward", true)
			minetest.settings:set_bool("pitch_move", true)
		elseif mode == "3d_velocity" then
			minetest.localplayer:set_physics_override({ gravity = 0 })
		end

		if mode ~= "2d_aim" then
			poi.display(autofly.tpos, poi.last_name)
		end
	end,
	on_stop = function(self)
		local mode = core.settings:get(self.setting .. ".mode") or "3d_aim"
		if mode == "2d_aim" then
			poi.display(autofly.atpos, poi.last_name)
			ws.aim(autofly.atpos)
		elseif mode == "3d_velocity" then
			minetest.localplayer:set_physics_override({ gravity = 1 })
		end
	end,
	daughters = {"continuous_forward", "pitch_move", "flight_hud", "freelook"},
	cheat_settings = {
		mode = { type = "string", default = "3d_aim" },
		landing_distance = { type = "number", default = 15, min = 1, max = 100 },
	},
})

function autofly.warp(name)
	local pos=autofly.get_waypoint(name)
	if pos then
		if ws.get_dimension(pos) == "void" then return false end
		minetest.localplayer:set_pos(pos)
		return true
	end
end

local function go_to(pos, name)
	poi.last_pos = pos
	poi.last_name = name
	minetest.settings:set_bool("autopilot", true)
end

poi.register_transport("Autopilot", function(pos, name) go_to(pos, name) end)
