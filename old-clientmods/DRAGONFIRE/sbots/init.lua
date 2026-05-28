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
	local tn = name
	registered_bots[tn] = setmetatable(def, bot_class_meta)

	ws.rg(name, {
		category = "Bots",
		setting = tn,
		on_step = function(self, dtime)
			local lp = minetest.localplayer:get_pos()
			if self.stage == 0 then
				self.target_pos = self:find_pos(lp)
				if self.target_pos then
					self.stage = 1
				elseif self.orig_pos and vector.distance(lp, self.orig_pos) > self.landing_distance then
					minetest.settings:set_bool("continuous_forward", false)
				else
					minetest.settings:set_bool("continuous_forward", false)
					if not self.stand_waiting then
						minetest.log("nothing found!")
						minetest.settings:set_bool(tn, false)
					end
				end
			elseif self.stage == 1 then
				if not self.target_pos then return end
				ws.aim(self.target_pos)
				minetest.settings:set_bool("continuous_forward", true)
				if vector.distance(lp, self.target_pos) < self.landing_distance then
					self.stage = 2
				end
			elseif self.stage == 2 then
				minetest.settings:set_bool("continuous_forward", false)
				if self:do_pos(lp) then
					self.stage = 0
				end
			else
				self.stage = 0
			end
			if self.moving_target then
				self.target_pos = self:update_pos(lp)
			end
			self:do_step(dtime)
		end,
		on_start = function(self)
			-- Co-bot check: only one bot active unless allow_cobot is set
			for n, bot in pairs(registered_bots) do
				if n ~= tn and core.settings:get_bool(n) and not self.allow_cobot then
					ws.dcm("Another bot is active. Disable it first, or enable allow_cobot on this bot.")
					return true
				end
			end
			self.active = true
			self.orig_pos = minetest.localplayer:get_pos()
			self.target_pos = nil
			self.stage = 0
			minetest.settings:set_bool("pitch_move", true)
			minetest.settings:set_bool("free_move", true)
			if self.on_activate then
				return self.on_activate(self)
			end
		end,
		on_stop = function(self)
			self.active = false
			minetest.settings:set_bool("continuous_forward", false)
			minetest.settings:set_bool("pitch_move", false)
			if self.on_deactivate then
				return self.on_deactivate(self)
			end
		end,
		daughters = def.daughters,
		delay = def.delay,
		cheat_settings = {
			allow_cobot = { type = "bool", default = false },
		},
	})
end

if nlist then
	sbots.register_bot("listDigBot", {
		find_pos = function(self, pos)
			local nds = minetest.find_nodes_near(pos, 60, nlist.get(nlist.selected))
			if not nds or #nds == 0 then return end
			table.sort(nds, function(a, b) return vector.distance(pos, a) < vector.distance(pos, b) end)
			return nds[1]
		end,
		do_pos = function(self, pos)
			local nn = minetest.find_nodes_near(pos, 1, nlist.get(nlist.selected), true)
			if not nn or #nn == 0 then return true end
			for _, v in pairs(nn) do ws.dig(v) end
		end,
	})
end
