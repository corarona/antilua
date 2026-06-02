-- wasplib integrations: merged from headsaver, lavaalarm, lockview, autotool,
-- and scaffold (constraint system, place_if_needed, dig_if_able, UI helpers)

------------------------------------------------------------------------------
-- Constraint system (from scaffold)
------------------------------------------------------------------------------
ws.constraint_pos1 = false
ws.constraint_pos2 = false
local hwps = {}

function ws.set_pos1(pos)
	if type(pos) == "string" then pos = core.string_to_pos(pos) end
	if not pos then pos = ws.dircoord(0, 0, 0) end
	ws.constraint_pos1 = vector.round(pos)
	local pstr = minetest.pos_to_string(ws.constraint_pos1)
	hwps[#hwps + 1] = ws.display_wp(pstr, ws.constraint_pos1)
	ws.notify("Constraint pos1 set to " .. pstr, ws.NOTIFY_INFO, {toast=false})
end

function ws.set_pos2(pos)
	if type(pos) == "string" then pos = core.string_to_pos(pos) end
	if not pos then pos = ws.dircoord(0, 0, 0) end
	ws.constraint_pos2 = vector.round(pos)
	local pstr = minetest.pos_to_string(ws.constraint_pos2)
	hwps[#hwps + 1] = ws.display_wp(pstr, ws.constraint_pos2)
	ws.notify("Constraint pos2 set to " .. pstr, ws.NOTIFY_INFO, {toast=false})
end

function ws.reset_constraints()
	ws.constraint_pos1 = false
	ws.constraint_pos2 = false
	for k, v in pairs(hwps) do
		if minetest.localplayer then
			minetest.localplayer:hud_remove(v)
		end
		hwps[k] = nil
	end
end

function ws.inside_constraints(pos)
	if ws.constraint_pos1 and ws.constraint_pos2 then
		return ws.in_cube(pos, ws.constraint_pos1, ws.constraint_pos2)
	end
	if not ws.constraint_pos1 then
		return true
	end
	return false
end

minetest.register_chatcommand("cpos1", {
	description = "Set constraint position 1",
	params = "[x,y,z]",
	func = function(param)
		if param and param ~= "" then
			local p = minetest.string_to_pos(param)
			if p then ws.set_pos1(p) end
		else
			ws.set_pos1()
		end
	end,
})

minetest.register_chatcommand("cpos2", {
	description = "Set constraint position 2",
	params = "[x,y,z]",
	func = function(param)
		if param and param ~= "" then
			local p = minetest.string_to_pos(param)
			if p then ws.set_pos2(p) end
		else
			ws.set_pos2()
		end
	end,
})

minetest.register_chatcommand("creset", {
	description = "Reset constraints",
	func = ws.reset_constraints,
})

------------------------------------------------------------------------------
-- Common scaffold helpers (moved from scaffold, now in wasplib)
------------------------------------------------------------------------------
function ws.place_if_needed(items, pos, place)
	if not ws.inside_constraints(pos) then return end
	if not pos then return end
	place = place or minetest.place_node

	local node = minetest.get_node_or_nil(pos)
	if not node then return end
	if ws.in_list(node.name, items) then
		return true
	else
		if ws.find_any_swap(items) then
			place(pos)
			return true
		end
	end
	return false
end

function ws.dig_if_able(pos)
	if not ws.inside_constraints(pos) then return false end
	return ws.dig(pos)
end

------------------------------------------------------------------------------
-- nodes_per_tick helper
------------------------------------------------------------------------------
-- TODO: review whether this concept still makes sense
function ws.get_nodes_per_tick()
	return tonumber(core.settings:get("ws_nodes_per_tick")) or 8
end

------------------------------------------------------------------------------
-- UI helpers (from enderchest/openinv/punchinv)
------------------------------------------------------------------------------
function ws.get_slot(inv, filter)
	for idx, stack in pairs(inv) do
		if not filter or stack:get_name() == filter then
			return idx
		end
	end
	return nil
end

function ws.get_itemslot_bg_v4(x, y, w, h, margin)
	margin = margin or 0.15
	local parts = {}
	for i = 1, w do
		for j = 1, h do
			local px = x + margin + (i - 1)
			local py = y + margin + (j - 1)
			parts[#parts + 1] = "image[" .. px .. "," .. py .. ";0,0;mcl_formspec_itemslot_bg.png]"
		end
	end
	return table.concat(parts)
end

------------------------------------------------------------------------------
-- headsaver (merged)
------------------------------------------------------------------------------
ws.rg("HeadSaver", {
	category = "Player",
	setting = "headsaver",
	on_step = function()
		local head = ws.dircoord(0, 1, 0)
		local headnd = minetest.get_node_or_nil(head)
		if headnd and headnd.name ~= "air" then
			local ap = ws.find_closest_reachable_airpocket(ws.dircoord(0, 0, 0))
			if ap then
				minetest.localplayer:set_pos(ap)
				return
			end
			ws.dig(head)
		end
	end,
})

------------------------------------------------------------------------------
-- lockview (merged)
------------------------------------------------------------------------------
local lv_pitch = nil
local lv_yaw = nil

ws.rg("LockView", {
	category = "Bots",
	setting = "lockview",
	on_step = function()
		if lv_pitch and lv_yaw then
			core.localplayer:set_yaw(lv_yaw)
			core.localplayer:set_pitch(lv_pitch)
		end
	end,
	on_start = function()
		lv_pitch = core.localplayer:get_pitch() * -1
		lv_yaw = core.localplayer:get_yaw()
	end,
	on_stop = function()
		lv_pitch = nil
		lv_yaw = nil
	end,
})

------------------------------------------------------------------------------
-- lavaalarm (merged)
------------------------------------------------------------------------------
ws.rg("LavaAlarm", {
	category = "Player",
	setting = "lavaalarm",
	on_step = function(self)
		local lava = {
			"mcl_core:lava_source", "mcl_core:lava_flowing",
			"mcl_nether:nether_lava_source", "mcl_nether:nether_lava_flowing",
		}
		local range = tonumber(core.settings:get(self.setting .. ".detect_range")) or 3
		if minetest.find_node_near(ws.dircoord(0, 0, 0), range, lava) then
			minetest.sound_play("mcl_bells_bell_stroke", { pitch = 1.5, gain = 1.5 })
		end
	end,
	cheat_settings = {
		detect_range = { type = "number", default = 3, min = 1, max = 20 },
	},
})

-- mcl2-invul exploit (merged from lavaalarm)
local mcl2_t = 0.5
minetest.register_globalstep(function(dtime)
	local player = minetest.localplayer
	if not player then return end
	if minetest.settings:get_bool("mcl2-invul") then
		if mcl2_t <= 0 then
			minetest.send_damage(1)
			mcl2_t = 0.5
		end
		mcl2_t = mcl2_t - dtime
	end
end)

core.register_cheat("mcl2-invul", { category = "Player", setting = "mcl2-invul" })

minetest.register_chatcommand("mcl2_invul", {
	func = function()
		minetest.send_damage(1)
		minetest.disconnect()
	end,
})

------------------------------------------------------------------------------
-- autotool (merged into wasplib, uses ws.find_best_tool from tools.lua)
------------------------------------------------------------------------------
local at_new_idx, at_old_idx, at_pointed_pos, at_best_time

minetest.register_on_punchnode(function(pos, node)
	if minetest.settings:get_bool("autotool") then
		at_pointed_pos = pos
		at_old_idx = at_old_idx or minetest.localplayer:get_wield_index()
		at_new_idx, at_best_time = ws.find_best_tool(node.name)
	end
end)

minetest.register_globalstep(function()
	local player = minetest.localplayer
	if not at_new_idx or not player then return end
	if minetest.settings:get_bool("autotool") then
		local pt = minetest.get_pointed_thing()
		if pt and pt.type == "node" then
			local ptpos = minetest.get_pointed_thing_position(pt)
			if ptpos and vector.equals(ptpos, at_pointed_pos) and player:get_control().dig then
				player:set_wield_index(at_new_idx)
				if at_best_time == 0 then
					minetest.dig_node(at_pointed_pos)
				end
				return
			end
		end
	end
	player:set_wield_index(at_old_idx or player:get_wield_index())
	at_new_idx, at_old_idx, at_pointed_pos, at_best_time = nil
end)

core.register_cheat("AutoTool", { category = "Inventory", setting = "autotool" })
