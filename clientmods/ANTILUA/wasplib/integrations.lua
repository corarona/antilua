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
	local pstr = core.pos_to_string(ws.constraint_pos1)
	hwps[#hwps + 1] = ws.display_wp(pstr, ws.constraint_pos1)
	ws.notify("Constraint pos1 set to " .. pstr, ws.NOTIFY_INFO, {toast=false})
end

function ws.set_pos2(pos)
	if type(pos) == "string" then pos = core.string_to_pos(pos) end
	if not pos then pos = ws.dircoord(0, 0, 0) end
	ws.constraint_pos2 = vector.round(pos)
	local pstr = core.pos_to_string(ws.constraint_pos2)
	hwps[#hwps + 1] = ws.display_wp(pstr, ws.constraint_pos2)
	ws.notify("Constraint pos2 set to " .. pstr, ws.NOTIFY_INFO, {toast=false})
end

function ws.reset_constraints()
	ws.constraint_pos1 = false
	ws.constraint_pos2 = false
	for k, v in pairs(hwps) do
		if core.localplayer then
			core.localplayer:hud_remove(v)
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

core.register_chatcommand("pos1", {
	description = "Set constraint position 1",
	params = "[x,y,z]",
	func = function(param)
		if param and param ~= "" then
			local p = core.string_to_pos(param)
			if p then
				ws.set_pos1(p)
			end
			return
		end
		ws.set_pos1()
	end,
})

core.register_chatcommand("pos2", {
	description = "Set constraint position 2",
	params = "[x,y,z]",
	func = function(param)
		if param and param ~= "" then
			local p = core.string_to_pos(param)
			if p then ws.set_pos2(p) end
		else
			ws.set_pos2()
		end
	end,
})

core.register_chatcommand("creset", {
	description = "Reset constraints",
	func = ws.reset_constraints,
})

------------------------------------------------------------------------------
-- Common scaffold helpers (moved from scaffold, now in wasplib)
------------------------------------------------------------------------------
function ws.place_if_needed(items, pos, place)
	if not ws.inside_constraints(pos) then return end
	if not pos then return end
	place = place or core.place_node

	local node = core.get_node_or_nil(pos)
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
			parts[#parts + 1] = "image[" .. px .. "," .. py .. ";0,0;mcl_formspec_itemslot.png]"
		end
	end
	return table.concat(parts)
end

local function find_air_ahead(pos, steps)
	local yaw = core.localplayer and core.localplayer:get_yaw()
	if not yaw then return end
	yaw = yaw * math.pi / 180
	local dx = math.sin(yaw)
	local dz = math.cos(yaw)
	for step = 1, steps do
		local fp = vector.offset(pos, dx * step, 0, dz * step)
		local fpos = vector.round(fp)
		local hp = vector.offset(fpos, 0, 1, 0)
		local feet = core.get_node_or_nil(fpos)
		local head = core.get_node_or_nil(hp)
		if not feet or not head then return end
		if feet.name == "air" and head.name == "air" then
			return fpos
		end
	end
end

------------------------------------------------------------------------------
-- headsaver (merged) -- wall-jump: prefers air ahead, then closest pocket, then dig
------------------------------------------------------------------------------
ws.rg("HeadSaver", {
	category = "Player",
	setting = "headsaver",
	description = "Save head position for quick return",
	on_step = function()
		local head = ws.dircoord(0, 1, 0)
		local headnd = core.get_node_or_nil(head)
		if headnd and headnd.name ~= "air" then
			local ap = find_air_ahead(ws.dircoord(0, 0, 0), 10)
			if ap then
				core.localplayer:set_pos(ap)
				return
			end
			ap = ws.find_closest_reachable_airpocket(ws.dircoord(0, 0, 0))
			if ap then
				core.localplayer:set_pos(ap)
				return
			end
			ws.dig(head)
		end
	end,
})

------------------------------------------------------------------------------
-- lockview (merged)
------------------------------------------------------------------------------
ws.rg("LockView", {
	category = "Player",
	setting = "lockview",
	description = "Lock camera to a fixed direction",
	on_step = function(self)
		if self.pitch and self.yaw then
			core.localplayer:set_yaw(self.yaw)
			core.localplayer:set_pitch(self.pitch)
		end
	end,
	on_start = function(self)
		self.pitch = core.localplayer:get_pitch() * -1
		self.yaw = core.localplayer:get_yaw()
	end,
	on_stop = function(self)
		self.pitch = nil
		self.yaw = nil
	end,
})

------------------------------------------------------------------------------
-- autotool (merged into wasplib, uses ws.find_best_tool from tools.lua)
------------------------------------------------------------------------------
local at_new_idx, at_old_idx, at_pointed_pos, at_best_time

core.register_on_punchnode(function(pos, node)
	if core.settings:get_bool("autotool") then
		at_pointed_pos = pos
		at_old_idx = at_old_idx or core.localplayer:get_wield_index()
		at_new_idx, at_best_time = ws.find_best_tool(node.name)
	end
end)

core.register_globalstep(function()
	local player = core.localplayer
	if not at_new_idx or not player then return end
	if core.settings:get_bool("autotool") then
		local pt = core.get_pointed_thing()
		if pt and pt.type == "node" then
			local ptpos = pt.under
			if ptpos and vector.equals(ptpos, at_pointed_pos) and player:get_control().dig then
				player:set_wield_index(at_new_idx)
				if at_best_time == 0 then
					core.dig_node(at_pointed_pos)
				end
				return
			end
		end
	end
	player:set_wield_index(at_old_idx or player:get_wield_index())
	at_new_idx, at_old_idx, at_pointed_pos, at_best_time = nil
end)

core.register_cheat("AutoTool", { category = "Inventory", setting = "autotool", description = "Auto-select the best tool for the job" })

----------------------------------------------------------------------------------
-- StripChatColors
----------------------------------------------------------------------------------
core.register_cheat("StripChatColors", { category = "Render", setting = "strip_chat_colors", description = "Remove color codes from chat messages" })
if not core.settings:get("strip_chat_colors") then
	core.settings:set("strip_chat_colors", "false")
end

core.register_on_receiving_chat_message(function(msg)
	if core.settings:get_bool("strip_chat_colors") then
		return core.strip_colors(msg)
	end
	-- Return the original message (or nil) to let it through unchanged
end)

--------------------------------------------------------------------------------
-- Constraint visualization: draw a wireframe box when constraints are active
--------------------------------------------------------------------------------
local CONSTRAINTS_VIZ_GROUP = 9001

ws.rg("ShowConstraints", {
	category = "Render",
	setting = "show_constraints",
	description = "Show a wireframe box around the constraint area",
	delay = 0,
	on_step = function()
		core.draw3d:clear(CONSTRAINTS_VIZ_GROUP)

		local p1 = ws.constraint_pos1
		local p2 = ws.constraint_pos2
		if not p1 or not p2 then return end

		local minp = vector.new(
			math.min(p1.x, p2.x) - 0.5,
			math.min(p1.y, p2.y) - 0.5,
			math.min(p1.z, p2.z) - 0.5
		)
		local maxp = vector.new(
			math.max(p1.x, p2.x) + 0.5,
			math.max(p1.y, p2.y) + 0.5,
			math.max(p1.z, p2.z) + 0.5
		)
		core.draw3d:add_wirebox(minp, maxp, "#00FF00", CONSTRAINTS_VIZ_GROUP)
	end,
	on_stop = function()
		core.draw3d:clear(CONSTRAINTS_VIZ_GROUP)
	end,
})
