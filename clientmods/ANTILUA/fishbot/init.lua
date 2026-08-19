-- FishBot: automated fishing for Mineclonia / VoxeLibre.
-- Uses a state machine to cast, wait for a bite, and reel in.
-- Bites are detected via the bobber's bubble particles (VoxeLibre) or
-- bobber movement (Mineclonia).

local BUBBLE_WINDOW = 1.0
local BUBBLE_RADIUS = 2.0
local SETTLE_TIME = 0.4
local CAST_THROTTLE = 1.0

local WATER_NODES = {
	["mcl_core:water_source"] = true,
	["mcl_core:river_water_source"] = true,
}

-- Last seen bubble particle: VoxeLibre sprays these at the bobber while a
-- fish is biting.
local bubble = { pos = nil, time = 0 }

if core.register_on_spawn_particle then
	core.register_on_spawn_particle(function(particle)
		if particle and particle.texture and particle.texture:find("bubble") then
			bubble.pos = particle.pos
			bubble.time = core.get_us_time() / 1000000
		end
	end)
end

local function get_bobber_pos(range)
	local lp = core.localplayer:get_pos()
	local obs = core.get_objects_inside_radius(lp, range)
	for _, v in ipairs(obs) do
		local props = v:get_properties()
		local tex = props and props.textures
		local txt = (tex and tex[1]) or ""
		if txt:lower():find("bobber") then
			return v:get_pos()
		end
	end
	return false
end

local function bubble_near(bpos, now)
	if not bubble.pos or now - bubble.time > BUBBLE_WINDOW then
		return false
	end
	return vector.distance(bubble.pos, bpos) <= BUBBLE_RADIUS
end

local function reel_in()
	core.after(0.1, function()
		core.interact("activate", {type="nothing"})
	end)
end

sbots.register_bot("FishBot", {
	description = "Bot that fishes automatically",
	movement = "stationary",
	find_pos = function(self, pos)
		return nil
	end,
	do_pos = function(self, pos)
		return true
	end,
	do_step = function(self, dtime)
		self.state = self.state or 0
		self.obpos = self.obpos or false
		self.settle_t = self.settle_t or 0
		self.cast_t = self.cast_t or 0
		local now = core.get_us_time() / 1000000

		local rod = "mcl_fishing:fishing_rod_enchanted"
		if not ws.switch_to_item(rod) then
			ws.switch_to_item("mcl_fishing:fishing_rod")
		end

		local bobber_range = tonumber(core.settings:get("fishbot.bobber_range")) or 10
		local bpos = get_bobber_pos(bobber_range)

		-- No bobber: cast the rod (throttled).
		if not bpos then
			self.obpos = false
			self.settle_t = 0
			if now - self.cast_t >= CAST_THROTTLE then
				core.interact("activate", {type="nothing"})
				self.cast_t = now
				sbots.set_status("FishBot", "casting")
			else
				sbots.set_status("FishBot", "waiting to cast")
			end
			self.state = 1
			return
		end

		if self.state == 1 then
			-- Bobber present: wait for it to settle (flying bobber still moving).
			if self.obpos then
				if vector.distance(bpos, self.obpos) < 0.1 then
					self.settle_t = self.settle_t + dtime
				else
					self.settle_t = 0
				end
			end
			self.obpos = bpos
			if self.settle_t >= SETTLE_TIME then
				self.settle_t = 0
				self.state = 2
			end
			sbots.set_status("FishBot", "waiting for bobber to settle")
			return
		elseif self.state == 2 then
			-- Watching for a bite: bubble particles near the bobber (VoxeLibre),
			-- or bobber movement (Mineclonia).
			if bubble_near(bpos, now)
					or (self.obpos and vector.distance(bpos, self.obpos) > 0.3) then
				sbots.set_status("FishBot", "bite! reeling")
				ws.notify("FishBot: bite!", ws.NOTIFY_SUCCESS, {chat = false})
				reel_in()
				self.state = 3
				self.obpos = bpos
				return
			end
			-- Recast if the bobber sits on land (no water below).
			local nd = core.get_node_or_nil(vector.add(bpos, vector.new(0, -0.5, 0)))
			if nd and not WATER_NODES[nd.name] then
				reel_in()
				self.state = 3
				self.obpos = bpos
				return
			end
			self.obpos = bpos
			sbots.set_status("FishBot", "waiting for bite")
			return
		elseif self.state == 3 then
			-- Cooldown: wait until the bobber is gone after reeling, then recast.
			sbots.set_status("FishBot", "cooldown")
			if not get_bobber_pos(bobber_range) then
				self.obpos = false
				ws.notify("FishBot: reeling in", ws.NOTIFY_INFO, {chat = false})
				self.state = 1
			end
			return
		end

		-- Unknown state: reset.
		self.state = 1
	end,
	on_activate = function(self)
		if not core.get_item_def("mcl_fishing:fishing_rod")
				and not core.get_item_def("mcl_fishing:fishing_rod_enchanted") then
			ws.notify("FishBot needs a fishing rod game (mineclonia/voxelibre)", ws.NOTIFY_ERROR)
			return true
		end
		if not ws.switch_to_item("mcl_fishing:fishing_rod_enchanted")
				and not ws.switch_to_item("mcl_fishing:fishing_rod") then
			ws.notify("Put a fishing rod in the hotbar", ws.NOTIFY_WARNING)
			return true
		end
		self.state = 0
		self.obpos = false
		self.settle_t = 0
		self.cast_t = 0
	end,
	on_deactivate = function(self)
		self.state = 0
	end,
	stand_waiting = true,
	delay = 0.2,
	daughters = {"autodump", "autoeject", "lockview"},
	cheat_settings = {
		bobber_range = { type = "number", default = 10, min = 1, max = 50 },
	},
})
