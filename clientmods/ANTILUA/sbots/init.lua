sbots = {}

local death_pos = nil  -- single death position for the local player

local movement_strategies = {}

movement_strategies.walk = {
	requires_movement = true,
	on_step = function(bot, lp)
		ws.aim(bot.target_pos)
		core.settings:set_bool("continuous_forward", true)
	end,
}

movement_strategies.teleport = {
	requires_movement = true,
	on_step = function(bot, lp)
		ws.aim(bot.target_pos)
		core.settings:set_bool("continuous_forward", false)
		if rhythmtp and not rhythmtp.is_moving() then
			rhythmtp.go_to(bot.target_pos)
		end
	end,
}

movement_strategies.stationary = {
	requires_movement = false,
	on_step = function(bot, lp)
		bot.stage = 2
	end,
}

movement_strategies.server_tp = {
	requires_movement = true,
	on_step = function(bot, lp)
		ws.aim(bot.target_pos)
		core.settings:set_bool("continuous_forward", false)
		local now = core.get_us_time() / 1000000
		if not bot._tp_cooldown or now - bot._tp_cooldown > 0.3 then
			bot._tp_cooldown = now
			local p = bot.target_pos
			core.send_chat_message(
				"/teleport " .. math.floor(p.x) .. "," .. math.floor(p.y) .. "," .. math.floor(p.z))
		end
	end,
}

movement_strategies.client_tp = {
	requires_movement = true,
	on_step = function(bot, lp)
		ws.aim(bot.target_pos)
		core.settings:set_bool("continuous_forward", false)
		core.localplayer:set_pos(bot.target_pos)
		bot.stage = 2
	end,
}

movement_strategies.sprint = {
	requires_movement = true,
	on_step = function(bot, lp)
		ws.aim(bot.target_pos)
		core.settings:set_bool("continuous_forward", true)
		core.set_keypress("special1", true)
	end,
}

movement_strategies.patrol = {
	requires_movement = true,
	on_find = function(bot, lp)
		if bot._patrol_waypoints == nil then
			bot._patrol_idx = 0
			bot._patrol_waypoints = {}
			local wp_str = bot._setting and core.settings:get(bot._setting .. ".patrol_waypoints") or ""
			for name in wp_str:gmatch("[^,]+") do
				local t = name:match("^%s*(.-)%s*$")
				if t and #t > 0 then
					table.insert(bot._patrol_waypoints, t)
				end
			end
		end
		if #bot._patrol_waypoints == 0 then
			ws.notify("No patrol waypoints configured.", ws.NOTIFY_WARNING)
			return
		end
		bot._patrol_idx = bot._patrol_idx + 1
		if bot._patrol_idx > #bot._patrol_waypoints then
			local cycle = core.settings:get_bool(bot._setting .. ".patrol_cycle")
			if cycle ~= false then
				bot._patrol_idx = 1
			else
				core.settings:set_bool(bot._setting, false)
				return
			end
		end
		local wp_name = bot._patrol_waypoints[bot._patrol_idx]
		local wp_pos = poi and poi.get_waypoint(wp_name)
		if not wp_pos then
			ws.notify("Patrol waypoint '" .. wp_name .. "' not found.", ws.NOTIFY_WARNING)
			return
		end
		return wp_pos
	end,
	on_step = function(bot, lp)
		ws.aim(bot.target_pos)
		core.settings:set_bool("continuous_forward", true)
	end,
}

local bot_class = {
	find_pos = function(self, pos) end,
	do_pos = function(self, pos) end,
	do_step = function(self, dtime) end,
	update_pos = function(self, pos) return self:find_pos(pos) end,
	active = false,
	landing_distance = 1,
	moving_target = false,
	stand_waiting = false,
	target_pos = nil,
	movement = "walk",
}

local registered_bots = {}

-- Find the nearest node matching a list of names within range, sorted by distance.
-- Optional filter(pos): return true to accept, false to skip.
--- Set status text for a registered bot (shown in bot dashboard HUD).
function sbots.set_status(name, text)
	local bot = registered_bots[name]
	if bot then
		bot._status_text = text
	elseif name == nil then
		for _, b in pairs(registered_bots) do
			b._status_text = text
		end
	end
end

--- Get all active bots with their status for dashboard display.
function sbots.get_active_bots()
	local active = {}
	for name, bot in pairs(registered_bots) do
		if bot.active then
			table.insert(active, {
				name = name,
				status = bot._status_text or "active",
				movement = bot.movement or "walk",
			})
		end
	end
	table.sort(active, function(a, b) return a.name < b.name end)
	return active
end

function sbots.find_nearest(pos, node_names, range, filter)
	local nds = core.find_nodes_near(pos, range, node_names, true)
	if not nds or #nds == 0 then return end
	table.sort(nds, function(a, b) return vector.distance(pos, a) < vector.distance(pos, b) end)
	if filter then
		for _, p in ipairs(nds) do
			if filter(p) then return p end
		end
		return
	end
	return nds[1]
end

function sbots.register_bot(name, def)
	for k, v in pairs(bot_class) do
		if def[k] == nil then
			def[k] = v
		end
	end
	local tn = name

	local bot_settings = def.cheat_settings or {}
	bot_settings.allow_cobot = { type = "bool", default = false }
	bot_settings.movement = {
		type = "enum",
		default = def.movement or "walk",
		values = {"walk", "teleport", "server_tp", "client_tp", "stationary", "sprint", "patrol"},
	}
	bot_settings.patrol_waypoints = { type = "string", default = "" }
	bot_settings.patrol_cycle = { type = "bool", default = true }
	bot_settings.return_after_death = { type = "bool", default = true }

	def._setting = tn:lower()
	registered_bots[tn] = def

	ws.rg(name, {
		category = "Bots",
		setting = tn:lower(),
		description = def.description,
		on_step = function(_, dtime)
			local bot = registered_bots[tn]
			if not bot then return end
			local strategy = movement_strategies[bot.movement] or movement_strategies.walk
			local lp = core.localplayer:get_pos()

			-- Death return: if pending, set target and check arrival
			if not bot._return_target and bot.active and
					core.settings:get_bool(bot._setting .. ".return_after_death", true) then
				if death_pos and vector.distance(lp, death_pos) >= 3 then
					bot._return_target = death_pos
				elseif death_pos then
					death_pos = nil
				end
			end
			if bot._return_target and vector.distance(lp, bot._return_target) < 3 then
				bot._return_target = nil
				death_pos = nil
			end

			if bot.stage == 0 then
				if bot._return_target then
					bot.target_pos = bot._return_target
				elseif strategy.on_find then
					bot.target_pos = strategy.on_find(bot, lp)
				else
					bot.target_pos = bot:find_pos(lp)
				end
				if bot.target_pos then
					bot.stage = 1
				elseif bot.orig_pos and vector.distance(lp, bot.orig_pos) > bot.landing_distance then
					core.settings:set_bool("continuous_forward", false)
				else
					core.settings:set_bool("continuous_forward", false)
					if not bot.stand_waiting then
						core.log("nothing found!")
						core.settings:set_bool(tn, false)
					end
				end
			elseif bot.stage == 1 then
				if not bot.target_pos then return end
				if bot._return_target and vector.distance(lp, bot._return_target) < 3 then
					bot._return_target = nil
					death_pos = nil
					bot.stage = 0
					return
				end
				strategy.on_step(bot, lp)
				if strategy.requires_movement and
						vector.distance(lp, bot.target_pos) < bot.landing_distance then
					bot.stage = 2
				end
			elseif bot.stage == 2 then
				core.settings:set_bool("continuous_forward", false)
				if bot:do_pos(lp) then
					bot.stage = 0
				end
			else
				bot.stage = 0
			end
			if bot.moving_target then
				bot.target_pos = bot:update_pos(lp)
			end
			bot:do_step(dtime)
		end,
		on_start = function(self)
			local bot = registered_bots[tn]
			if not bot then return end
			for n, _ in pairs(registered_bots) do
				if n ~= tn and core.settings:get_bool(n) and not bot.allow_cobot then
					ws.notify("Another bot is active.", ws.NOTIFY_WARNING)
					return true
				end
			end
			local mov_val = core.settings:get(tn:lower() .. ".movement")
			if mov_val and movement_strategies[mov_val] then
				bot.movement = mov_val
			end
			local strategy = movement_strategies[bot.movement] or movement_strategies.walk
			bot.active = true
			bot.orig_pos = core.localplayer:get_pos()
			bot.target_pos = nil
			bot.stage = 0
			bot._patrol_waypoints = nil
			bot._patrol_idx = nil
			if strategy.requires_movement then
				bot._saved_pitch_move = core.settings:get_bool("pitch_move")
				bot._saved_free_move = core.settings:get_bool("free_move")
				core.settings:set_bool("pitch_move", true)
				core.settings:set_bool("free_move", true)
			end
			if bot.on_activate then
				return bot.on_activate(bot)
			end
		end,
		on_stop = function(self)
			local bot = registered_bots[tn]
			if not bot then return end
			local strategy = movement_strategies[bot.movement] or movement_strategies.walk
			bot.active = false
			core.settings:set_bool("continuous_forward", false)
			if strategy.requires_movement then
				core.settings:set_bool("pitch_move", bot._saved_pitch_move ~= nil and bot._saved_pitch_move or false)
				core.settings:set_bool("free_move", bot._saved_free_move ~= nil and bot._saved_free_move or false)
			end
			if bot.on_deactivate then
				return bot.on_deactivate(bot)
			end
		end,
		daughters = def.daughters,
		delay = def.delay,
		cheat_settings = bot_settings,
	})
end

ws.on_death(function()
	if not core.localplayer then return end
	local pos = vector.round(core.localplayer:get_pos())
	for _, bot in pairs(registered_bots) do
		if bot.active and core.settings:get_bool(bot._setting .. ".return_after_death", true) then
			death_pos = pos
			break
		end
	end
end)

------------------------------------------------------------------------------
-- Container / kit helpers
--
-- Placing containers (ender chest, shulker kits, chests) in the world to
-- access their inventories, and restocking materials from named kit shulkers
-- kept in the ender chest. If the private kit_util helper is available it is
-- used to keep consumables topped up; without it restock degrades gracefully
-- to what the player actually carries.
------------------------------------------------------------------------------

--- Read the custom label of an itemstack (renamed shulker kits).
function sbots.stack_label(stack)
	local meta = stack:get_meta()
	if not meta then return "" end
	local d = meta:get_string("description")
	if d == "" then
		d = meta:get_string("name")
	end
	return d
end

local function stack_has_contents(stack)
	local meta = stack:get_meta()
	if not meta then return false end
	return meta:get_string("compressed") ~= "" or meta:get_string("") ~= ""
end

--- Find a shulker kit stack in a player inventory list ("main"/"enderchest").
-- Preference: labelled kit with contents > labelled kit > sole shulker.
-- Returns the list index or nil.
function sbots.find_kit_stack(listname, label, item_name)
	local inv = core.get_inventory("current_player")
	if not inv or not inv[listname] then return nil end
	local shulkers = {}
	for i, stack in ipairs(inv[listname]) do
		if not stack:is_empty() and stack:get_name():find("shulker_box", 1, true) then
			table.insert(shulkers, {index = i, stack = stack})
		end
	end
	if #shulkers == 0 then return nil end
	local best, best_score
	for _, e in ipairs(shulkers) do
		local score = 0
		if item_name and item_name ~= "" and e.stack:get_name() == item_name then
			score = score + 4
		end
		local lbl = sbots.stack_label(e.stack)
		if label and lbl ~= "" and lbl:lower():find(label:lower(), 1, true) then
			score = score + 2
		end
		if stack_has_contents(e.stack) then
			score = score + 1
		end
		if not best_score or score > best_score then
			best, best_score = e.index, score
		end
	end
	if best_score and best_score > 0 then return best end
	-- No label/name match: only fall back when it is unambiguous.
	if #shulkers == 1 then return shulkers[1].index end
	return nil
end

local function main_empty_slot(inv)
	for i = 1, 9 do
		if inv.main[i]:is_empty() then return i end
	end
	return ws.hotbar_slot or 8
end

--- Make sure a pickaxe sits in the hotbar. Checks the player inventory, then
-- the ender chest. Returns the pickaxe item name or nil.
function sbots.ensure_pickaxe()
	local inv = core.get_inventory("current_player")
	if not inv or not inv.main then return nil end
	local function pick_of(stacks)
		for i, s in ipairs(stacks) do
			if not s:is_empty() and s:get_name():find("^mcl_tools:pick_") then
				return i, s:get_name()
			end
		end
	end
	local idx, name = pick_of(inv.main)
	if not idx and inv.enderchest then
		idx, name = pick_of(inv.enderchest)
		if idx then
			ws.move_stack("current_player", "enderchest", idx, "current_player", "main", main_empty_slot(inv))
		end
	end
	if not idx then return nil end
	if idx > 9 then
		ws.move_stack("current_player", "main", idx, "current_player", "main", main_empty_slot(inv))
	end
	return name
end

--- Place a node item in air near the player, never in the excluded columns
-- (pass rail line columns as avoid = { {x=,z=}, ... }) and never inside the
-- player's own body. Digs a pocket at the nearest diggable spot when no air
-- is available. Returns the position or nil.
function sbots.place_in_air(item_name, avoid)
	if not core.localplayer then return nil end
	local lp = core.localplayer:get_pos()
	if not lp then return nil end
	local rlp = vector.round(lp)
	if not ws.switch_to_item(item_name) then return nil end
	local cands = {}
	for dx = -2, 2 do
		for dy = -1, 2 do
			for dz = -2, 2 do
				table.insert(cands, vector.add(rlp, {x = dx, y = dy, z = dz}))
			end
		end
	end
	table.sort(cands, function(a, b)
		return vector.distance(lp, a) < vector.distance(lp, b)
	end)
	local function excluded(p)
		if p.x == rlp.x and p.z == rlp.z and (p.y == rlp.y or p.y == rlp.y + 1) then
			return true
		end
		if avoid then
			for _, a in ipairs(avoid) do
				if a.x == p.x and a.z == p.z then return true end
			end
		end
		return false
	end
	for _, p in ipairs(cands) do
		if not excluded(p) and ws.can_place_at(p) and ws.place(p, item_name) then
			return p
		end
	end
	for _, p in ipairs(cands) do
		if not excluded(p) then
			local nd = core.get_node_or_nil(p)
			if nd and nd.name ~= "air" and nd.name ~= "ignore" and ws.is_diggable(p) then
				ws.dig(p)
				if ws.place(p, item_name) then return p end
			end
		end
	end
	return nil
end

--- Open a placed container so its node inventory gets synchronised.
function sbots.open_container(pos)
	core.interact("activate", {
		type = "node",
		under = pos,
		above = vector.add(pos, {x = 0, y = 1, z = 0}),
	})
end

local function count_main(name)
	local inv = core.get_inventory("current_player")
	local total = 0
	if inv and inv.main then
		for _, s in ipairs(inv.main) do
			if not s:is_empty() and s:get_name() == name then
				total = total + s:get_count()
			end
		end
	end
	return total
end

local function find_placed(names, range)
	if not core.localplayer then return nil end
	local lp = core.localplayer:get_pos()
	local found = core.find_nodes_near(lp, range or 6, names, true)
	if not found or #found == 0 then return nil end
	table.sort(found, function(a, b)
		return vector.distance(lp, a) < vector.distance(lp, b)
	end)
	return found[1]
end

--- First item whose total count is below its wanted threshold.
function sbots.missing_item(items)
	if not items then return nil end
	for name, want in pairs(items) do
		if ws.count_item(name) < want then return name, want end
	end
	return nil
end

------------------------------------------------------------------------------
-- Restock job
--
-- sbots.refill_materials(opts) returns a job; poll job:step(dtime) which
-- returns "active", "done" or "failed" (job.error / job.missing describe the
-- outcome). opts:
--   kit       = "railkit"            -- kit label searched in the ender chest
--   kit_item  = "mcl_chests:..."     -- optional explicit shulker item name
--   items     = { [itemname] = want, ... }
--   avoid     = { {x=,z=}, ... }     -- columns containers must not be placed in
--   spare_kit = true                 -- use kit_util to duplicate the kit
------------------------------------------------------------------------------

local RESTOCK_WAIT = 0.45

local function ender_empty_slot(inv)
	if not inv or not inv.enderchest then return nil end
	for i, s in ipairs(inv.enderchest) do
		if s:is_empty() then return i end
	end
	return nil
end

local function any_empty_slot(inv)
	if not inv or not inv.main then return nil end
	for i, s in ipairs(inv.main) do
		if s:is_empty() then return i end
	end
	return nil
end

function sbots.refill_materials(opts)
	local KU = rawget(_G, "kit_util")
	local job = {phase = "start", wait = 0.2, missing = {}}
	local spare = opts.spare_kit ~= false and KU ~= nil
	local chest_pos, chest_placed
	local ender_pos, ender_placed
	local kit_pos, kit_item_name = nil, opts.kit_item or ""
	local drain_count, retried_original = 0, false
	local topup, topup_idx = {}, 1
	local pickup_item, pickup_base, pickup_deadline, pickup_target
	local nudged, return_pos
	local sub, on_sub = nil, nil

	local ENDER_NAMES = {"mcl_chests:ender_chest", "mcl_chests:ender_chest_small"}

	local function fail(msg)
		job.error = job.phase .. ": " .. tostring(msg)
		job.phase = "failed"
	end

	local function start_pickup(item, deadline, target)
		pickup_item = item
		pickup_base = count_main(item)
		pickup_deadline = os.clock() + (deadline or 8)
		pickup_target = target
		nudged = false
	end

	-- Waits for a dropped item to be picked up; teleports the player briefly
	-- onto the drop position if it takes too long. Returns true when finished.
	local function pickup_done()
		if count_main(pickup_item) > pickup_base then
			if return_pos then
				core.localplayer:set_pos(return_pos)
				return_pos = nil
			end
			return true
		end
		local now = os.clock()
		if now > pickup_deadline then
			if return_pos then
				core.localplayer:set_pos(return_pos)
				return_pos = nil
			end
			return true
		end
		if not nudged and pickup_target and now > pickup_deadline - 4 then
			nudged = true
			return_pos = core.localplayer:get_pos()
			core.localplayer:set_pos(vector.add(pickup_target, {x = 0, y = 0.5, z = 0}))
		end
		return false
	end

	local function move_to_enderchest(item_name)
		local inv = core.get_inventory("current_player")
		if not inv then return end
		for i, s in ipairs(inv.main) do
			if not s:is_empty() and s:get_name() == item_name then
				local slot = ender_empty_slot(inv)
				if not slot then return end
				ws.move_stack("current_player", "main", i, "current_player", "enderchest", slot)
				return
			end
		end
	end

	local function run_sub(j, cb)
		sub, on_sub = j, cb
	end

	function job:step(dtime)
		if self.phase == "done" then return "done" end
		if self.phase == "failed" then return "failed" end
		if not core.localplayer then
			return fail("no player")
		end

		if sub then
			local st = sub:step(dtime)
			if st == "active" then return "active" end
			local cb = on_sub
			sub, on_sub = nil, nil
			if cb then cb(st == "done") end
			return "active"
		end

		self.wait = self.wait - dtime
		if self.wait > 0 then return "active" end
		self.wait = RESTOCK_WAIT

		local phase = self.phase
		self.status = phase

		if phase == "start" then
			if sbots.find_kit_stack("main", opts.kit, kit_item_name) then
				self.phase = spare and "chest" or "ender"
			elseif sbots.find_kit_stack("enderchest", opts.kit, kit_item_name) then
				self.phase = spare and "chest" or "ender"
			else
				fail("kit '" .. tostring(opts.kit) .. "' not found")
			end

		elseif phase == "chest" then
			chest_pos = KU.find_chest(6)
			chest_placed = false
			if not chest_pos then
				chest_pos = sbots.place_in_air("mcl_chests:chest", opts.avoid)
				chest_placed = chest_pos ~= nil
			end
			-- No chest: no dupes this run; restock degrades gracefully.
			self.phase = "ender"

		elseif phase == "ender" then
			ender_pos = find_placed(ENDER_NAMES, 6)
			ender_placed = false
			if ender_pos then
				self.phase = "ender_open"
			elseif ws.count_item("mcl_chests:ender_chest") >= 1 then
				if chest_pos then
					-- Keep a spare ender chest around: it drops obsidian when
					-- mined, so the placed one is consumed. Best effort only.
					run_sub(KU.ensure_stack("mcl_chests:ender_chest", 2, chest_pos), function(ok)
						if not ok then
							job.soft_missing = job.soft_missing or {}
							job.soft_missing["mcl_chests:ender_chest"] = true
						end
						job.phase = "ender_place"
						job.wait = 0.3
					end)
					self.phase = "sub"
				else
					self.phase = "ender_place"
				end
			else
				fail("no ender chest available")
			end

		elseif phase == "ender_place" then
			ender_pos = sbots.place_in_air("mcl_chests:ender_chest", opts.avoid)
			ender_placed = ender_pos ~= nil
			if not ender_pos then
				return fail("could not place ender chest")
			end
			self.phase = "ender_open"

		elseif phase == "ender_open" then
			sbots.open_container(ender_pos)
			self.phase = "pull_kit"

		elseif phase == "pull_kit" then
			local idx = sbots.find_kit_stack("main", opts.kit, kit_item_name)
			if idx then
				kit_item_name = core.get_inventory("current_player").main[idx]:get_name()
			else
				idx = sbots.find_kit_stack("enderchest", opts.kit, kit_item_name)
				if not idx then
					return fail("kit '" .. tostring(opts.kit) .. "' not found")
				end
				kit_item_name = core.get_inventory("current_player").enderchest[idx]:get_name()
				local slot = any_empty_slot(core.get_inventory("current_player"))
				if not slot then
					return fail("inventory full")
				end
				ws.move_stack("current_player", "enderchest", idx,
					"current_player", "main", slot)
			end
			sbots.ensure_pickaxe()
			self.phase = (spare and chest_pos) and "dupe_kit" or "place_kit"

		elseif phase == "dupe_kit" then
			run_sub(KU.ensure_stack(kit_item_name, 2, chest_pos), function(ok)
				if ok then
					job.phase = "return_one"
				elseif count_main(kit_item_name) >= 1 then
					job.phase = "place_kit"
				else
					fail("kit restock failed")
				end
				job.wait = 0.3
			end)
			self.phase = "sub"

		elseif phase == "return_one" then
			-- Keep one kit for placing; return only the excess. The dupe step
			-- is skipped when the ender chest already holds spares, so main
			-- may carry just the one kit that is about to be placed.
			if count_main(kit_item_name) > 1 then
				move_to_enderchest(kit_item_name)
			end
			self.phase = "place_kit"

		elseif phase == "place_kit" then
			kit_pos = sbots.place_in_air(kit_item_name, opts.avoid)
			if not kit_pos then
				move_to_enderchest(kit_item_name)
				return fail("could not place kit shulker")
			end
			self.phase = "open_kit"

		elseif phase == "open_kit" then
			sbots.open_container(kit_pos)
			drain_count = 0
			self._sync_wait = 5
			self._sync_opened = false
			self.phase = "sync_kit"

		elseif phase == "sync_kit" then
			-- The placed shulker's node inventory reaches the client via a
			-- node-meta update; wait for it before draining.
			local cloc = "nodemeta:" .. kit_pos.x .. "," .. kit_pos.y .. "," .. kit_pos.z
			local kinv = core.get_inventory(cloc)
			local has_items = false
			if kinv then
				for _, stacks in pairs(kinv) do
					for _, stack in ipairs(stacks) do
						if not stack:is_empty() then
							has_items = true
							break
						end
					end
					if has_items then break end
				end
			end
			if has_items then
				self.phase = "drain_kit"
			else
				self._sync_wait = self._sync_wait - RESTOCK_WAIT
				if self._sync_wait <= 0 then
					if not self._sync_opened then
						sbots.open_container(kit_pos)
						self._sync_opened = true
						self._sync_wait = 3
						return "active"
					end
					-- Contents never became visible; recover the intact kit.
					ws.dig(kit_pos)
					start_pickup(kit_item_name, 8, kit_pos)
					self.phase = "recover_kit"
				end
			end

		elseif phase == "recover_kit" then
			if pickup_done() then
				return fail("kit contents were not visible client-side")
			end

		elseif phase == "drain_kit" then
			local cloc = "nodemeta:" .. kit_pos.x .. "," .. kit_pos.y .. "," .. kit_pos.z
			local kinv = core.get_inventory(cloc)
			local inv = core.get_inventory("current_player")
			if not (kinv and inv) then
				self.phase = "break_kit"
				return "active"
			end
			local moved = 0
			for _, stacks in pairs(kinv) do
				for idx, stack in ipairs(stacks) do
					if moved >= 4 then break end
					if not stack:is_empty() then
						inv = core.get_inventory("current_player")
						local slot = inv and ws.find_empty(inv.main)
						if not slot then break end
						job.kit_supplies = job.kit_supplies or {}
						job.kit_supplies[stack:get_name()] = true
						ws.move_stack(cloc, "main", idx, "current_player", "main", slot)
						moved = moved + 1
						drain_count = drain_count + 1
					end
				end
				if moved >= 4 then break end
			end
			if moved == 0 then
				sbots.ensure_pickaxe()
				if drain_count == 0 and spare and not retried_original
						and sbots.find_kit_stack("enderchest", opts.kit, kit_item_name) then
					-- The duplicated kit was empty; fall back to the original.
					retried_original = true
					spare = false
					ws.dig(kit_pos)
					self.phase = "pull_kit"
				else
					self.phase = "break_kit"
				end
			end

		elseif phase == "break_kit" then
			ws.dig(kit_pos)
			start_pickup(kit_item_name, 8, kit_pos)
			self.phase = "pickup_kit"

		elseif phase == "pickup_kit" then
			if pickup_done() then
				self.phase = "return_kits"
			end

		elseif phase == "return_kits" then
			local inv = core.get_inventory("current_player")
			if count_main(kit_item_name) < 1 then
				self.phase = "topup_prep"
			elseif inv and ender_empty_slot(inv) then
				move_to_enderchest(kit_item_name)
				self._return_tries = 0
			else
				-- No room in the ender chest: keep the kit in main and move on.
				self._return_tries = (self._return_tries or 0) + 1
				if self._return_tries > 3 then
					self.phase = "topup_prep"
				end
			end

		elseif phase == "topup_prep" then
			topup = {}
			for name, want in pairs(opts.items or {}) do
				if ws.count_item(name) < want then
					table.insert(topup, {name = name, want = want})
				end
			end
			table.sort(topup, function(a, b) return a.name < b.name end)
			topup_idx = 1
			if #topup == 0 or not chest_pos then
				for _, e in ipairs(topup) do
					job.missing[e.name] = true
				end
				self.phase = "cleanup"
			else
				self.phase = "topup"
			end

		elseif phase == "topup" then
			local e = topup[topup_idx]
			if not e then
				self.phase = "cleanup"
				return "active"
			end
			if ws.count_item(e.name) >= e.want then
				topup_idx = topup_idx + 1
				return "active"
			end
			run_sub(KU.ensure_stack(e.name, e.want, chest_pos), function(ok)
				if not ok then
					job.missing[e.name] = true
				end
				topup_idx = topup_idx + 1
				job.phase = topup_idx > #topup and "cleanup" or "topup"
				job.wait = 0.3
			end)
			self.phase = "sub"

		elseif phase == "cleanup" then
			if chest_placed and chest_pos then
				ws.dig(chest_pos)
				start_pickup("mcl_chests:chest", 8, chest_pos)
				self.phase = "pickup_chest"
			else
				self.phase = "ender_break"
			end

		elseif phase == "pickup_chest" then
			if pickup_done() then
				self.phase = "ender_break"
			end

		elseif phase == "ender_break" then
			if ender_placed and ender_pos then
				-- Consumed on mining (drops obsidian), the spare covers the
				-- next run.
				ws.dig(ender_pos)
				start_pickup("mcl_core:obsidian", 6, ender_pos)
				self.phase = "pickup_ender"
			else
				self.phase = "done"
			end

		elseif phase == "pickup_ender" then
			if pickup_done() then
				self.phase = "done"
			end

		else
			self.phase = "done"
		end

		return self.phase == "failed" and "failed" or "active"
	end

	return job
end


if nlist and dig then
	local dig_active = {}
	sbots.register_bot("listDigBot", {
		description = "Bot that digs nodes from selected nlist, respecting DigList range and constraints",
		find_pos = function(self, pos)
			return sbots.find_nearest(pos, nlist.get(nlist.selected), 60, ws.inside_constraints)
		end,
		do_pos = function(self, pos)
			local now = os.clock()
			local range = tonumber(core.settings:get("diglist.range")) or ws.range or 4
			local nn = core.find_nodes_near(pos, range, nlist.get(nlist.selected), true)
			if nn then
				for _, v in ipairs(nn) do
					if ws.inside_constraints(v) then
						local key = core.pos_to_string(v)
						if not dig_active[key] or now >= dig_active[key] then
							return false
						end
					end
				end
			end
			return true
		end,
		do_step = function(self, dtime)
			local pos = core.localplayer:get_pos()
			if not pos then return end
			local range = tonumber(core.settings:get("diglist.range")) or ws.range or 4
			local nn = core.find_nodes_near(pos, range, nlist.get(nlist.selected), true)
			if not nn then return end
			local now = os.clock()
			local npt = ws.get_nodes_per_tick()
			local count = 0
			for _, v in ipairs(nn) do
				if count >= npt then break end
				local key = core.pos_to_string(v)
				if not dig_active[key] and ws.inside_constraints(v) then
					local tm = dig.get_dig_time(v)
					dig_active[key] = now + (tm or 1) + 1
					ws.select_best_tool(v)
					dig.dig_node(v)
					count = count + 1
				end
			end
			for k, expires in pairs(dig_active) do
				if now >= expires then dig_active[k] = nil end
			end
		end,
	})
end
