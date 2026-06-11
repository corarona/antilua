local killaura = {
	hph = 1,
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
	if not nlist then return true end
	local friends = nlist.get("friends")
	if not friends then return true end
	return table.indexof(friends, obj:get_name()) == -1
		and table.indexof(friends, obj:get_properties().nametag) == -1
end

local function in_enemylist(obj)
	if not nlist then return false end
	local enemies = nlist.get("enemies")
	if not enemies then return false end
	return table.indexof(enemies, obj:get_name()) ~= -1
		or table.indexof(enemies, obj:get_properties().nametag) ~= -1
end

local function is_mob(obj)
	local p = obj and obj:get_properties()
	local r = obj and obj:get_rotation()
	local m = p and p.mesh
	return p and r and r.z == 0 and m
		and (m:find("mobs_mc") or m:find("extra_mobs"))
end

local function hit_objects(radius, check)
	local pl = core.localplayer
	local lp = pl:get_pos()
	local rt = false
	for _, obj in pairs(core.get_objects_inside_radius(lp, radius)) do
		if not check or check(obj) then
			killaura.punch_object(obj)
			rt = true
		end
	end
	return rt
end

local function make_filter(mode)
	if mode == "players_enemies" then
		return function(obj)
			return obj and obj:is_player() and in_enemylist(obj) and not obj:is_local_player()
		end
	elseif mode == "players_all" then
		return function(obj)
			return obj and obj:is_player() and not_in_friendlist(obj) and not obj:is_local_player()
		end
	elseif mode == "mobs" then
		return function(obj)
			return obj and not obj:is_player() and is_mob(obj)
		end
	elseif mode == "all" then
		return function(obj)
			return obj and not obj:is_local_player()
				and (obj:is_player() or is_mob(obj))
		end
	end
end

local function build_formspec()
	local function esc(t)
		local out = {}
		for _, v in ipairs(t) do
			table.insert(out, core.formspec_escape(v))
		end
		return table.concat(out, ",")
	end

	local friends = nlist and nlist.get("friends") or {}
	local enemies = nlist and nlist.get("enemies") or {}
	local f_str = #friends > 0 and esc(friends) or " "
	local e_str = #enemies > 0 and esc(enemies) or " "

	local fs = "size[10,8.5]"
	fs = fs .. "bgcolor[#000000;true]"
	fs = fs .. "label[0.3,0;Friends (not attacked)]"
	fs = fs .. "textlist[0.3,0.5;4.4,3;friend_entries;" .. f_str .. ";1]"
	fs = fs .. "field[0.3,3.8;7,0.8;friend_input;;]"
	fs = fs .. "button[7.4,3.8;1.2,0.8;btn_add_friend;Add]"
	fs = fs .. "button[8.7,3.8;1.2,0.8;btn_rm_friend;Rem]"
	fs = fs .. "label[5.3,0;Enemies (always attacked)]"
	fs = fs .. "textlist[5.3,0.5;4.4,3;enemy_entries;" .. e_str .. ";1]"
	fs = fs .. "field[5.3,3.8;7,0.8;enemy_input;;]"
	fs = fs .. "button[7.4,3.8;1.2,0.8;btn_add_enemy;Add]"
	fs = fs .. "button[8.7,3.8;1.2,0.8;btn_rm_enemy;Rem]"
	fs = fs .. "label[0.3,4.8;Tip: click a name in the list to remove it]"
	fs = fs .. "button_exit[8.5,7.5;1.3,0.8;btn_done;Done]"
	return fs
end

ws.rg("Killaura", {
	category = "Combat",
	setting = "killaura",
	on_step = function(self, dtime)
		local mode = core.settings:get("killaura.target_mode")
		if not mode or mode == "" then mode = "players_enemies" end
		local filter = make_filter(mode)
		if filter then
			hit_objects(killaura.get("range"), filter)
		end
	end,
	cheat_settings = {
		hph = { type = "number", default = 1, min = 1, max = 10 },
		hit_y = { type = "number", default = -0.1, min = -5, max = 5 },
		range = { type = "number", default = 10, min = 1, max = 30 },
		target_mode = {
			type = "enum",
			default = "players_enemies",
			values = {"players_enemies", "players_all", "mobs", "all"},
		},
	},
	get_formspec = build_formspec,
})

core.register_on_formspec_input(function(formname, fields)
	if formname ~= "cheat_settings:killaura:custom" then return end
	if fields.btn_done or not next(fields) then return end

	if not nlist then
		core.log("warning", "[killaura] nlist not available for friend/enemy management")
		return
	end

	if fields.btn_add_friend and fields.friend_input and fields.friend_input ~= "" then
		nlist.add("friends", fields.friend_input)
	end
	if fields.btn_rm_friend and fields.friend_input and fields.friend_input ~= "" then
		nlist.remove("friends", fields.friend_input)
	end
	if fields.btn_add_enemy and fields.enemy_input and fields.enemy_input ~= "" then
		nlist.add("enemies", fields.enemy_input)
	end
	if fields.btn_rm_enemy and fields.enemy_input and fields.enemy_input ~= "" then
		nlist.remove("enemies", fields.enemy_input)
	end
end)

-- Public API for external mods
killaura = {
	get = killaura.get,
	punch_object = killaura.punch_object,
}
