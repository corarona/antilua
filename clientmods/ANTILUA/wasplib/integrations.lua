-- wasplib integrations: merged from headsaver, lavaalarm, lockview, autotool,
-- and scaffold (constraint system, place_if_needed, dig_if_able, UI helpers)

------------------------------------------------------------------------------
-- Constraint system (from scaffold)
------------------------------------------------------------------------------
local function load_constraint_pos(setting, field)
	local s = core.settings:get(setting)
	if s and s ~= "" then
		local p = core.string_to_pos(s)
		if p then
			ws[field] = p
			return p
		end
	end
	ws[field] = false
	return nil
end

local function save_constraint_pos(setting, pos)
	if pos then
		core.settings:set(setting, core.pos_to_string(pos))
	else
		core.settings:set(setting, "")
	end
end

ws.constraint_pos1 = false
ws.constraint_pos2 = false
local hwps = {}

load_constraint_pos("wasplib_constraint_pos1", "constraint_pos1")
load_constraint_pos("wasplib_constraint_pos2", "constraint_pos2")

function ws.set_constraint_pos(n, pos)
	if type(pos) == "string" then pos = core.string_to_pos(pos) end
	if not pos then pos = ws.dircoord(0, 0, 0) end
	local field = "constraint_pos" .. n
	ws[field] = vector.round(pos)
	save_constraint_pos("wasplib_constraint_pos" .. n, ws[field])
	local pstr = core.pos_to_string(ws[field])
	hwps[#hwps + 1] = ws.display_wp(ws[field], pstr)
	ws.notify("Constraint pos" .. n .. " set to " .. pstr, ws.NOTIFY_INFO, {toast=false})
end

ws.set_pos1 = function(pos) ws.set_constraint_pos(1, pos) end
ws.set_pos2 = function(pos) ws.set_constraint_pos(2, pos) end

function ws.reset_constraints()
	ws.constraint_pos1 = false
	ws.constraint_pos2 = false
	save_constraint_pos("wasplib_constraint_pos1")
	save_constraint_pos("wasplib_constraint_pos2")
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

------------------------------------------------------------------------------
-- headsaver (merged) -- 3-phase wall pass: step through thin walls,
-- directional air pocket search, dig at max reach, then fallback.
------------------------------------------------------------------------------
ws.rg("HeadSaver", {
	category = "Player",
	setting = "headsaver",
	description = "Pass through walls: step through thin, dig through thick",
	on_step = function()
		local head = ws.dircoord(0, 1, 0)
		local head_nd = core.get_node_or_nil(head)
		if not head_nd or head_nd.name == "air" then return end
		if head_nd.name == "ignore" then return end
		local ndef = core.get_node_def(head_nd.name)
		if not ndef then return end
		local g = ndef.groups or {}
		if g.opaque ~= 1 then return end

		local pos = core.localplayer:get_pos()
		local vel = core.localplayer:get_velocity()
		local dx, dy, dz
		if vel and (vel.x * vel.x + vel.y * vel.y + vel.z * vel.z) > 0.01 then
			local len = math.sqrt(vel.x * vel.x + vel.y * vel.y + vel.z * vel.z)
			dx = vel.x / len
			dy = vel.y / len
			dz = vel.z / len
		else
			local yaw = core.localplayer:get_yaw() * math.pi / 180
			dx = math.sin(yaw)
			dy = 0
			dz = math.cos(yaw)
		end

		-- Phase 1: step through thin walls
		for step = 1, 10 do
			local tp = vector.offset(pos, dx * step, dy * step, dz * step)
			local rp = vector.round(tp)
			local hp = vector.offset(rp, 0, 1, 0)
			local fnd = core.get_node_or_nil(rp)
			local hnd = core.get_node_or_nil(hp)
			if fnd and fnd.name == "air" and hnd and hnd.name == "air" then
				core.localplayer:set_pos(rp)
				return
			end
		end

		-- Phase 2: wider search in movement direction (3x3 cylinder)
		for step = 1, 10 do
			local tp = vector.offset(pos, dx * step, dy * step, dz * step)
			local rp = vector.round(tp)
			for xo = -1, 1 do
				for zo = -1, 1 do
					local cp = vector.offset(rp, xo, 0, zo)
					local hp = vector.offset(cp, 0, 1, 0)
					local cnd = core.get_node_or_nil(cp)
					local hnd = core.get_node_or_nil(hp)
					if cnd and cnd.name == "air" and hnd and hnd.name == "air" then
						core.localplayer:set_pos(cp)
						return
					end
				end
			end
		end

		-- Phase 3: dig one block straight ahead at max reach, teleport there
		local max_reach = 4
		local tp = vector.offset(pos, dx * max_reach, dy * max_reach, dz * max_reach)
		local rp = vector.round(tp)
		local hp = vector.offset(rp, 0, 1, 0)
		local dig_nd = core.get_node_or_nil(hp)
		if dig_nd and dig_nd.name ~= "air" and dig_nd.name ~= "ignore"
				and core.registered_nodes and core.registered_nodes[dig_nd.name]
				and not core.registered_nodes[dig_nd.name].buildable_to then
			ws.dig(hp)
			core.localplayer:set_pos(rp)
			return
		end

		-- Fallback: omnidirectional search (old Phase 2)
		local ap = ws.find_closest_reachable_airpocket(pos)
		if ap then
			core.localplayer:set_pos(ap)
			return
		end

		-- Last resort: dig current head block
		ws.dig(head)
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

local function show_constraints_wp(self, field, pos, label)
	local cur = self[field]
	if not pos then
		if cur then
			core.localplayer:hud_remove(cur)
			self[field] = nil
		end
		return
	end
	if cur then
		core.localplayer:hud_remove(cur)
	end
	self[field] = core.localplayer:hud_add({
		type = "waypoint",
		name = label,
		text = label,
		number = 0x00FF00,
		world_pos = pos,
	})
end

ws.rg("ShowConstraints", {
	category = "Render",
	setting = "show_constraints",
	description = "Show a wireframe box around the constraint area",
	delay = 0,
	on_step = function(self)
		core.draw3d:clear(CONSTRAINTS_VIZ_GROUP)

		local p1 = ws.constraint_pos1
		local p2 = ws.constraint_pos2
		if p1 and p2 then
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
		end

		show_constraints_wp(self, "_wp1", p1, "Pos1")
		show_constraints_wp(self, "_wp2", p2, "Pos2")
	end,
	on_stop = function(self)
		core.draw3d:clear(CONSTRAINTS_VIZ_GROUP)
		if self._wp1 then
			core.localplayer:hud_remove(self._wp1)
			self._wp1 = nil
		end
		if self._wp2 then
			core.localplayer:hud_remove(self._wp2)
			self._wp2 = nil
		end
	end,
})

--
-- HUD anchor helper: returns {position, alignment, offset} for a named anchor.
-- Additional dx, dy are pixel offsets from the anchor point.
--
local hud_anchors = {
	center =			{ pos = {x=0.5, y=0.5}, align = {x=0.5, y=0.5} },
	top_center =		{ pos = {x=0.5, y=0},   align = {x=0.5, y=0}   },
	top_left =			{ pos = {x=0,   y=0},   align = {x=0,   y=0}   },
	top_right =			{ pos = {x=1,   y=0},   align = {x=1,   y=0}   },
	bottom_center =		{ pos = {x=0.5, y=1},   align = {x=0.5, y=1}   },
	bottom_left =		{ pos = {x=0,   y=1},   align = {x=0,   y=1}   },
	bottom_right =		{ pos = {x=1,   y=1},   align = {x=1,   y=1}   },
	right_center =		{ pos = {x=1,   y=0.5}, align = {x=1,   y=0.5} },
	left_center =		{ pos = {x=0,   y=0.5}, align = {x=0,   y=0.5} },
}

function ws.hud_anchor(name, dx, dy)
	local a = hud_anchors[name]
	if not a then
		a = hud_anchors.center
	end
	return {
		position = a.pos,
		alignment = a.align,
		offset = { x = (dx or 0), y = (dy or 0) },
	}
end

--
-- HUD layout registry: assigns non-overlapping vertical slots per anchor so
-- HUD widgets from different mods never collide. Each widget reserves a slot
-- with its current height (in text lines) and re-reserves whenever the height
-- changes; release() frees the slot. Only vertical placement is managed —
-- each widget keeps its own horizontal placement.
--
--   local slot = ws.hud_layout.reserve("mymod", "top_right", 3)
--   hud_add({ position = slot.position, alignment = slot.alignment,
--             offset = { x = -10, y = slot.y }, ... })
--   ... ws.hud_layout.release("mymod")
--
local hud_layout_slots = {}  -- anchor -> { id -> { height, y } }
local hud_layout_order = {}  -- anchor -> array of ids (reservation order)
local HUD_LINE_H = 15        -- pixels per text line
local HUD_GAP = 6            -- gap between widgets
local HUD_TOP = 8            -- top margin

--- Whether the minimap is currently drawn in the top-right corner.
function ws.hud_layout_minimap_active()
	if not core.settings:get_bool("enable_minimap") then return false end
	local mm = core.ui and core.ui.minimap
	if not mm or type(mm.get_mode) ~= "function" then return false end
	return mm:get_mode() > 0
end

--- Pixel offset to add below the minimap footprint when it is visible.
-- Controlled by the ws_hud_minimap_avoid_fraction setting (fraction of the
-- screen height, default 1/4); 0 disables avoidance entirely.
function ws.hud_layout_minimap_offset(screen_h)
	if not screen_h or screen_h <= 0 then return 0 end
	local frac = tonumber(core.settings:get("ws_hud_minimap_avoid_fraction")) or 0.25
	if frac <= 0 then return 0 end
	return math.floor(screen_h * frac)
end

--- Top margin for a given anchor's stack. The top_right anchor is pushed down
-- by the minimap footprint when the minimap is visible so HUD widgets don't
-- overlap it; other anchors are unaffected.
function ws.hud_layout_top(anchor)
	local top = HUD_TOP
	if anchor == "top_right" and ws.hud_layout_minimap_active() then
		local win = core.get_player_window_information and core.get_player_window_information()
		if win and win.size and win.size.y then
			top = top + ws.hud_layout_minimap_offset(win.size.y)
		end
	end
	return top
end

local function layout_anchor(anchor)
	local a = hud_anchors[anchor]
	if not a then a = hud_anchors.top_right end
	return a
end

local function hud_layout_rebuild(anchor)
	local slots = hud_layout_slots[anchor]
	local order = hud_layout_order[anchor]
	if not slots or not order then return end
	local y = ws.hud_layout_top(anchor)
	for _, id in ipairs(order) do
		local e = slots[id]
		e.y = y
		y = y + e.height * HUD_LINE_H + HUD_GAP
	end
end

--- Reserve (or re-reserve) a vertical HUD slot.
-- @param id     Unique widget id (e.g. mod name). Re-reserving keeps order.
-- @param anchor Named anchor from ws.hud_anchor (defaults to top_right)
-- @param height Current height in text lines (recomputed by the caller)
-- @return { position, alignment, y } where y is the pixel offset from the top
function ws.hud_layout_reserve(id, anchor, height)
	height = math.max(tonumber(height) or 1, 1)
	local a = layout_anchor(anchor)
	hud_layout_slots[anchor] = hud_layout_slots[anchor] or {}
	hud_layout_order[anchor] = hud_layout_order[anchor] or {}
	local slots = hud_layout_slots[anchor]
	local order = hud_layout_order[anchor]
	if not slots[id] then
		slots[id] = { height = height }
		table.insert(order, id)
	else
		slots[id].height = height
	end
	hud_layout_rebuild(anchor)
	return {
		position = a.pos,
		alignment = a.align,
		y = slots[id].y,
	}
end

--- Free a widget's HUD slot (from any anchor if anchor is nil).
function ws.hud_layout_release(id, anchor)
	if not anchor then
		for an, slots in pairs(hud_layout_slots) do
			if slots[id] then
				slots[id] = nil
				local order = hud_layout_order[an]
				for i = #order, 1, -1 do
					if order[i] == id then table.remove(order, i) end
				end
				hud_layout_rebuild(an)
			end
		end
		return
	end
	local slots = hud_layout_slots[anchor]
	local order = hud_layout_order[anchor]
	if slots and slots[id] then
		slots[id] = nil
		for i = #order, 1, -1 do
			if order[i] == id then table.remove(order, i) end
		end
		hud_layout_rebuild(anchor)
	end
end

--- Clear all HUD layout slots (or just one anchor).
function ws.hud_layout_clear(anchor)
	if anchor then
		hud_layout_slots[anchor] = {}
		hud_layout_order[anchor] = {}
	else
		hud_layout_slots = {}
		hud_layout_order = {}
	end
end

ws.hud_layout = {
	reserve = ws.hud_layout_reserve,
	release = ws.hud_layout_release,
	clear = ws.hud_layout_clear,
	top = ws.hud_layout_top,
	minimap_active = ws.hud_layout_minimap_active,
	minimap_offset = ws.hud_layout_minimap_offset,
}

core.register_on_disconnect(function()
	ws.hud_layout_clear()
end)
