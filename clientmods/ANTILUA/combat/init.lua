-- Combat mod: Killaura + PatrolGuard bot

local killaura = {}

local punch_ctx = {
	obj = nil,
	remaining = 0,
	max_burst = 8,
	interval = 0.05,
}

function killaura.get(key)
	return ws.get_number("killaura", key) or killaura[key]
end

local function do_punch_step()
	if not punch_ctx.obj then return end
	if not core.localplayer then return end
	if not punch_ctx.obj:get_pos() then
		punch_ctx.obj = nil
		return
	end
	punch_ctx.obj:punch()
	punch_ctx.remaining = punch_ctx.remaining - 1
	if punch_ctx.remaining > 0 then
		core.after(punch_ctx.interval, do_punch_step)
	end
end

function killaura.queue_punches(obj, count)
	if not obj or not obj:get_pos() then return end
	if punch_ctx.obj and punch_ctx.obj ~= obj then
		punch_ctx.remaining = 0
	end
	punch_ctx.obj = obj
	punch_ctx.remaining = count
	if punch_ctx.remaining > 0 then
		core.after(0, do_punch_step)
	end
end

local PASSIVE_MOBS = {
	"mobs_mc:cow", "mobs_mc:sheep", "mobs_mc:chicken", "mobs_mc:pig",
	"mobs_mc:rabbit", "mobs_mc:horse", "mobs_mc:donkey", "mobs_mc:mule",
	"mobs_mc:llama", "mobs_mc:parrot", "mobs_mc:ocelot", "mobs_mc:cat",
	"mobs_mc:wolf", "mobs_mc:fox", "mobs_mc:panda", "mobs_mc:polar_bear",
	"mobs_mc:villager", "mobs_mc:iron_golem", "mobs_mc:snowman",
	"mobs_mc:squid", "mobs_mc:dolphin", "mobs_mc:turtle", "mobs_mc:bat",
	"mobs_mc:salmon", "mobs_mc:cod", "mobs_mc:tropical_fish",
	"mobs_mc:pufferfish", "mobs_mc:axolotl", "mobs_mc:goat", "mobs_mc:bee",
	"mobs_mc:strider",
}

local function is_mob(obj)
	if not obj then return false end
	local name = obj:get_name() or ""
	return name:find("mobs_mc:") == 1 or name:find("extra_mobs:") == 1
end

local function is_hostile_mob(obj)
	local name = obj and obj:get_name() or ""
	if name:find("mobs_mc:") ~= 1 then return false end
	for _, p in ipairs(PASSIVE_MOBS) do
		if name == p then return false end
	end
	return true
end

local function should_attack(obj)
	if not obj or obj:is_local_player() then return false end
	if obj:is_player() then return true end
	if core.settings:get_bool("killaura.attack_mobs") and is_mob(obj) then return true end
	return false
end

local function get_target_name(obj)
	if obj:is_player() then return obj:get_name() end
	local props = obj:get_properties()
	return (props and props.nametag) or "mob"
end

local function make_hp_bar(hp, max_hp)
	local segments = 10
	local filled = math.max(0, math.min(math.floor((hp / math.max(max_hp, 1)) * segments), segments))
	local bar = {}
	for i = 1, segments do
		bar[i] = i <= filled and "█" or "░"
	end
	return table.concat(bar)
end

local function get_hp_color(hp, max_hp)
	local ratio = hp / math.max(max_hp, 1)
	if ratio > 0.6 then return 0xFFCCFFCC end
	if ratio > 0.3 then return 0xFFFFFF88 end
	return 0xFFFF8888
end

local function update_target_hud(closest)
	if not killaura.hud_id then return end
	if not closest then
		core.localplayer:hud_change(killaura.hud_id, "text", "")
		return
	end
	local name = get_target_name(closest)
	if #name > 16 then name = name:sub(1, 14) .. ".." end
	local hp = closest:get_hp() or 0
	local props = closest:get_properties()
	local max_hp = (props and props.hp_max) or 20
	local dist = vector.distance(core.localplayer:get_pos(), closest:get_pos())
	local hp_bar = make_hp_bar(hp, max_hp)
	local color = get_hp_color(hp, max_hp)
	local text = string.format("► %s   ♥ %d/%d   %s   %.1fm", name, hp, max_hp, hp_bar, dist)
	core.localplayer:hud_change(killaura.hud_id, "number", color)
	core.localplayer:hud_change(killaura.hud_id, "text", text)
end

local function hit_objects(radius)
	local pl = core.localplayer
	local lp = pl:get_pos()
	local closest_obj = nil
	local closest_dist = math.huge
	for _, obj in pairs(core.get_objects_inside_radius(lp, radius)) do
		if should_attack(obj) then
			local dist = vector.distance(lp, obj:get_pos())
			if dist < closest_dist then
				closest_obj = obj
				closest_dist = dist
			end
		end
	end
	if closest_obj then
		killaura.queue_punches(closest_obj, 8)
	end
	return closest_obj
end

ws.rg("Killaura", {
	category = "Combat",
	setting = "killaura",
	description = "Auto-attack nearby entities",
	on_start = function(self)
		if not core.localplayer then return false end
		killaura.hud_id = core.localplayer:hud_add({
			type = "text",
			position = {x = 1, y = 0.28},
			alignment = {x = -1, y = 0},
			offset = {x = -10, y = 0},
			number = 0xFFCCCCCC,
			scale = {x = 1.5, y = 1.5},
		})
		return true
	end,
	on_step = function(self, dtime)
		local closest = hit_objects(killaura.get("range"))
		update_target_hud(closest)
	end,
	on_stop = function(self)
		if killaura.hud_id then
			core.localplayer:hud_remove(killaura.hud_id)
			killaura.hud_id = nil
		end
	end,
	cheat_settings = {
		range = { type = "number", default = 10, min = 1, max = 30 },
		attack_mobs = { type = "bool", default = false },
	},
})

--
-- PatrolGuard bot (deferred until all mods loaded so sbots/poi exist)
--

core.register_on_mods_loaded(function()
	if not sbots or not poi then return end

	sbots.register_bot("PatrolGuard", {
		description = "Patrol area and engage targets using killaura",
		movement = "walk",
		stand_waiting = true,
		moving_target = true,
		landing_distance = 3,
		find_pos = function(self, pos)
			local range = tonumber(core.settings:get("patrolguard.scan_range")) or 50
			local closest = nil
			local closest_dist = math.huge
			for _, obj in pairs(core.get_objects_inside_radius(pos, range)) do
				if should_attack(obj) then
					local d = vector.distance(pos, obj:get_pos())
					if d < closest_dist then
						closest = obj
						closest_dist = d
					end
				end
			end
			if closest then return closest:get_pos() end

			local wp_str = core.settings:get("patrolguard.patrol_waypoints") or ""
			local wps = {}
			for name in wp_str:gmatch("[^,]+") do
				local t = name:match("^%s*(.-)%s*$")
				if t and #t > 0 then table.insert(wps, t) end
			end
			if #wps > 0 then
				if not self._patrol_idx then self._patrol_idx = 0 end
				self._patrol_idx = self._patrol_idx + 1
				if self._patrol_idx > #wps then self._patrol_idx = 1 end
				local wp_pos = poi.get_waypoint(wps[self._patrol_idx])
				if wp_pos then return wp_pos end
			end
			local radius = tonumber(core.settings:get("patrolguard.patrol_radius")) or 50
			local origin = self.orig_pos or pos
			return {
				x = origin.x + math.random(-radius, radius),
				y = origin.y,
				z = origin.z + math.random(-radius, radius),
			}
		end,
		update_pos = function(self, pos)
			local range = tonumber(core.settings:get("patrolguard.scan_range")) or 50
			local closest = nil
			local closest_dist = math.huge
			for _, obj in pairs(core.get_objects_inside_radius(pos, range)) do
				if should_attack(obj) then
					local d = vector.distance(pos, obj:get_pos())
					if d < closest_dist then
						closest = obj
						closest_dist = d
					end
				end
			end
			return closest and closest:get_pos() or self.target_pos
		end,
		do_pos = function(self, pos)
			local target = nil
			local closest = math.huge
			for _, obj in pairs(core.get_objects_inside_radius(pos, 5)) do
				if should_attack(obj) then
					local d = vector.distance(pos, obj:get_pos())
					if d < closest then
						closest = d
						target = obj
					end
				end
			end
			if target then
				killaura.queue_punches(target, 8)
				return false
			end
			return true
		end,
		cheat_settings = {
			scan_range = { type = "number", default = 50, min = 10, max = 200 },
			patrol_waypoints = { type = "string", default = "" },
			patrol_radius = { type = "number", default = 50, min = 10, max = 500 },
		},
	})
end)
