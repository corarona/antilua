local function dump_inv(pos)
	local n = core.find_node_near(pos, 4, {"air"}, true)
	if n then
		ws.place(n, "mcl_chests:chest")
		local plinv = core.get_inventory("current_player")
		for i, v in pairs(plinv.main) do
			if i > 9 then
				local act = InventoryAction("move")
				act:from("current_player", "main", i)
				act:to("nodemeta:" .. n.x .. "," .. n.y .. "," .. n.z, "main", i)
				act:apply()
			end
		end
	end
end

local function check_obslist(obj)
	local p = obj:get_properties()
	for _, vv in pairs(nlist.get("obsbot")) do
		if p.mesh == vv then
			return true
		end
	end
end

local function get_close_objects(pos, radius, check_func)
	local obs = core.get_objects_inside_radius(pos, radius)
	local robs = {}
	for _, v in pairs(obs) do
		if check_func and check_func(v) then
			table.insert(robs, v)
		end
	end
	table.sort(robs, function(a, b)
		return vector.distance(pos, a:get_pos()) < vector.distance(pos, b:get_pos())
	end)
	return robs
end

local function find_close_safespot(pos, epos)
	local nds = core.find_nodes_in_area(pos:offset(-5, -6, -5), pos:offset(5, 10, 5), {"air"})
	table.sort(nds, function(a, b) return vector.distance(a, pos) < vector.distance(b, pos) end)
	for _, v in ipairs(nds) do
		if vector.distance(v, epos) > 5 then
			return v:offset(0, -1, 0)
		end
	end
end

ws.rg("SafeAura", { category = "Combat", setting = "safeaura",
	on_step = function(self)
		local range = tonumber(core.settings:get(self.setting .. ".range")) or 5
		local pos = core.localplayer:get_pos()
		local obs = get_close_objects(pos, range, function(obj)
			return obj and obj:is_player() and not obj:is_local_player()
		end)
		if #obs == 0 then return end
		table.shuffle(obs)
		local sp = find_close_safespot(pos, obs[1]:get_pos())
		if sp then
			core.localplayer:set_pos(sp)
		end
	end,
	cheat_settings = {
		range = { type = "number", default = 5, min = 1, max = 30 },
	},
})

ws.rg("SelKillaura", { category = "Combat", setting = "selkillaura",
	on_step = function(self)
		local range = tonumber(core.settings:get(self.setting .. ".range")) or 4
		local pos = core.localplayer:get_pos()
		for _, obj in pairs(get_close_objects(pos, range, check_obslist)) do
			killaura.punch_object(obj)
		end
	end,
	cheat_settings = {
		range = { type = "number", default = 4, min = 1, max = 20 },
	},
})

ws.rg("EvadeWither", { category = "Combat", setting = "evade_wither",
	on_step = function(self)
		local range = tonumber(core.settings:get(self.setting .. ".range")) or 3.5
		local pos = core.localplayer:get_pos()
		for _, obj in pairs(core.get_objects_inside_radius(pos, range)) do
			local p = obj:get_properties()
			if p.textures[1]:find("mobs_mc_wither_projectile.png") then
				local nn = core.find_nodes_in_area(pos:offset(-4, -4, -4), pos:offset(4, 4, 4), {"air"})
				if nn and #nn > 0 then
					table.sort(nn, function(a, b) return vector.distance(pos, a) > vector.distance(pos, b) end)
					core.localplayer:set_pos(nn[1]:offset(0, -1, 0))
				end
			end
		end
	end,
	cheat_settings = {
		range = { type = "number", default = 3.5, min = 0.5, max = 20 },
	},
})

local mobsbot = {
	moving_target = true,
	stand_waiting = true,
	landing_distance = 4,
	find_pos = function(self, pos)
		if self._target and self._target.get_pos then
			return self._target:get_pos()
		else
			self._target = nil
		end
		local obs = get_close_objects(core.localplayer:get_pos(), 128, self.check_object)
		if obs[1] then
			self._target = obs[1]
			return obs[1]:get_pos()
		end
		return vector.new(0, -72, 0)
	end,
	update_pos = function(self, pos)
		if self._target and self._target.get_pos then
			return self._target:get_pos()
		end
		return self:find_pos(pos)
	end,
	do_pos = function(self, pos)
		for _, obj in pairs(get_close_objects(pos, 9, self.check_object)) do
			killaura.punch_object(obj)
		end
		self._target = nil
		self.target_pos = nil
		return true
	end,
	do_step = function(self, dtime)
		local pos = core.localplayer:get_pos()
		for _, v in pairs(get_close_objects(pos, 9, self.check_object)) do
			local p = v:get_pos()
			if vector.distance(p, pos) <= 5 then
				local sp = find_close_safespot(pos, p)
				if sp then end
			end
		end
		if not self._target or not self._target.get_pos or not self._target:get_pos() then
			self._target = nil
			self._target_pos = nil
			self.stage = 0
		end
	end,
	check_object = function(obj)
		local p = obj and obj:get_properties()
		local r = obj and obj:get_rotation()
		return p and r and r.z == 0 and (p.mesh:find("mobs_mc") or p.mesh:find("extra_mobs")) and obj:get_hp() > 0
	end,
}

local crystalbot = table.copy(mobsbot)
local plbot = table.copy(mobsbot)
local obsbot = table.copy(mobsbot)
local hmobsbot = table.copy(mobsbot)
local itembot = table.copy(mobsbot)
obsbot.check_object = check_obslist

function hmobsbot.check_object(obj)
	local p = obj:get_properties()
	return p.mesh:find("mobs_mc") and obj:get_hp() > 0
end

function crystalbot.check_object(obj)
	local p = obj:get_properties()
	return p and p.mesh == "mcl_end_crystal.b3d"
end

function itembot.check_object(obj)
	return obj:get_name() == "__builtin:item"
end

function plbot.check_object(obj)
	return obj:is_player() and not obj:is_local_player() and obj:get_hp() > 0
end

plbot.landing_distance = 9

function itembot.do_pos(self, pos)
	for _, v in pairs(get_close_objects(pos, 4.5, self.check_object)) do
		v:punch()
	end
	if not (self._target and self._target.get_pos and self._target:get_pos()) then
		self._target = nil
		self.target_pos = nil
		self.stage = 0
		return true
	end
	return false
end

itembot.landing_distance = 1

sbots.register_bot("ObsBot", obsbot)
sbots.register_bot("PlBot", plbot)
sbots.register_bot("CrystalBot", crystalbot)
sbots.register_bot("MobsBot", mobsbot)
sbots.register_bot("HostileMobs", hmobsbot)
sbots.register_bot("ItemBot", itembot)
