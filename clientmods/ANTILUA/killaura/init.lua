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

local function get_target_name(obj)
	if obj:is_player() then
		return obj:get_name()
	end
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
	if ratio > 0.6 then
		return 0xFFCCFFCC
	elseif ratio > 0.3 then
		return 0xFFFFFF88
	end
	return 0xFFFF8888
end

local function hit_objects(radius, filter)
	local pl = core.localplayer
	local lp = pl:get_pos()
	local closest_obj = nil
	local closest_dist = math.huge
	for _, obj in pairs(core.get_objects_inside_radius(lp, radius)) do
		if not filter or filter(obj) then
			killaura.punch_object(obj)
			local dist = vector.distance(lp, obj:get_pos())
			if dist < closest_dist then
				closest_obj = obj
				closest_dist = dist
			end
		end
	end
	return closest_obj
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
	local af = core.al_formspec
	local friends = nlist and nlist.get("friends") or {}
	local enemies = nlist and nlist.get("enemies") or {}
	local sb = af.cheat_form_begin("size[10,8.5]")
	sb:add(
		af.label(0.3, 0, "Friends (not attacked)"),
		af.textlist(0.3, 0.5, 4.4, 3, "friend_entries", friends),
		af.field(0.3, 3.8, 7, 0.8, "friend_input", "", ""),
		af.button(7.4, 3.8, 1.2, 0.8, "btn_add_friend", "Add"),
		af.button(8.7, 3.8, 1.2, 0.8, "btn_rm_friend", "Rem"),
		af.label(5.3, 0, "Enemies (always attacked)"),
		af.textlist(5.3, 0.5, 4.4, 3, "enemy_entries", enemies),
		af.field(5.3, 3.8, 7, 0.8, "enemy_input", "", ""),
		af.button(7.4, 3.8, 1.2, 0.8, "btn_add_enemy", "Add"),
		af.button(8.7, 3.8, 1.2, 0.8, "btn_rm_enemy", "Rem"),
		af.label(0.3, 4.8, "Tip: click a name in the list to remove it"),
		af.button_exit(8.5, 7.5, 1.3, 0.8, "btn_done", "Done")
	)
	return sb:get()
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

ws.rg("Killaura", {
	category = "Combat",
	setting = "killaura",
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
		local mode = core.settings:get("killaura.target_mode")
		if not mode or mode == "" then mode = "players_enemies" end
		local filter = make_filter(mode)
		local closest = nil
		if filter then
			closest = hit_objects(killaura.get("range"), filter)
		end
		update_target_hud(closest)
	end,
	on_stop = function(self)
		if killaura.hud_id then
			core.localplayer:hud_remove(killaura.hud_id)
			killaura.hud_id = nil
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
	core.show_cheat_settings_form("killaura")
end)

-- Public API for external mods
_G.killaura = {
	get = killaura.get,
	punch_object = killaura.punch_object,
}
