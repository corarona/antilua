sbots = {}

local bot_class = {
	find_pos = function(self, pos) end,
	do_pos = function(self, pos) end,
	do_step = function(self, dtime) end,
	update_pos = function(self, pos) return self:find_pos(self, pos) end,
	active = false,
	landing_distance = 1,
	moving_target = false,
	stand_waiting = false,
	target_pos = nil,
}

local bot_class_meta = { __index = bot_class }

local registered_bots = {}

function sbots.register_bot(name, def)
	for k, v in pairs(bot_class) do
		if def[k] == nil then
			def[k] = v
		end
	end
	local tn = name

	local bot_settings = def.cheat_settings or {}
	bot_settings.allow_cobot = { type = "bool", default = false }

	registered_bots[tn] = def

	ws.rg(name, {
		category = "Bots",
		setting = tn:lower(),
		on_step = function(self, dtime)
			local bot = registered_bots[tn]
			if not bot then return end
			local lp = core.localplayer:get_pos()
			if bot.stage == 0 then
				bot.target_pos = bot:find_pos(lp)
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
				ws.aim(bot.target_pos)
				core.settings:set_bool("continuous_forward", true)
				if vector.distance(lp, bot.target_pos) < bot.landing_distance then
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
			bot.active = true
			bot.orig_pos = core.localplayer:get_pos()
			bot.target_pos = nil
			bot.stage = 0
			core.settings:set_bool("pitch_move", true)
			core.settings:set_bool("free_move", true)
			if bot.on_activate then
				return bot.on_activate(bot)
			end
		end,
		on_stop = function(self)
			local bot = registered_bots[tn]
			if not bot then return end
			bot.active = false
			core.settings:set_bool("continuous_forward", false)
			core.settings:set_bool("pitch_move", false)
			if bot.on_deactivate then
				return bot.on_deactivate(bot)
			end
		end,
		daughters = def.daughters,
		delay = def.delay,
		cheat_settings = bot_settings,
	})
end

if nlist then
	sbots.register_bot("listDigBot", {
		find_pos = function(self, pos)
			local nds = core.find_nodes_near(pos, 60, nlist.get(nlist.selected))
			if not nds or #nds == 0 then return end
			table.sort(nds, function(a, b) return vector.distance(pos, a) < vector.distance(pos, b) end)
			return nds[1]
		end,
		do_pos = function(self, pos)
			local nn = core.find_nodes_near(pos, 1, nlist.get(nlist.selected), true)
			if not nn or #nn == 0 then return true end
			for _, v in pairs(nn) do ws.dig(v) end
		end,
	})
end
