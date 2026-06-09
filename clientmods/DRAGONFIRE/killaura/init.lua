killaura = {
	hph = 1,
	hps = 20,
	hit_y = -0.1,
}

function killaura.get(key)
	return tonumber(core.settings:get("killaura." .. key)) or killaura[key]
end

function killaura.punch_object(obj)
	local pos = core.localplayer:get_pos()
	local lv = core.localplayer:get_velocity()
	core.localplayer:set_velocity(vector.new(0, killaura.get("hit_y"), 0))
	for i = 1, killaura.get("hph") do
		obj:punch()
	end
	core.localplayer:set_velocity(lv)
	core.localplayer:set_pos(pos)
end

local function not_in_friendlist(obj)
	local friends = nlist.get("friends")
	return table.indexof(friends, obj:get_name()) == -1
		and table.indexof(friends, obj:get_properties().nametag) == -1
end

local function in_enemylist(obj)
	local enemies = nlist.get("enemies")
	return table.indexof(enemies, obj:get_name()) ~= -1
		or table.indexof(enemies, obj:get_properties().nametag) ~= -1
end

local function hit_objects(radius, check)
	local pl = core.localplayer
	local lp = pl:get_pos()
	local rt = false
	for _, obj in pairs(core.get_objects_inside_radius(lp, radius)) do
		if not check or (check and check(obj)) then
			killaura.punch_object(obj)
			rt = true
		end
	end
	return rt
end

ws.rg("Killaura", {
	category = "Combat",
	setting = "killaura",
	on_step = function(self, dtime)
		local friendfunc = in_enemylist
		if core.settings:get_bool("killaura.attack_all", false) then
			friendfunc = not_in_friendlist
		end
		hit_objects(tonumber(core.settings:get("killaura.range")) or 10, function(obj)
			return obj and obj:is_player() and friendfunc(obj) and not obj:is_local_player()
		end)
	end,
	cheat_settings = {
		hph = { type = "number", default = 1, min = 1, max = 10 },
		hit_y = { type = "number", default = -0.1, min = -5, max = 5 },
		range = { type = "number", default = 10, min = 1, max = 30 },
		attack_all = { type = "bool", default = false },
	},
})

ws.rg("Mobaura", {
	category = "Combat",
	setting = "mobaura",
	on_step = function(self, dtime)
		hit_objects(tonumber(core.settings:get("mobaura.range")) or 10, function(obj)
			local p = obj and obj:get_properties()
			local r = obj and obj:get_rotation()
			return p and r and r.z == 0 and (p.mesh:find("mobs_mc") or p.mesh:find("extra_mobs"))
		end)
	end,
	cheat_settings = {
		range = { type = "number", default = 10, min = 1, max = 30 },
	},
})

core.register_cheat("ForceField", { category = "Combat", setting = "forcefield" })

core.register_list_command("friend", "Configure Friend List (friends dont get attacked by Killaura or Forcefield)", "friendlist")

local function find_safespot(pos)
	local n = core.get_node_or_nil(pos)
	if not n or n.name == "air" then return end
	local nn = core.find_nodes_in_area(ws.dircoord(1, -4, -3), ws.dircoord(4, 4, 3), {"air"})
	table.sort(nn, function(a, b) return vector.distance(pos, a) < vector.distance(pos, b) end)
	if #nn > 0 then
		return nn[1]
	end
	return false
end

ws.rg("AirHead", {
	category = "Player",
	setting = "airhead",
	on_step = function(self, dtime)
		local pos = core.localplayer:get_pos()
		local sp = find_safespot(pos:offset(0, 1, 0))
		if sp then
			core.localplayer:set_pos(sp:offset(0, -1, 0))
		end
	end,
})
