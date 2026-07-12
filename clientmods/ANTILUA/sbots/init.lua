sbots = {}

local death_pos = nil  -- single death position for the local player

local movement_strategies = {}

movement_strategies.walk = {
	requires_movement = true,
	on_step = function(bot, lp)
		ws.aim(bot.target_pos)
		core.settings:set_bool("continuous_forward", true)
	end,
}

movement_strategies.teleport = {
	requires_movement = true,
	on_step = function(bot, lp)
		ws.aim(bot.target_pos)
		core.settings:set_bool("continuous_forward", false)
		if rhythmtp and not rhythmtp.is_moving() then
			rhythmtp.go_to(bot.target_pos)
		end
	end,
}

movement_strategies.stationary = {
	requires_movement = false,
	on_step = function(bot, lp)
		bot.stage = 2
	end,
}

movement_strategies.server_tp = {
	requires_movement = true,
	on_step = function(bot, lp)
		ws.aim(bot.target_pos)
		core.settings:set_bool("continuous_forward", false)
		local now = core.get_us_time() / 1000000
		if not bot._tp_cooldown or now - bot._tp_cooldown > 0.3 then
			bot._tp_cooldown = now
			local p = bot.target_pos
			core.send_chat_message(
				"/teleport " .. math.floor(p.x) .. "," .. math.floor(p.y) .. "," .. math.floor(p.z))
		end
	end,
}

movement_strategies.client_tp = {
	requires_movement = true,
	on_step = function(bot, lp)
		ws.aim(bot.target_pos)
		core.settings:set_bool("continuous_forward", false)
		core.localplayer:set_pos(bot.target_pos)
		bot.stage = 2
	end,
}

movement_strategies.sprint = {
	requires_movement = true,
	on_step = function(bot, lp)
		ws.aim(bot.target_pos)
		core.settings:set_bool("continuous_forward", true)
		core.set_keypress("special1", true)
	end,
}

movement_strategies.patrol = {
	requires_movement = true,
	on_find = function(bot, lp)
		if bot._patrol_waypoints == nil then
			bot._patrol_idx = 0
			bot._patrol_waypoints = {}
			local wp_str = bot._setting and core.settings:get(bot._setting .. ".patrol_waypoints") or ""
			for name in wp_str:gmatch("[^,]+") do
				local t = name:match("^%s*(.-)%s*$")
				if t and #t > 0 then
					table.insert(bot._patrol_waypoints, t)
				end
			end
		end
		if #bot._patrol_waypoints == 0 then
			ws.notify("No patrol waypoints configured.", ws.NOTIFY_WARNING)
			return
		end
		bot._patrol_idx = bot._patrol_idx + 1
		if bot._patrol_idx > #bot._patrol_waypoints then
			local cycle = core.settings:get_bool(bot._setting .. ".patrol_cycle")
			if cycle ~= false then
				bot._patrol_idx = 1
			else
				core.settings:set_bool(bot._setting, false)
				return
			end
		end
		local wp_name = bot._patrol_waypoints[bot._patrol_idx]
		local wp_pos = poi and poi.get_waypoint(wp_name)
		if not wp_pos then
			ws.notify("Patrol waypoint '" .. wp_name .. "' not found.", ws.NOTIFY_WARNING)
			return
		end
		return wp_pos
	end,
	on_step = function(bot, lp)
		ws.aim(bot.target_pos)
		core.settings:set_bool("continuous_forward", true)
	end,
}

local bot_class = {
	find_pos = function(self, pos) end,
	do_pos = function(self, pos) end,
	do_step = function(self, dtime) end,
	update_pos = function(self, pos) return self:find_pos(pos) end,
	active = false,
	landing_distance = 1,
	moving_target = false,
	stand_waiting = false,
	target_pos = nil,
	movement = "walk",
}

local registered_bots = {}

-- Find the nearest node matching a list of names within range, sorted by distance.
-- Optional filter(pos): return true to accept, false to skip.
function sbots.find_nearest(pos, node_names, range, filter)
	local nds = core.find_nodes_near(pos, range, node_names, true)
	if not nds or #nds == 0 then return end
	table.sort(nds, function(a, b) return vector.distance(pos, a) < vector.distance(pos, b) end)
	if filter then
		for _, p in ipairs(nds) do
			if filter(p) then return p end
		end
		return
	end
	return nds[1]
end

function sbots.register_bot(name, def)
	for k, v in pairs(bot_class) do
		if def[k] == nil then
			def[k] = v
		end
	end
	local tn = name

	local bot_settings = def.cheat_settings or {}
	bot_settings.allow_cobot = { type = "bool", default = false }
	bot_settings.movement = {
		type = "enum",
		default = def.movement or "walk",
		values = {"walk", "teleport", "server_tp", "client_tp", "stationary", "sprint", "patrol"},
	}
	bot_settings.patrol_waypoints = { type = "string", default = "" }
	bot_settings.patrol_cycle = { type = "bool", default = true }
	bot_settings.return_after_death = { type = "bool", default = true }

	def._setting = tn:lower()
	registered_bots[tn] = def

	ws.rg(name, {
		category = "Bots",
		setting = tn:lower(),
		description = def.description,
		on_step = function(_, dtime)
			local bot = registered_bots[tn]
			if not bot then return end
			local strategy = movement_strategies[bot.movement] or movement_strategies.walk
			local lp = core.localplayer:get_pos()

			-- Death return: if pending, set target and check arrival
			if not bot._return_target and bot.active and
					core.settings:get_bool(bot._setting .. ".return_after_death", true) then
				if death_pos and vector.distance(lp, death_pos) >= 3 then
					bot._return_target = death_pos
				elseif death_pos then
					death_pos = nil
				end
			end
			if bot._return_target and vector.distance(lp, bot._return_target) < 3 then
				bot._return_target = nil
				death_pos = nil
			end

			if bot.stage == 0 then
				if bot._return_target then
					bot.target_pos = bot._return_target
				elseif strategy.on_find then
					bot.target_pos = strategy.on_find(bot, lp)
				else
					bot.target_pos = bot:find_pos(lp)
				end
				if bot.target_pos then
					bot.stage = 1
				elseif bot.orig_pos and vector.distance(lp, bot.orig_pos) > bot.landing_distance then
					core.settings:set_bool("continuous_forward", false)
				else
					core.settings:set_bool("continuous_forward", false)
					if not bot.stand_waiting then
						core.log("nothing found!")
						core.settings:set_bool(tn, false)
					end
				end
			elseif bot.stage == 1 then
				if not bot.target_pos then return end
				if bot._return_target and vector.distance(lp, bot._return_target) < 3 then
					bot._return_target = nil
					death_pos = nil
					bot.stage = 0
					return
				end
				strategy.on_step(bot, lp)
				if strategy.requires_movement and
						vector.distance(lp, bot.target_pos) < bot.landing_distance then
					bot.stage = 2
				end
			elseif bot.stage == 2 then
				core.settings:set_bool("continuous_forward", false)
				if bot:do_pos(lp) then
					bot.stage = 0
				end
			else
				bot.stage = 0
			end
			if bot.moving_target then
				bot.target_pos = bot:update_pos(lp)
			end
			bot:do_step(dtime)
		end,
		on_start = function(self)
			local bot = registered_bots[tn]
			if not bot then return end
			for n, _ in pairs(registered_bots) do
				if n ~= tn and core.settings:get_bool(n) and not bot.allow_cobot then
					ws.notify("Another bot is active.", ws.NOTIFY_WARNING)
					return true
				end
			end
			local mov_val = core.settings:get(tn:lower() .. ".movement")
			if mov_val and movement_strategies[mov_val] then
				bot.movement = mov_val
			end
			local strategy = movement_strategies[bot.movement] or movement_strategies.walk
			bot.active = true
			bot.orig_pos = core.localplayer:get_pos()
			bot.target_pos = nil
			bot.stage = 0
			bot._patrol_waypoints = nil
			bot._patrol_idx = nil
			if strategy.requires_movement then
				bot._saved_pitch_move = core.settings:get_bool("pitch_move")
				bot._saved_free_move = core.settings:get_bool("free_move")
				core.settings:set_bool("pitch_move", true)
				core.settings:set_bool("free_move", true)
			end
			if bot.on_activate then
				return bot.on_activate(bot)
			end
		end,
		on_stop = function(self)
			local bot = registered_bots[tn]
			if not bot then return end
			local strategy = movement_strategies[bot.movement] or movement_strategies.walk
			bot.active = false
			core.settings:set_bool("continuous_forward", false)
			if strategy.requires_movement then
				core.settings:set_bool("pitch_move", bot._saved_pitch_move ~= nil and bot._saved_pitch_move or false)
				core.settings:set_bool("free_move", bot._saved_free_move ~= nil and bot._saved_free_move or false)
			end
			if bot.on_deactivate then
				return bot.on_deactivate(bot)
			end
		end,
		daughters = def.daughters,
		delay = def.delay,
		cheat_settings = bot_settings,
	})
end

core.register_on_death(function()
	if not core.localplayer then return end
	local pos = vector.round(core.localplayer:get_pos())
	for _, bot in pairs(registered_bots) do
		if bot.active and core.settings:get_bool(bot._setting .. ".return_after_death", true) then
			death_pos = pos
			break
		end
	end
end)

if nlist then
	sbots.register_bot("listDigBot", {
		description = "Bot that digs nodes from a list",
		find_pos = function(self, pos)
			return sbots.find_nearest(pos, nlist.get(nlist.selected), 60)
		end,
		do_pos = function(self, pos)
			local nn = core.find_nodes_near(pos, ws.range or 4, nlist.get(nlist.selected), true)
			return not nn or #nn == 0
		end,
		do_step = function(self, dtime)
			local pos = core.localplayer:get_pos()
			if not pos then return end
			local nn = core.find_nodes_near(pos, ws.range or 4, nlist.get(nlist.selected), true)
			if not nn then return end
			local npt = ws.get_nodes_per_tick()
			for i, v in ipairs(nn) do
				if i > npt then break end
				ws.dig(v)
			end
		end,
	})
end
