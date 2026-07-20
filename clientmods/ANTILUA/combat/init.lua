local target_obj = nil  -- set via .target command; targeted object ref or nil

local killaura = {
	hph = 1,
	hit_y = -0.1,
	damage_log = {},
	friend_hp_cache = {},
}

function killaura.get(key)
	return ws.get_number("killaura", key) or killaura[key]
end

local function expire_damage_log()
	local now = core.get_us_time() / 1000000
	local timeout = killaura.get("retaliate_timeout")
	for name, entry in pairs(killaura.damage_log) do
		if now - entry.time > timeout then
			killaura.damage_log[name] = nil
		end
	end
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

local function is_projectile(obj)
	if not obj then return false end
	local name = obj:get_name() or ""
	if name == "mcl_bows:arrow_entity" then return true end
	if name == "mcl_throwing:snowball_entity" or name == "mcl_throwing:egg_entity"
			or name == "mcl_throwing:ender_pearl_entity" then return true end
	if name == "mcl_tridents:trident" or name == "mcl_experience:bottle" then return true end
	if name:find("^mcl_potions:.*_splash_flying$") then return true end
	if name:find("^mcl_potions:.*_lingering_flying$") then return true end
	if name:find("^mobs_mc:.*fireball$") or name == "mobs_mc:dragon_fireball" then return true end
	if name:find("^mobs_mc:wither_skull") then return true end
	if name == "mobs_mc:shulker_bullet" then return true end
	if name == "mobs_mc:llama_spit" then return true end
	return false
end

local function is_mob(obj)
	if not obj then return false end
	local name = obj:get_name() or ""
	if is_projectile(obj) then return false end
	return name:find("mobs_mc:") == 1 or name:find("extra_mobs:") == 1
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

local function is_hostile_mob(obj)
	local name = obj and obj:get_name() or ""
	if name:find("mobs_mc:") ~= 1 then return false end
	for _, p in ipairs(PASSIVE_MOBS) do
		if name == p then return false end
	end
	return true
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

local function resolve_mode(mode)
	local aliases = {
		players_enemies = "neutral",
		players_all = "aggressive",
		mobs = "neutral",
		all = "aggressive",
	}
	return aliases[mode] or mode or "aggressive"
end

local function find_closest_non_friend(from_pos)
	if not from_pos then return nil end
	local closest_name = nil
	local closest_dist = math.huge
	for _, obj in pairs(core.get_objects_inside_radius(from_pos, killaura.get("range"))) do
		if obj and obj:is_player() and not obj:is_local_player()
				and not_in_friendlist(obj) then
			local dist = vector.distance(from_pos, obj:get_pos())
			if dist < closest_dist then
				closest_name = obj:get_name()
				closest_dist = dist
			end
		end
	end
	return closest_name
end

local function track_friend_hp()
	local pos = core.localplayer:get_pos()
	if not pos then return end
	if not nlist then return end
	local friends = nlist.get("friends")
	if not friends or #friends == 0 then return end
	for _, obj in pairs(core.get_objects_inside_radius(pos, killaura.get("range"))) do
		if obj and obj:is_player() and not obj:is_local_player() then
			local name = obj:get_name()
			local hp = obj:get_hp() or 0
			local cached = killaura.friend_hp_cache[name]
			if cached and hp < cached and not not_in_friendlist(obj) then
				local attacker = find_closest_non_friend(obj:get_pos())
				if attacker then
				killaura.damage_log[attacker] = {
					time = core.get_us_time() / 1000000,
					damage = cached - hp,
					}
				end
			end
			killaura.friend_hp_cache[name] = hp
		end
	end
end

core.register_on_damage_taken(function(amount)
	if not core.settings:get_bool("killaura") then return end
	if not core.localplayer then return end
	local pos = core.localplayer:get_pos()
	if not pos then return end
	core.after(0.05, function()
		if not core.localplayer then return end
		local p = core.localplayer:get_pos()
		if not p then return end
		local name = find_closest_non_friend(p)
		if name then
			killaura.damage_log[name] = {
				time = core.get_us_time() / 1000000,
				damage = amount,
			}
		end
	end)
end)

local function mob_filter(obj)
	if not is_mob(obj) then return false end
	local attack_all = core.settings:get_bool("killaura.attack_all_mobs")
	local attack_hostile = core.settings:get_bool("killaura.attack_hostile_mobs")
	if attack_all then return true end
	if attack_hostile and is_hostile_mob(obj) then return true end
	return false
end

local function target_check(obj)
	return target_obj == nil or obj == target_obj
end

local PLAYER_CHECKS = {
	aggressive = function(obj) return not_in_friendlist(obj) end,
	neutral = function(obj) return in_enemylist(obj) end,
	retaliate = function(obj)
		return in_enemylist(obj) or (not_in_friendlist(obj) and killaura.damage_log[obj:get_name()])
	end,
	guard = function(obj)
		return in_enemylist(obj) or (not_in_friendlist(obj) and killaura.damage_log[obj:get_name()])
	end,
	hunter = function(obj)
		local hp = obj:get_hp() or 0
		return in_enemylist(obj) or (not_in_friendlist(obj) and hp > 0 and hp < killaura.get("hunter_threshold"))
	end,
}

local function make_filter(mode)
	local check = PLAYER_CHECKS[resolve_mode(mode)]
	return function(obj)
		if not obj or obj:is_local_player() then return false end
		if obj:is_player() and check(obj) then
			return target_check(obj)
		end
		if mob_filter(obj) then
			return target_check(obj)
		end
		return false
	end
end

-- Expose killaura helpers for PatrolGuard bot and external mods
_G.killaura = {
	get = killaura.get,
	make_filter = make_filter,
	resolve_mode = resolve_mode,
	not_in_friendlist = not_in_friendlist,
	in_enemylist = in_enemylist,
	damage_log = killaura.damage_log,
	find_closest_non_friend = find_closest_non_friend,
}

local function textlist_selected(field_value, items)
	if not field_value or field_value == "" or not items then return nil end
	local colon = field_value:find(":")
	local idx = colon and tonumber(field_value:sub(colon + 1)) or tonumber(field_value)
	if idx and idx >= 1 and idx <= #items then return items[idx] end
	return nil
end

local function build_formspec()
	local af = core.al_formspec
	local friends = nlist and nlist.get("friends") or {}
	local enemies = nlist and nlist.get("enemies") or {}
	local sb = af.cheat_form_begin("size[10,8]")
	sb:add(
		af.label(0.3, 0, "Friends (not attacked)"),
		af.textlist(0.3, 0.5, 4.4, 2, "friend_entries", friends),
		af.field(0.3, 2.8, 4.4, 0.7, "friend_input", "", ""),
		af.button(0.3, 3.6, 1.5, 0.7, "btn_add_friend", "Add"),
		af.button(1.9, 3.6, 1.5, 0.7, "btn_rm_friend", "Rem"),
		af.label(5.3, 0, "Enemies (always attacked)"),
		af.textlist(5.3, 0.5, 4.4, 2, "enemy_entries", enemies),
		af.field(5.3, 2.8, 4.4, 0.7, "enemy_input", "", ""),
		af.button(5.3, 3.6, 1.5, 0.7, "btn_add_enemy", "Add"),
		af.button(6.9, 3.6, 1.5, 0.7, "btn_rm_enemy", "Rem"),
		af.label(0.3, 4.8, "Tip: double-click a name in the list to remove it"),
		af.button(0.3, 6.5, 3, 0.8, "__cheat_settings__", "Settings"),
		af.button_exit(8.5, 6.5, 1.3, 0.8, "btn_done", "Done")
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

local function has_group(groups, name)
	local v = groups[name]
	return v ~= nil and v ~= 0
end

local function find_best_weapon()
	local best = { slot = nil, rank = 999 }
	for i = 1, 9 do
		local inv = core.get_inventory("current_player")
		if not inv then break end
		local stack = inv.main[i]
		if stack and not stack:is_empty() then
			local name = stack:get_name()
			local def = core.get_item_def(name)
			local groups = def and def.groups or {}
			local enchanted = name:find("_enchanted$") ~= nil
			local rank
			if has_group(groups, "mace") then
				rank = 0
			elseif has_group(groups, "sword") and enchanted then
				rank = 1
			elseif has_group(groups, "axe") and enchanted then
				rank = 2
			elseif has_group(groups, "sword") then
				rank = 3
			elseif has_group(groups, "axe") then
				rank = 4
			else
				rank = 999
			end
			if rank < best.rank then
				best = { slot = i, rank = rank, name = name }
			end
		end
	end
	return best.slot, best.name
end

local function hit_objects(radius, filter, interact_action)
	local pl = core.localplayer
	local lp = pl:get_pos()
	local closest_obj = nil
	local closest_dist = math.huge
	for _, obj in pairs(core.get_objects_inside_radius(lp, radius)) do
		if not filter or filter(obj) then
			if interact_action then
				core.interact(interact_action, {type = "object", ref = obj})
			else
				obj:punch()
			end
			local dist = vector.distance(lp, obj:get_pos())
			if dist < closest_dist then
				closest_obj = obj
				closest_dist = dist
			end
		end
	end
	return closest_obj
end

ws.rg("Killaura", {
	category = "Combat",
	setting = "killaura",
	description = "Auto-attack all nearby entities",
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
		local mode = resolve_mode(core.settings:get("killaura.target_mode"))
		expire_damage_log()
		if mode == "guard" then
			track_friend_hp()
		end
		local filter = make_filter(mode)
		local closest
		if filter then
			local lp = core.localplayer:get_pos()
			local found_target
			for _, obj in pairs(core.get_objects_inside_radius(lp, killaura.get("range"))) do
				if filter(obj) then
					found_target = true
					break
				end
			end
			if found_target then
				local weapon_slot, weapon_name = find_best_weapon()
				local is_mace = weapon_name and weapon_name:find("mace") ~= nil
				local vel = core.localplayer:get_velocity()
				local saved_pos = core.localplayer:get_pos()
				local saved_wield = core.localplayer:get_wield_index()
				local action
				if weapon_slot then
					local cur = core.localplayer:get_wield_index()
					if cur ~= weapon_slot then
						core.localplayer:set_wield_index(weapon_slot)
					end
					if is_mace then
						local d = tonumber(core.settings:get("killaura.mace_fall_distance")) or 10
						local v = math.sqrt(d * 40)
						core.localplayer:set_velocity({x = 0, y = -v, z = 0})
						core.localplayer:set_pos(saved_pos)
						action = "use"
					elseif vel.y >= -0.5 then
						core.localplayer:set_velocity({x = vel.x, y = -3, z = vel.z})
						core.localplayer:set_pos(saved_pos)
					end
				elseif vel.y >= -0.5 then
					core.localplayer:set_velocity({x = vel.x, y = -3, z = vel.z})
					core.localplayer:set_pos(saved_pos)
				end
				closest = hit_objects(killaura.get("range"), filter, action)
				if weapon_slot or vel.y >= -0.5 then
					local function restore()
						core.localplayer:set_velocity(vel)
						core.localplayer:set_pos(saved_pos)
					end
					restore()
					if weapon_slot then
						core.localplayer:set_wield_index(saved_wield)
					end
					if is_mace then
						core.after(0.05, restore)
						core.after(0.1, restore)
						core.after(0.2, restore)
					end
				end
			end
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
		attack_hostile_mobs = { type = "bool", default = false },
		attack_all_mobs = { type = "bool", default = false },
		target_mode = {
			type = "enum",
			default = "aggressive",
			values = {"aggressive", "neutral", "retaliate", "guard", "hunter"},
		},
		retaliate_timeout = { type = "number", default = 30, min = 5, max = 120 },
		hunter_threshold = { type = "number", default = 10, min = 1, max = 40 },
		mace_fall_distance = { type = "number", default = 10, min = 2, max = 50 },
	},
	get_formspec = build_formspec,
})

local function rm_item(list, input, tl_field, items)
	if input and input ~= "" then
		nlist.remove(list, input)
	elseif tl_field then
		local name = textlist_selected(tl_field, items)
		if name then nlist.remove(list, name) end
	end
end

local function add_rm_handler(fields, list, input_field, tl_field, items)
	local input = fields[input_field]
	local tl_val = fields[tl_field]
	if fields["btn_add_" .. list] and input and input ~= "" then
		nlist.add(list, input)
	elseif fields["btn_rm_" .. list] then
		rm_item(list, input, tl_val, items)
	end
end

core.register_on_formspec_input(function(formname, fields)
	if formname ~= "cheat_settings:killaura:custom" then return end
	if fields.btn_done or fields.quit or fields.__cheat_settings__ or not next(fields) then return end

	if not nlist then
		core.log("warning", "[killaura] nlist not available for friend/enemy management")
		return
	end

	local friends = nlist.get("friends") or {}
	local enemies = nlist.get("enemies") or {}

	if fields.friend_entries and fields.friend_entries:find("^DCL:") then
		local name = textlist_selected(fields.friend_entries, friends)
		if name then nlist.remove("friends", name) end
	elseif fields.enemy_entries and fields.enemy_entries:find("^DCL:") then
		local name = textlist_selected(fields.enemy_entries, enemies)
		if name then nlist.remove("enemies", name) end
	else
		add_rm_handler(fields, "friend", "friend_input", "friend_entries", friends)
		add_rm_handler(fields, "enemy", "enemy_input", "enemy_entries", enemies)
	end

	core.show_cheat_settings_form("killaura")
end)

core.register_chatcommand("target", {
	params = "[name]",
	description = "Target a specific player or mob by name. Without arguments, clear target and attack everything.",
	func = function(param)
		local trimmed = param and param:match("^%s*(.-)%s*$")
		if not trimmed or trimmed == "" then
			target_obj = nil
			core.display_chat_message("Target cleared — attacking all targets.")
			return true
		end
		local lp = core.localplayer and core.localplayer:get_pos()
		if not lp then return true end
		local tlower = trimmed:lower()
		for _, obj in pairs(core.get_objects_inside_radius(lp, 100)) do
			local olower = (obj:get_name() or ""):lower()
			if obj:is_player() and olower == tlower then
				target_obj = obj
				core.display_chat_message("Now targeting player: " .. (obj:get_name() or "?"))
				return true
			end
			if olower:find(tlower, 1, true) then
				target_obj = obj
				core.display_chat_message("Now targeting entity: " .. (obj:get_name() or "?"))
				return true
			end
		end
		core.display_chat_message("No entity found matching: " .. trimmed)
		return true
	end,
})

--
-- PatrolGuard bot (deferred until all mods loaded so sbots/poi exist)
--


sbots.register_bot("PatrolGuard", {
	description = "Patrol area and engage targets using killaura strategy",
	cheat_settings = {
		scan_range = { type = "number", default = 50, min = 10, max = 200 },
		target_mode = {
			type = "enum",
			default = "aggressive",
			values = {"aggressive", "neutral", "retaliate", "guard", "hunter"},
		},
		patrol_waypoints = { type = "string", default = "" },
		patrol_radius = { type = "number", default = 50, min = 10, max = 500 },
	},
	movement = "walk",
	stand_waiting = true,
	moving_target = true,
	landing_distance = 3,
	find_pos = function(self, pos)
		local mode = resolve_mode(core.settings:get("killaura.target_mode"))
		local filter = make_filter(mode)
		local scan_range = tonumber(core.settings:get("patrolguard.scan_range")) or 50

		local closest = nil
		local closest_dist = math.huge
		for _, obj in pairs(core.get_objects_inside_radius(pos, scan_range)) do
			if filter and filter(obj) then
				local d = vector.distance(pos, obj:get_pos())
				if d < closest_dist then
					closest = obj
					closest_dist = d
				end
			end
		end
		if closest then
			return closest:get_pos()
		end

		local wp_str = core.settings:get("patrolguard.patrol_waypoints") or ""
		local wps = {}
		for name in wp_str:gmatch("[^,]+") do
			local t = name:match("^%s*(.-)%s*$")
			if t and #t > 0 then
				table.insert(wps, t)
			end
		end
		if #wps > 0 then
			if not self._patrol_idx then self._patrol_idx = 0 end
			self._patrol_idx = self._patrol_idx + 1
			if self._patrol_idx > #wps then
				self._patrol_idx = 1
			end
			local wp_pos = poi.get_waypoint(wps[self._patrol_idx])
			if wp_pos then
				return wp_pos
			end
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
		local mode = resolve_mode(core.settings:get("killaura.target_mode"))
		local filter = make_filter(mode)
		local scan_range = tonumber(core.settings:get("patrolguard.scan_range")) or 50

		for _, obj in pairs(core.get_objects_inside_radius(pos, scan_range)) do
			if filter and filter(obj) then
				return obj:get_pos()
			end
		end
		return self.target_pos
	end,
	do_pos = function(self, pos)
		local mode = resolve_mode(core.settings:get("killaura.target_mode"))
		local filter = make_filter(mode)
		for _, obj in pairs(core.get_objects_inside_radius(pos, 5)) do
			if filter and filter(obj) then
				obj:punch()
				return false
			end
		end
		return true
	end,
	do_step = function(self, dtime)
		expire_damage_log()
		local mode = resolve_mode(core.settings:get("killaura.target_mode"))
		if mode == "guard" then
			track_friend_hp()
		end
	end,
})

local function find_safe_pos(target, hover_h)
	local tries = {
		{x = 0, y = 0, z = 0},
		{x = 2, y = 0, z = 0}, {x = -2, y = 0, z = 0},
		{x = 0, y = 0, z = 2}, {x = 0, y = 0, z = -2},
		{x = 2, y = 0, z = 2}, {x = -2, y = 0, z = -2},
		{x = 2, y = 0, z = -2}, {x = -2, y = 0, z = 2},
		{x = 0, y = 1, z = 0}, {x = 0, y = -1, z = 0},
		{x = 3, y = 0, z = 0}, {x = -3, y = 0, z = 0},
		{x = 0, y = 0, z = 3}, {x = 0, y = 0, z = -3},
	}
	for _, t in ipairs(tries) do
		local tp = vector.add(target, {x = t.x, y = hover_h, z = t.z})
		local head = core.get_node_or_nil(vector.offset(tp, 0, 1, 0))
		if head and head.name == "air" then
			return tp
		end
	end
	return nil
end

sbots.register_bot("KillauraBot", {
	description = "Hunt and attack targets using killaura logic",
	movement = "walk",
	stand_waiting = true,
	moving_target = true,
	landing_distance = 5,
	find_pos = function(self, pos)
		if core.settings:get_bool("killaurabot.lock_target") and self._locked_obj then
			local lp = self._locked_obj:get_pos()
			if lp and vector.distance(pos, lp) <= (tonumber(core.settings:get("killaurabot.scan_range")) or 50) then
				return lp
			end
			self._locked_obj = nil
		end
		local mode = resolve_mode(core.settings:get("killaura.target_mode"))
		local filter = make_filter(mode)
		local range = tonumber(core.settings:get("killaurabot.scan_range")) or 50
		local closest, closest_d = nil, math.huge
		for _, obj in pairs(core.get_objects_inside_radius(pos, range)) do
			if filter and filter(obj) then
				local d = vector.distance(pos, obj:get_pos())
				if d < closest_d then closest, closest_d = obj, d end
			end
		end
		return closest and closest:get_pos()
	end,
	do_pos = function(self, pos)
		local mode = resolve_mode(core.settings:get("killaura.target_mode"))
		local filter = make_filter(mode)
		local lock = core.settings:get_bool("killaurabot.lock_target")
		if lock then
			if not self._locked_obj then
				local closest, closest_d = nil, math.huge
				for _, obj in pairs(core.get_objects_inside_radius(pos, killaura.get("range"))) do
					if filter and filter(obj) then
						local d = vector.distance(pos, obj:get_pos())
						if d < closest_d then closest, closest_d = obj, d end
					end
				end
				if closest then self._locked_obj = closest end
			end
			if self._locked_obj then
				local lp = self._locked_obj:get_pos()
				if lp and vector.distance(pos, lp) <= killaura.get("range") then
					return false
				end
				self._locked_obj = nil
				return true
			end
		end
		for _, obj in pairs(core.get_objects_inside_radius(pos, killaura.get("range"))) do
			if filter and filter(obj) then return false end
		end
		return true
	end,
	do_step = function(self, dtime)
		local lp = core.localplayer:get_pos()
		if not lp then return end

		-- Projectile evaade
		if core.settings:get_bool("killaurabot.projectile_evade") then
			local range = tonumber(core.settings:get("killaurabot.evade_range")) or 5
			for _, obj in pairs(core.get_objects_inside_radius(lp, range)) do
				if is_projectile(obj) then
					local ppos = obj:get_pos()
					if ppos then
						local dir = vector.direction(lp, ppos)
						local evade = vector.add(lp, {x = dir.z * 3, y = 0.5, z = -dir.x * 3})
						core.localplayer:set_pos(evade)
					end
					break
				end
			end
		end

		-- Fly attack mode
		if not core.settings:get_bool("killaurabot.fly_attack") then return end
		if not self._locked_obj then return end
		local tgt = self._locked_obj:get_pos()
		if not tgt then return end
		local h = tonumber(core.settings:get("killaurabot.fly_height")) or 12

		self._fly_t = (self._fly_t or 0) + dtime

		if not self._diving then
			core.localplayer:set_velocity(vector.new(0, 0, 0))
			local hover_pos = find_safe_pos(tgt, h)
			if not hover_pos then
				hover_pos = vector.add(tgt, {x = 0, y = h, z = 0})
			end
			core.localplayer:set_pos(hover_pos)
			ws.aim(tgt)
			if self._fly_t > 0.3 then
				self._diving = true
				self._fly_t = 0
			end
		else
			if self._fly_t < 0.001 then
				core.localplayer:set_velocity(vector.new(0, -5, 0))
				core.localplayer:set_pos(vector.add(tgt, {x = 0, y = 0.5, z = 0}))
			end
			-- Punch the target directly each tick while in dive
			if self._locked_obj and self._locked_obj:get_pos() then
				self._locked_obj:punch()
			end
			if self._fly_t > 0.4 then
				core.localplayer:set_velocity(vector.new(0, 0, 0))
				self._diving = false
				self._fly_t = 0
			end
		end
	end,
	cheat_settings = {
		scan_range = { type = "number", default = 50, min = 10, max = 200 },
		projectile_evade = { type = "bool", default = false },
		evade_range = { type = "number", default = 5, min = 2, max = 15 },
		lock_target = { type = "bool", default = false },
		fly_attack = { type = "bool", default = false },
		fly_height = { type = "number", default = 12, min = 5, max = 30 },
	},
})
