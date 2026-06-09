-- rhythmic teleport: burst-move using anticheat pool credit
-- Toggle ON → continuously auto-teleport forward in look direction
-- Each burst spends up to budget seconds of pool, then recharges
-- Settings in cheat menu: budget, dist, h_speed, vup_speed, drain_factor

local MOVING = false
local ACTIVE = false

local SETTING = "rhythmtp"

local function get(key, default)
	local full = SETTING .. "." .. key
	local v = core.settings:get(full)
	if v then
		return tonumber(v) or default
	end
	return default
end

local function step()
	if not ACTIVE then
		MOVING = false
		return
	end

	local player = core.localplayer
	if not player then
		core.after(0.1, step)
		return
	end

	local target = MOVING
	local pos = player:get_pos()
	if not pos then
		core.after(0.05, step)
		return
	end

	local rem = vector.subtract(target, pos)
	local dist = vector.distance(pos, target)
	if dist < 2 then
		player:set_pos(target)
		MOVING = false
		return
	end

	local budget = get("budget", 10)
	local h_speed = get("h_speed", 4.0)
	local vup_speed = get("vup_speed", 26.0)
	local drain = get("drain_factor", 0.98)

	budget = math.max(1, math.min(14, budget))
	drain = math.max(0.5, math.min(1, drain))

	local h_rem = math.sqrt(rem.x * rem.x + rem.z * rem.z)
	local vup_rem = math.max(0, rem.y)
	local vdown_rem = -math.min(0, rem.y)

	local h_cost = h_rem / h_speed
	local vup_cost = vup_rem / vup_speed
	local cost = math.max(h_cost, vup_cost)

	local scale = 1
	if cost > budget then
		scale = budget / cost
	end

	local move_h = h_rem * scale
	local move_vup = vup_rem * scale
	local move_vdown = vdown_rem

	if h_rem > 0.001 then
		local h_scale = move_h / h_rem
		rem.x = rem.x * h_scale
		rem.z = rem.z * h_scale
	end
	if vup_rem > 0.001 then
		rem.y = move_vup
	else
		rem.y = -move_vdown
	end

	local next_pos = vector.add(pos, rem)
	player:set_pos(next_pos)

	local actual_cost = math.max(move_h / h_speed, move_vup / vup_speed)
	local wait = math.max(0.05, actual_cost * drain)
	core.after(wait, step)
end

local function go_to(target)
	if ACTIVE then
		return
	end
	ACTIVE = true
	MOVING = target
	core.settings:set_bool("free_move", true)
	step()
end

local function go_forward(dist)
	if ACTIVE then
		return
	end
	dist = dist or get("dist", 100)
	local player = core.localplayer
	if not player then
		return
	end
	local yaw = player:get_yaw() * math.pi / 180
	local dir = {x = math.sin(yaw), y = 0, z = math.cos(yaw)}
	local pos = player:get_pos()
	if not pos then
		return
	end
	local target = vector.add(pos, {x = dir.x * dist, y = 0, z = dir.z * dist})
	go_to(target)
end

local function stop()
	ACTIVE = false
	MOVING = false
end

-- auto-run when the cheat toggle is on
core.register_globalstep(function()
	if ACTIVE then
		return
	end
	if core.settings:get_bool(SETTING) then
		go_forward()
	end
end)

if core.register_cheat then
	core.register_cheat("RhythmTP", {
		category = "Movement",
		setting = SETTING,
		cheat_settings = {
			budget = {
				type = "number",
				default = 10,
				label = "Pool budget (s)",
			},
			dist = {
				type = "number",
				default = 100,
				label = "Forward dist (m)",
			},
			h_speed = {
				type = "number",
				default = 4.0,
				label = "Walk speed",
			},
			vup_speed = {
				type = "number",
				default = 26.0,
				label = "Jump speed",
			},
			drain_factor = {
				type = "number",
				default = 0.98,
				label = "Drain factor",
			},
		},
	})
end

core.register_chatcommand("rhythmtp", {
	description = "One-shot burst forward. 'stop' to cancel.",
	params = "[dist]",
	func = function(param)
		if param == "stop" then
			stop()
			return
		end
		local d = tonumber(param)
		go_forward(d)
	end,
})

core.register_chatcommand("rhythmtp_to", {
	description = "Burst-teleport to coordinates",
	params = "<x,y,z>",
	func = function(param)
		local t = core.string_to_pos(param)
		if not t then
			return false, "Invalid position"
		end
		go_to(t)
	end,
})
