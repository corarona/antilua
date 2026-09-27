-- agent: AI-agent control surface.
-- Event feed, context snapshot, movement controller, verified actions.
-- Designed to be driven over the Lua pipe / MCP server; everything here is
-- non-blocking (no busy loops) so the client keeps running freely.

agent = {}

local last_formspec = nil
local move = nil
local fly_enabled = false

local now_us = function()
	return core.get_us_time() / 1000000
end

local function round(x)
	return math.floor(x + 0.5)
end

local poskey = function(pos)
	return string.format("%d,%d,%d", round(pos.x), round(pos.y), round(pos.z))
end

--
-- Event feed (ring buffer, like mcp_chat)
--

local MAX_EVENTS = 500
local events = {}
local event_seq = 0

local function ev(etype, data)
	event_seq = event_seq + 1
	table.insert(events, {
		id = event_seq,
		ts = os.date("%H:%M:%S"),
		type = etype,
		data = data or {},
	})
	if #events > MAX_EVENTS then
		table.remove(events, 1)
	end
end

function agent.events(since, types)
	since = tonumber(since) or 0
	local want = {}
	if type(types) == "table" then
		for _, t in ipairs(types) do want[t] = true end
	end
	local out = {}
	for _, e in ipairs(events) do
		if e.id > since and (not next(want) or want[e.type]) then
			out[#out + 1] = e
		end
	end
	return {events = out, cursor = event_seq, dropped = math.max(0, event_seq - #events)}
end

function agent.last_event_id()
	return event_seq
end

--
-- Persistent memory (per-modstorage, survives restarts)
--

local storage = core.get_mod_storage("agent")

function agent.mem(key, value)
	if value ~= nil then
		if type(value) == "table" then
			local ok, json = pcall(core.write_json, value)
			storage:set_string(key, ok and ("json:" .. json) or tostring(dump(value)))
		else
			storage:set_string(key, tostring(value))
		end
		return value
	end
	local raw = storage:get_string(key)
	if raw:sub(1, 5) == "json:" then
		local ok, t = pcall(core.parse_json, raw:sub(6))
		return ok and t or nil
	end
	if raw == "true" then return true end
	if raw == "false" then return false end
	return raw ~= "" and raw or nil
end

--
-- Pending action registry (verified dig/place/use results)
--

local actions = {}
local action_seq = 0

local function new_action(kind, pos, timeout)
	action_seq = action_seq + 1
	local key = kind .. "@" .. action_seq
	actions[key] = {
		kind = kind,
		key = key,
		pos = pos,
		pos_key = pos and poskey(pos) or nil,
		state = "pending",
		started = now_us(),
		deadline = now_us() + (timeout or 6),
	}
	return actions[key]
end

local function settle_action(act, node, t)
	-- Server confirmations for own placements/digs can arrive either as
	-- AddNode/RemoveNode packets or as a full block re-send; the reliable
	-- check is the actual node state.
	if act.kind == "dig" then
		if not node or node.name == "air" or node.name == "ignore" then
			act.state = "done"
			act.result = "removed"
		end
	elseif act.kind == "place" and act.expect then
		if node and node.name == act.expect then
			act.state = "done"
			act.result = node.name
		end
	end
end

local function sweep_actions()
	local t = now_us()
	for key, act in pairs(actions) do
		if act.state == "pending" then
			local pos = act.pos
			local node = pos and core.get_node_or_nil(pos)
			settle_action(act, node, t)
			if act.state == "pending" and t > act.deadline then
				if node and act.kind ~= "dig" then
					act.result = node.name
				end
				act.state = "timeout"
				ev("action", {kind = act.kind, key = act.key, state = act.state,
					pos = pos and {x = pos.x, y = pos.y, z = pos.z} or nil})
			elseif act.state == "done" then
				ev("action", {kind = act.kind, key = act.key, state = "done",
					result = act.result, pos = pos and {x = pos.x, y = pos.y, z = pos.z} or nil})
			end
		end
	end
end

function agent.action(key)
	return actions[key]
end

local function finish_action(kind, pos_key, result)
	for _, act in pairs(actions) do
		if act.kind == kind and act.pos_key == pos_key and act.state == "pending" then
			act.state = "done"
			act.result = result
			ev("action", {kind = act.kind, key = act.key, state = "done",
				result = result, pos = act.pos})
		end
	end
end

local function pending_use_action()
	local best
	for _, act in pairs(actions) do
		if act.kind == "use" and act.state == "pending" then
			if not best or act.started > best.started then
				best = act
			end
		end
	end
	return best
end

local function finish_use(formname)
	local act = pending_use_action()
	if act then
		act.state = "done"
		act.result = formname
		ev("action", {kind = "use", key = act.key, state = "done",
			result = formname, pos = act.pos})
	end
end

local function prune_actions()
	local t = now_us()
	for key, act in pairs(actions) do
		if act.state ~= "pending" and act.deadline and t > act.deadline + 300 then
			actions[key] = nil
		end
	end
end

--
-- Context snapshot
--

local function inv_summary()
	local out = {}
	local inv = core.get_inventory("current_player")
	if not inv or not inv.main then return out end
	for _, stack in ipairs(inv.main) do
		if stack and not stack:is_empty() then
			out[stack:get_name()] = (out[stack:get_name()] or 0) + stack:get_count()
		end
	end
	return out
end

local function objects_near(pos, radius)
	local out = {}
	for _, obj in ipairs(core.get_objects_inside_radius(pos, radius or 16)) do
		local ok, opos = pcall(obj.get_pos, obj)
		local ok2, oname = pcall(obj.get_name, obj)
		local ok3, ispl = pcall(obj.is_player, obj)
		local ok4, oid = pcall(obj.get_id, obj)
		if ok and opos then
			out[#out + 1] = {
				id = ok4 and oid or nil,
				name = (ok2 and oname) or "",
				is_player = (ok3 and ispl) or false,
				pos = {x = opos.x, y = opos.y, z = opos.z},
				dist = vector.distance(pos, opos),
			}
		end
	end
	table.sort(out, function(a, b) return a.dist < b.dist end)
	return out
end

function agent.ctx(radius)
	local lp = core.localplayer
	if not lp then
		return {joined = false}
	end
	local pos = lp:get_pos()
	local vel = pos and lp:get_velocity()
	local chat_line = mcp_chat and mcp_chat.recent and mcp_chat.recent(1)[1]
	local ok_day, day_count = pcall(core.get_day_count)
	local pointed = nil
	if pos then
		pcall(function()
			pointed = core.get_pointed_thing()
		end)
	end
	local ctx = {
		joined = true,
		name = lp:get_name(),
		pos = pos and {x = pos.x, y = pos.y, z = pos.z} or nil,
		look = {yaw = lp:get_yaw(), pitch = lp:get_pitch(), roll = lp:get_roll()},
		velocity = vel and {x = vel.x, y = vel.y, z = vel.z} or nil,
		hp = lp:get_hp(),
		breath = lp:get_breath(),
		dead = lp:get_hp() <= 0,
		touching_ground = lp:is_touching_ground(),
		in_liquid = lp:is_in_liquid(),
		is_climbing = lp:is_climbing(),
		attached = lp:is_attached(),
		standing_node = lp:get_standing_node(),
		wielded = (function()
			local stack = lp:get_wielded_item()
			if stack and not stack:is_empty() then
				return {name = stack:get_name(), count = stack:get_count(),
					wear = stack:get_wear()}
			end
			return nil
		end)(),
		wield_index = lp:get_wield_index(),
		inv = inv_summary(),
		moving = agent.moving(),
		move = move and agent.mstate() or nil,
		last_chat_id = chat_line and chat_line.id or nil,
		last_event_id = event_seq,
		last_formspec = last_formspec,
		server = core.get_server_info(),
		day_count = ok_day and day_count or nil,
		brightness = (core.sky and core.sky.get_brightness and
			core.sky:get_brightness()) or nil,
		ping = tps_client and tps_client.ping or nil,
		tps = tps_client and tps_client.tps or nil,
		time = os.time(),
		pointed = pointed,
		objects_near = pos and objects_near(pos, radius or 16) or nil,
	}
	return ctx
end

--
-- Movement controller
--

local function release_sprint()
	core.set_keypress("special1", false)
end

local function halt_forward()
	core.settings:set_bool("continuous_forward", false)
	release_sprint()
end

local function move_finish(state, reason)
	halt_forward()
	if move then
		if move.mode == "fly" then
			agent.set_fly_mode(false)
		end
		move.state = state
		move.reason = reason
		move.finished = now_us()
		ev("move", {status = state, reason = reason,
			target = move.target, mode = move.mode,
			dist = core.localplayer and core.localplayer:get_pos() and
				vector.distance(core.localplayer:get_pos(), move.target) or nil})
	end
end

local function lp_pos()
	local lp = core.localplayer
	return lp and lp:get_pos() or nil
end

local MOVE_SEG = 24      -- straight-line chunk length for unloaded areas
local PATH_DIST = 40     -- within this distance, try A* to the final target
local ARRIVE_WAYPOINT = 1.0

local function find_path_to(target)
	local lp = lp_pos()
	if not lp or not core.find_path then return nil end
	local ok, path = pcall(core.find_path, vector.round(lp), vector.round(target))
	if ok and path and #path > 0 then
		return path
	end
	return nil
end

local function new_segment(target)
	-- Prefer A* when the target is close (loaded terrain); otherwise steer
	-- straight-line in chunks and let the stuck detector catch failures.
	local path = nil
	local dist = vector.distance(lp_pos(), target)
	if dist <= PATH_DIST then
		path = find_path_to(target)
	end
	if path then
		move.path = path
		move.idx = 2 -- path[1] is the start node
		return move.path[move.idx]
	end
	local pos = lp_pos()
	local dir = vector.direction(pos, target)
	local len = math.min(MOVE_SEG, dist)
	local chunk = vector.round(vector.add(pos,
		{x = dir.x * len, y = dir.y * len, z = dir.z * len}))
	move.path = {chunk, target}
	move.idx = 1
	move.straight = dist > PATH_DIST
	return chunk
end

local function walk_step()
	local pos = lp_pos()
	local wp = move.path and move.path[move.idx]
	if not wp then
		wp = new_segment(move.target)
		if not wp then
			move_finish("failed", "no segment")
			return
		end
	end

	local d = vector.distance(pos, wp)
	if d < ARRIVE_WAYPOINT and move.idx < #move.path then
		move.idx = move.idx + 1
		wp = move.path[move.idx]
		d = vector.distance(pos, wp)
	end

	-- Waypoint consumed but not at target yet: extend toward it.
	if d < ARRIVE_WAYPOINT and move.idx >= #move.path then
		if vector.distance(pos, move.target) <= math.max(move.arrival, 1.6) then
			move_finish("done")
			return
		end
		wp = new_segment(move.target)
		if not wp then
			move_finish("failed", "no segment")
			return
		end
	end

	ws.aim(wp)

	if wp.y > math.floor(pos.y + 0.6) and d < 2.5 then
		core.localplayer:set_autojump(true)
	end

	core.settings:set_bool("continuous_forward", true)
	if move.mode == "sprint" then
		core.set_keypress("special1", true)
	end

	-- Net-progress guard (horizontal distance, immune to falling/bouncing)
	local t = now_us()
	local hd = math.sqrt(
		(pos.x - move.target.x) * (pos.x - move.target.x)
			+ (pos.z - move.target.z) * (pos.z - move.target.z))
	if move.best_dist == nil or hd < move.best_dist - 0.5 then
		move.best_dist = hd
		move.best_time = t
		move.stall_count = nil
	elseif t - (move.best_time or t) > 5.0 then
		if (move.stall_count or 0) >= 1 then
			move_finish("failed", "no progress")
			return
		end
		move.stall_count = (move.stall_count or 0) + 1
		move.path = nil
		move.idx = nil
		move.best_time = t
	end

	-- Stuck detection: too little progress for too long
	if vector.distance(pos, move.last_pos) > 0.4 then
		move.last_pos = pos
		move.last_progress = t
		move.stuck_jumps = 0
	else
		local stuck_t = t - move.last_progress
		if stuck_t > 1.0 then
			core.localplayer:set_autojump(true)
			move.stuck_jumps = (move.stuck_jumps or 0) + 1
		end
		if stuck_t > 2.5 and (t - (move.last_recalc or 0)) > 2.0 then
			move.last_recalc = t
			move.path = nil
			move.idx = nil
		end
		if stuck_t > 6 then
			move_finish("failed", "stuck")
			return
		end
	end
end

-- Find a nearby, genuinely walkable target in the most open direction
-- (used by tests/agents to avoid cliff/obstacle targets). Accepts flat
-- steps and downhill drops up to 2 nodes; falls back to shorter hops.
function agent.open_target(want)
	local lp = core.localplayer
	if not lp then return nil end
	local base = vector.round(lp:get_pos())
	local dirs = {
		{x = 1, z = 0}, {x = -1, z = 0}, {x = 0, z = 1}, {x = 0, z = -1},
		{x = 1, z = 1}, {x = -1, z = -1}, {x = 1, z = -1}, {x = -1, z = 1},
	}
	local function step_ok(p)
		local at = core.get_node_or_nil(p)
		local above = core.get_node_or_nil({x = p.x, y = p.y + 1, z = p.z})
		if not at or not above then
			return false
		end
		-- swimming: water at feet level with air/other above counts as open
		if at.name:find("water") then
			return true
		end
		local open_at = at.name == "air"
			or (core.get_node_def(at.name) or {}).buildable_to
		local open_above = above.name == "air"
			or (core.get_node_def(above.name) or {}).buildable_to
		if not (open_at and open_above) then
			return false
		end
		-- ground at feet level (flat) or a drop of up to 3 nodes (downhill)
		for drop = 0, 3 do
			local below = core.get_node_or_nil(
				{x = p.x, y = p.y - 1 - drop, z = p.z})
			if below and below.name ~= "air" and below.name ~= "ignore" then
				return true
			end
		end
		return false
	end
	for _, w in ipairs({want or 4, math.max(2, (want or 4) - 1),
			math.max(2, (want or 4) - 2)}) do
		local best, best_n = nil, 0
		for _, d in ipairs(dirs) do
			local n = 0
			for i = 1, w + 2 do
				local p = {x = base.x + d.x * i, y = base.y, z = base.z + d.z * i}
				if step_ok(p) then
					n = i
				else
					break
				end
			end
			if n > best_n then
				best_n = n
				best = {x = base.x + d.x * n, y = base.y, z = base.z + d.z * n}
			end
		end
		if best_n >= w then
			return best
		end
	end
	return nil
end

function agent.go_to(pos, mode, opts)
	local lp = core.localplayer
	if not lp then
		return {ok = false, error = "no localplayer"}
	end
	if not pos or pos.x == nil or pos.y == nil or pos.z == nil then
		return {ok = false, error = "invalid pos"}
	end
	mode = mode or "walk"
	local target = vector.round(vector.new(pos.x, pos.y, pos.z))
	local dist = vector.distance(lp:get_pos(), target)
	if dist < 0.5 then
		return {ok = true, state = "done", dist = 0, target = target}
	end
	halt_forward()

	move = {
		target = target,
		mode = mode,
		arrival = (opts and opts.arrival) or 1.3,
		speed = opts and opts.speed or nil,
		started = now_us(),
		deadline = now_us() + ((opts and opts.timeout) or math.max(15, dist * 0.8)),
		last_pos = lp:get_pos(),
		last_progress = now_us(),
		path = nil,
		idx = nil,
	}

	if mode == "rtp" then
		if rhythmtp and rhythmtp.go_to then
			rhythmtp.go_to(target)
		else
			return {ok = false, error = "rhythmtp not available"}
		end
	elseif mode == "fly" then
		core.settings:set_bool("priv_bypass", true)
		core.settings:set_bool("free_move", true)
		agent.set_fly_mode(true)
		lp:set_velocity(vector.direction(lp:get_pos(), target)
			* (move.speed or 8))
	elseif mode == "tp" then
		lp:set_pos(target)
		move.state = "done"
		ev("move", {status = "done", mode = "tp", target = target, dist = 0})
	elseif mode == "walk" or mode == "sprint" then
		walk_step()
	else
		return {ok = false, error = "unknown mode " .. tostring(mode)}
	end
	return agent.mstate()
end

-- Flight: velocity-driven traversal (free_move). The globalstep lives in the
-- mod (not in pipe code) and is fully guarded so it never lingers after the
-- move ends. Callers can keep using it for repeated hops.
function agent.set_fly_mode(enabled)
	fly_enabled = enabled and true or false
	if not fly_enabled then
		if core.localplayer then
			core.localplayer:set_velocity({x = 0, y = 0, z = 0})
		end
		core.settings:set_bool("free_move", false)
	end
end

function agent.fly_to(pos, speed, timeout)
	return agent.go_to(pos, "fly", {speed = speed, timeout = timeout,
		arrival = 1.0})
end

function agent.moving()
	return move and move.state == nil
end

function agent.mstate()
	if not move then
		return {active = false, state = "idle"}
	end
	local pos = lp_pos()
	local out = {
		active = move.state == nil,
		mode = move.mode,
		state = move.state or "moving",
		reason = move.reason,
		target = move.target,
		dist = pos and vector.distance(pos, move.target) or nil,
		started = move.started,
		deadline = move.deadline,
	}
	if move.state == "done" or move.state == "failed" or move.state == "stopped" then
		out.active = false
	end
	return out
end

function agent.stop()
	halt_forward()
	if move and move.state == nil then
		move.state = "stopped"
		ev("move", {status = "stopped", target = move.target, mode = move.mode})
	end
	return {ok = true, state = move and move.state or "idle"}
end

--
-- Actions
--

-- Wield the stack in main[slot] (1-based), moving it into the hotbar first
-- when needed. Handles a full hotbar by evicting the currently wielded stack
-- into a free main slot above the hotbar.
local function wield_slot(slot)
	local lp = core.localplayer
	if not lp then return false end
	local inv = core.get_inventory("current_player")
	if not inv or not inv.main or not inv.main[slot] then return false end
	local hbs = lp:get_hotbar_size() or 8
	if slot <= hbs then
		lp:set_wield_index(slot)
		return true
	end
	local target
	for i = 1, hbs do
		local st = inv.main[i]
		if not st or st:is_empty() then
			target = i
			break
		end
	end
	if not target then
		local cur = lp:get_wield_index()
		local free
		for i = hbs + 1, #inv.main do
			local st = inv.main[i]
			if not st or st:is_empty() then
				free = i
				break
			end
		end
		if free then
			ws.move_stack("current_player", "main", cur,
				"current_player", "main", free)
		end
		target = cur
	end
	if not target or target > hbs then return false end
	ws.move_stack("current_player", "main", slot, "current_player", "main", target)
	lp:set_wield_index(target)
	return true
end

function agent.dig(pos, opts)
	local lp = core.localplayer
	if not lp then return {ok = false, error = "no localplayer"} end
	if not pos then return {ok = false, error = "invalid pos"} end
	pos = vector.round(vector.new(pos.x, pos.y, pos.z))
	local node = core.get_node_or_nil(pos)
	if not node or node.name == "air" or node.name == "ignore" then
		return {ok = false, error = "node not loaded or already air"}
	end
	local nd = core.get_node_def(node.name)
	if not nd or not nd.diggable then
		return {ok = false, error = "not diggable", node = node.name}
	end
	local tm = math.huge
	if (opts and opts.autotool) ~= false then
		local ok_tool, tool_idx, best_time = pcall(ws.find_best_tool, node.name)
		if ok_tool and best_time and best_time < math.huge then
			if wield_slot(tool_idx) then
				tm = best_time
			end
		end
	end
	if tm == math.huge then
		tm = ws.get_digtime(node.name) or math.huge
	end
	if tm == math.huge or tm > 45 then
		return {ok = false, error = "dig time too long, need a better tool",
			digtime = tm == math.huge and -1 or tm}
	end
	local max_time = opts and opts.max_time
	if max_time and max_time > 0 and tm > max_time then
		return {ok = false, error = "dig exceeds max_time", digtime = tm}
	end
	core.interact("start_digging", {type = "node", under = pos, above = pos})
	core.after(tm + 0.05, function()
		core.interact("digging_completed", {type = "node", under = pos, above = pos})
	end)
	local timeout = (tm + ((opts and opts.timeout) or 5))
	local act = new_action("dig", pos, timeout)
	ev("action", {kind = "dig", key = act.key, state = "started", node = node.name})
	return {ok = true, key = act.key, node = node.name, digtime = tm, timeout = timeout}
end

local function neighbor_above(pos)
	local lp = lp_pos()
	if not lp then return vector.new(pos.x, pos.y + 1, pos.z) end
	local d = vector.subtract(pos, lp)
	local ax, ay, az = math.abs(d.x), math.abs(d.y), math.abs(d.z)
	if ay >= ax and ay >= az then
		return vector.new(pos.x, pos.y + (d.y >= 0 and 1 or -1), pos.z)
	elseif ax >= az then
		return vector.new(pos.x + (d.x >= 0 and 1 or -1), pos.y, pos.z)
	else
		return vector.new(pos.x, pos.y, pos.z + (d.z >= 0 and 1 or -1))
	end
end

function agent.place(pos, item, opts)
	local lp = core.localplayer
	if not lp then return {ok = false, error = "no localplayer"} end
	if not pos then return {ok = false, error = "invalid pos"} end
	pos = vector.round(vector.new(pos.x, pos.y, pos.z))
	local node = core.get_node_or_nil(pos)
	if not node then
		return {ok = false, error = "block not loaded (move closer)"}
	end
	local nd = core.get_node_def(node.name)
	if not nd or not nd.buildable_to then
		return {ok = false, error = "not buildable", node = node.name}
	end
	if item and item ~= "" then
		local inv = core.get_inventory("current_player")
		local slot = inv and ws.find_named(inv.main, item)
		if not slot or not wield_slot(slot) then
			return {ok = false, error = "item not in inventory", item = item}
		end
	elseif lp:get_wielded_item():is_empty() then
		return {ok = false, error = "nothing wielded"}
	end
	local above = (opts and opts.above) and vector.new(opts.above.x, opts.above.y, opts.above.z)
		or neighbor_above(pos)
	local expected = item or ""
	if expected == "" then
		local stack = lp:get_wielded_item()
		expected = stack and stack:get_name() or ""
	end
	local def = expected ~= "" and core.get_item_def(expected)
	local act = new_action("place", pos, (opts and opts.timeout) or 6)
	act.expect = (def and def.node_placement_prediction) or expected
	core.interact("place", {type = "node", under = pos, above = above})
	ev("action", {kind = "place", key = act.key, state = "started"})
	return {ok = true, key = act.key, above = above, expect = act.expect}
end

function agent.use(pos, opts)
	local lp = core.localplayer
	if not lp then return {ok = false, error = "no localplayer"} end
	if not pos then return {ok = false, error = "invalid pos"} end
	pos = vector.round(vector.new(pos.x, pos.y, pos.z))
	local above = (opts and opts.above) and vector.new(opts.above.x, opts.above.y, opts.above.z)
		or neighbor_above(pos)
	core.interact("place", {type = "node", under = pos, above = above})
	local act = new_action("use", pos, (opts and opts.timeout) or 4)
	ev("action", {kind = "use", key = act.key, state = "started"})
	return {ok = true, key = act.key, above = above}
end

function agent.formspec()
	return last_formspec
end

function agent.punch(object_id)
	local lp = core.localplayer
	if not lp then return {ok = false, error = "no localplayer"} end
	local obj = core.get_active_object_by_id(tonumber(object_id) or 0)
	if not obj then return {ok = false, error = "no such object"} end
	pcall(function()
		local opos = obj:get_pos()
		if opos then ws.aim(opos) end
	end)
	lp:punch(tonumber(object_id))
	return {ok = true}
end

function agent.aim(pos, velocity, gravity)
	local lp = core.localplayer
	if not lp or not pos then return {ok = false, error = "invalid args"} end
	local ppos = lp:get_pos()
	if velocity and velocity > 0 then
		local dist = vector.distance(ppos, pos)
		local dir = vector.direction(ppos, pos)
		local g = gravity or 9.81
		local t = dist / velocity
		local dy = dir.y * dist + 0.5 * g * t * t
		local hd = math.sqrt(dir.x * dir.x + dir.z * dir.z) * dist
		local pitch = math.deg(math.atan2(dy, math.max(hd, 0.001)))
		core.localplayer:set_yaw(ws.yaw_to(pos) or 0)
		core.localplayer:set_pitch(-pitch)
	else
		ws.aim(pos)
	end
	return {ok = true, look = {yaw = lp:get_yaw(), pitch = lp:get_pitch()}}
end

function agent.look(yaw, pitch)
	local lp = core.localplayer
	if not lp then return {ok = false, error = "no localplayer"} end
	if yaw ~= nil then lp:set_yaw(yaw) end
	if pitch ~= nil then lp:set_pitch(pitch) end
	return {ok = true, look = {yaw = lp:get_yaw(), pitch = lp:get_pitch()}}
end

function agent.jump()
	local lp = core.localplayer
	if not lp then return {ok = false, error = "no localplayer"} end
	lp:set_autojump(true)
	return {ok = true}
end

function agent.eat()
	if autoeat and autoeat.eat then
		local before = inv_summary()
		autoeat.eat()
		core.after(0.5, function()
			local after = inv_summary()
			for name, count in pairs(before) do
				if (after[name] or 0) < count then
					ev("eat", {item = name, diff = count - (after[name] or 0)})
					return
				end
			end
		end)
		return {ok = true, source = "autoeat"}
	end
	return {ok = false, error = "autoeat mod not loaded"}
end

function agent.respawn()
	local lp = core.localplayer
	if not lp then return {ok = false, error = "no localplayer"} end
	if lp:get_hp() > 0 then
		return {ok = false, error = "not dead"}
	end
	core.send_respawn()
	return {ok = true}
end

local SURVIVAL_SETTINGS = {
	"autoeat", "autototem", "autojump", "autorespawn", "autotool",
}

function agent.survival(enabled)
	if enabled == nil then enabled = true end
	local applied = {}
	for _, name in ipairs(SURVIVAL_SETTINGS) do
		core.settings:set_bool(name, enabled)
		applied[name] = enabled
	end
	ev("survival", {enabled = enabled, applied = applied})
	return {ok = true, applied = applied}
end

--
-- Hooks feeding the event stream
--

core.register_on_receiving_chat_message(function(message)
	ev("chat", {text = core.strip_colors(message)})
	return nil
end)

core.register_on_death(function()
	ev("death", {pos = lp_pos()})
end)

core.register_on_damage_taken(function(amount)
	ev("damage", {amount = amount, hp = core.localplayer and core.localplayer:get_hp()})
end)

core.register_on_hp_modification(function(hp)
	ev("hp", {hp = hp})
end)

core.register_on_breath_changed(function(breath)
	ev("breath", {breath = breath})
end)

core.register_on_dignode(function(pos, node)
	ev("dignode", {pos = pos, node = node and node.name})
end)

core.register_on_placenode(function(pointed, item)
	ev("placenode", {under = pointed and pointed.under, above = pointed and pointed.above,
		item = item and item:get_name()})
end)

core.register_on_node_add(function(pos, node)
	finish_action("place", poskey(pos), node and node.name)
	ev("node_add", {pos = pos, node = node and node.name})
end)

core.register_on_node_remove(function(pos)
	finish_action("dig", poskey(pos), "removed")
	ev("node_remove", {pos = pos})
end)

core.register_on_object_add(function(id)
	ev("object_add", {id = id})
end)

core.register_on_object_hp_change(function(id, hp)
	ev("object_hp", {id = id, hp = hp})
end)

core.register_on_inventory_update(function()
	ev("inventory", {})
end)

core.register_on_inventory_action(function()
	ev("inventory_action", {})
end)

core.register_on_detached_inventory_update(function(name, keep)
	ev("detached_inv", {name = name, keep = keep})
end)

core.register_on_receiving_formspec(function(formname, formspec)
	last_formspec = {formname = formname, ts = now_us()}
	if formname and formname ~= "" then
		finish_use(formname)
	end
	ev("formspec", {formname = formname})
	return nil
end)

core.register_on_receiving_inventory_form(function(formspec)
	last_formspec = {formname = "inventory", ts = now_us()}
	finish_use("inventory")
	return nil
end)

core.register_on_open_nodemeta_form(function(pos, formspec)
	last_formspec = {formname = "nodemeta:" .. poskey(pos), ts = now_us()}
	finish_use("nodemeta:" .. poskey(pos))
	if formspec and #formspec > 0 then return nil end
	return nil
end)

core.register_on_connect(function()
	ev("connect", {server = core.get_server_info()})
end)

core.register_on_disconnect(function()
	halt_forward()
	ev("disconnect", {})
end)

--
-- Global step: sweep actions + drive movement
--

local sweep_timer = 0

core.register_globalstep(function(dtime)
	if not core.localplayer then return end

	sweep_timer = sweep_timer + dtime
	if sweep_timer > 0.25 then
		sweep_timer = 0
		sweep_actions()
		prune_actions()
	end

	if move and move.state == nil then
		local pos = lp_pos()
		local t = now_us()
		if pos then
			local hd = math.sqrt(
				(pos.x - move.target.x) * (pos.x - move.target.x)
					+ (pos.z - move.target.z) * (pos.z - move.target.z))
			if move.mode == "fly" then
				if vector.distance(pos, move.target) <= move.arrival then
					agent.set_fly_mode(false)
					move_finish("done")
				elseif t > move.deadline then
					agent.set_fly_mode(false)
					move_finish("failed", "timeout")
				else
					local speed = move.speed or 8
					core.localplayer:set_velocity(
						vector.direction(pos, move.target) * speed)
				end
			elseif (move.mode == "walk" or move.mode == "sprint") then
				if hd <= math.max(move.arrival, 1.6) then
					move_finish("done")
				elseif t > move.deadline then
					move_finish("failed", "timeout")
				else
					walk_step()
				end
			elseif vector.distance(pos, move.target) <= move.arrival then
				move_finish("done")
			elseif t > move.deadline then
				move_finish("failed", "timeout")
			elseif move.mode == "rtp" then
				if not (rhythmtp and rhythmtp.is_moving()) then
					if vector.distance(pos, move.target) <= math.max(move.arrival, 2.5) then
						move_finish("done")
					else
						move_finish("failed", "rhythmtp stopped early")
					end
				end
			end
		end
	end
end)

--
-- Chat commands (debug / interactive use)
--

core.register_chatcommand("agentstop", {
	description = "Stop the agent movement controller",
	func = function()
		return true, dump(agent.stop())
	end,
})

core.register_chatcommand("agentgoto", {
	description = "Walk the agent to x,y,z (modes: walk, sprint, tp, rtp)",
	params = "<x,y,z> [mode]",
	func = function(param)
		local pos_s, mode = param:match("^(%S+)%s*(%S*)$")
		local pos = ws.string_to_pos(pos_s)
		if not pos then return false, "Invalid position" end
		return true, dump(agent.go_to(pos, mode ~= "" and mode or nil))
	end,
})

core.register_chatcommand("agentstate", {
	description = "Show agent movement state",
	func = function()
		return true, dump(agent.mstate())
	end,
})
