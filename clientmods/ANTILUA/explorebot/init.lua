local function make_ring(step, r)
	local cells = {}
	if r == 0 then
		return {{0, 0}}
	end
	local s = r * step
	for i = -r, r do
		cells[#cells + 1] = {i * step, -s}
	end
	for i = -r + 1, r do
		cells[#cells + 1] = {s, i * step}
	end
	for i = r - 1, -r, -1 do
		cells[#cells + 1] = {i * step, s}
	end
	for i = r - 1, -r + 1, -1 do
		cells[#cells + 1] = {-s, i * step}
	end
	return cells
end

local function find_ground_y(x, z, top_y, bottom_y)
	local ray = core.raycast(
		{x = x, y = top_y, z = z},
		{x = x, y = bottom_y, z = z},
		false, true)
	for point in ray do
		if point.type == "node" then
			local nd = core.get_node_or_nil(point.under)
			if nd and nd.name ~= "air" and nd.name ~= "ignore" then
				return point.under.y
			end
		end
	end
end

local function is_explored(x, z)
	if core.al_bigmap:has_block(x, z) then
		return true
	end
	return core.al_bigmap:get_pixel(x, z) ~= nil
end

local function is_solid(pos)
	local nd = core.get_node_or_nil(pos)
	if not nd then
		return false
	end
	return nd.name ~= "air" and nd.name ~= "ignore"
end

sbots.register_bot("ExploreBot", {
	description = "Fly an outward spiral and fill in bigmap blanks",
	movement = "walk",
	landing_distance = 6,
	stand_waiting = true,
	find_pos = function(self, pos)
		if not self._origin then
			self._origin_wait = (self._origin_wait or 0) + (self._dtime or 0.2)
			if vector.length(pos) > 1 or self._origin_wait > 3 then
				self._origin = vector.round(pos)
				self._ring = nil
				self._ring_idx = nil
				self._ring_cells = nil
				self._failed = {}
				local gy = find_ground_y(pos.x, pos.z, pos.y - 1, pos.y - 300)
				self._cruise_y = (gy or pos.y) + self._hover
			end
		end
		if not self._origin then
			return nil
		end
		local max_ring = self._max_ring
		if not self._ring then
			self._ring = 0
			self._ring_cells = make_ring(self._step, 0)
			self._ring_idx = 1
		end
		while self._ring <= max_ring do
			local cells = self._ring_cells
			for i = self._ring_idx, #cells do
				local cell = cells[i]
				local cx = math.floor(self._origin.x) + cell[1]
				local cz = math.floor(self._origin.z) + cell[2]
				local key = cx .. "," .. cz
				if not self._failed[key] and not is_explored(cx, cz) then
					self._ring_idx = i + 1
					local gy = find_ground_y(cx, cz,
						math.max(pos.y, 0) + 256, -64)
					local ty = gy and (gy + self._hover)
						or (self._cruise_y or pos.y)
					return {x = cx, y = ty, z = cz}
				end
			end
			self._ring = self._ring + 1
			self._ring_idx = 1
			if self._ring <= max_ring then
				self._ring_cells = make_ring(self._step, self._ring)
			else
				self._ring_cells = nil
			end
		end
		if not self._complete_notified then
			self._complete_notified = true
			ws.notify("ExploreBot: exploration complete ("
				.. self._max_radius .. "m radius)", ws.NOTIFY_SUCCESS)
			core.settings:set_bool("explorebot", false)
		end
		return nil
	end,
	do_pos = function(self, pos)
		local t = self.target_pos
		if not t then
			return true
		end
		local cx = math.floor(t.x)
		local cz = math.floor(t.z)
		local key = cx .. "," .. cz
		if is_explored(cx, cz) then
			self._failed[key] = nil
			self._wait_t = 0
			return true
		end
		self._wait_t = (self._wait_t or 0) + (self._dtime or 0.2)
		if self._wait_t > self._capture_timeout then
			self._failed[key] = true
			self._wait_t = 0
			ws.notify("ExploreBot: no map data at " .. key .. ", skipping",
				ws.NOTIFY_WARNING)
			return true
		end
		sbots.set_status("ExploreBot", "waiting for map data")
		return false
	end,
	do_step = function(self, dtime)
		self._dtime = dtime
		local lp = core.localplayer:get_pos()
		if not lp then
			return
		end
		local phys = core.localplayer:get_physics_override()
		if phys.speed ~= self._speed then
			core.localplayer:set_physics_override({speed = self._speed})
		end
		local gy = find_ground_y(lp.x, lp.z, lp.y - 1, lp.y - 300)
		if gy then
			local want = gy + self._hover
			if math.abs(lp.y - want) > 1 then
				local step = lp.y < want and 1 or -1
				core.localplayer:set_pos({x = lp.x, y = lp.y + step, z = lp.z})
				lp = core.localplayer:get_pos()
			end
		end
		if self.target_pos and lp then
			local d = vector.direction(lp, self.target_pos)
			local len = math.sqrt(d.x * d.x + d.z * d.z)
			if len > 0 then
				local ahead = vector.add(lp,
					{x = d.x / len, y = 0, z = d.z / len})
				if is_solid(ahead) then
					local up = vector.add(ahead, {x = 0, y = 1, z = 0})
					if not is_solid(up) then
						core.localplayer:set_pos(up)
					end
				end
			end
		end
		sbots.set_status("ExploreBot", "ring " .. (self._ring or 0)
			.. " of " .. (self._max_ring or 0))
	end,
	on_activate = function(self)
		if not core.al_bigmap or not core.al_bigmap.has_block
				or not core.al_bigmap.get_pixel then
			ws.notify("ExploreBot: bigmap API unavailable", ws.NOTIFY_ERROR)
			return false
		end
		if not core.settings:get_bool("enable_minimap", true) then
			ws.notify("ExploreBot: enable_minimap is off, bigmap cannot capture",
				ws.NOTIFY_ERROR)
			return false
		end
		self._prev_save = core.settings:get_bool("enable_minimap_saving", true)
		if not self._prev_save then
			core.settings:set_bool("enable_minimap_saving", true)
		end
		self._step = tonumber(core.settings:get("explorebot.step")) or 16
		self._max_radius = tonumber(core.settings:get("explorebot.max_radius")) or 300
		self._hover = tonumber(core.settings:get("explorebot.hover_height")) or 20
		self._capture_timeout = tonumber(core.settings:get("explorebot.capture_timeout")) or 5
		local speed = tonumber(core.settings:get("explorebot.speed")) or 2.0
		self._speed = speed
		self._max_ring = math.floor(self._max_radius / self._step)
		self._ring = nil
		self._ring_idx = nil
		self._ring_cells = nil
		self._failed = {}
		self._wait_t = 0
		self._complete_notified = false
		self._origin = nil
		self._origin_wait = 0
		self._cruise_y = nil
		self._prev_physics = core.localplayer:get_physics_override()
		core.localplayer:set_physics_override({speed = speed})
	end,
	on_deactivate = function(self)
		if self._prev_save ~= nil then
			core.settings:set_bool("enable_minimap_saving", self._prev_save)
			self._prev_save = nil
		end
		if self._prev_physics then
			core.localplayer:set_physics_override(self._prev_physics)
			self._prev_physics = nil
		end
	end,
	cheat_settings = {
		step = {type = "number", default = 16, min = 8, max = 128},
		max_radius = {type = "number", default = 300, min = 32, max = 5000},
		hover_height = {type = "number", default = 20, min = 2, max = 200},
		speed = {type = "number", default = 2.0, min = 0.1, max = 10},
		capture_timeout = {type = "number", default = 5, min = 1, max = 30},
	},
})
