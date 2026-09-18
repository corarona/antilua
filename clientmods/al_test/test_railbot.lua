-- Tests for RailBuilder mod.
--
-- test_railbot: static checks (all games).
-- test_railbot_integration: mineclonia only. Registers a deferred async test
-- that actually enables the bot, verifies the placed rail line node by node,
-- then empties the inventory and verifies the restock path (graceful mode —
-- the private kit_util helper is not loaded in CI, so no duplication happens;
-- the kit itself carries the goods).

local RAIL = "mcl_minecarts:golden_rail"
local RAIL_ON = "mcl_minecarts:golden_rail_on"
local RAILS = { [RAIL] = true, [RAIL_ON] = true }
local REDSTONE = "mcl_redstone_torch:redstoneblock"
local LIGHT_ITEM = "mcl_ocean:sea_lantern"
local LIGHT_MIN = 10
local PICKAXE = "mcl_tools:pick_netherite"

local RAILKIT = "mcl_chests:white_shulker_box"
local STATIONKIT = "mcl_chests:violet_shulker_box"
local ENDER_CHEST = "mcl_chests:ender_chest"

local LINE_COLUMNS = 8      -- rails + supports verified for columns 0..7
local LINE_LIGHTS = {0, 8}  -- light posts must exist here (rail_y + 2)
local CORRIDOR_FROM = 2     -- cleared columns must get a placed redstone
local CORRIDOR_TO = 12

local GIVE_ITEMS = {
	{RAIL, 256},
	{REDSTONE, 256},
	{LIGHT_ITEM, 32},
	{"mcl_core:obsidian", 64},
	{"mcl_fire:flint_and_steel", 2},
	{PICKAXE, 1},
	{RAILKIT, 1},
	{STATIONKIT, 1},
	{ENDER_CHEST, 3},
}

local KIT_RAIL_CONTENTS = {
	{name = RAIL, count = 128},
	{name = REDSTONE, count = 128},
	{name = LIGHT_ITEM, count = 16},
	{name = PICKAXE, count = 1},
}

local KIT_STATION_CONTENTS = {
	{name = "mcl_core:obsidian", count = 64},
	{name = "mcl_fire:flint_and_steel", count = 1},
}

function test_railbot(T)
	T.run("railbuilder cheat setting exists", function()
		T.assert(core.settings:get("railbuilder") ~= nil)
	end)

	T.run("RailBuilder registered in Bots category", function()
		local bots = core.cheats["Bots"]
		T.assert(bots ~= nil, "Bots category exists")
		local found = false
		for name, _ in pairs(bots) do
			if name:lower() == "railbuilder" then
				found = true
				break
			end
		end
		T.assert(found, "RailBuilder found in Bots category")
	end)

	T.run("railbuilder default settings exist", function()
		T.assert(core.settings:get("railbuilder.direction") ~= nil)
		T.assert(core.settings:get("railbuilder.redstone_sparsity") ~= nil)
		T.assert(core.settings:get("railbuilder.light_every") ~= nil)
		T.assert(core.settings:get("railbuilder.light_above") ~= nil)
		T.assert(core.settings:get("railbuilder.station_every") ~= nil)
	end)
end

------------------------------------------------------------------------------
-- Integration: run the bot for real on mineclonia.
-- All state lives in S so step closures can share it.
------------------------------------------------------------------------------

local S = {
	dir = {x = 1, z = 0},
	start = nil,
	rail_y = nil,
	ec_pos = nil,
	cleared = {},   -- column -> true if rail_y-1 was dug to air
	skipped = {},   -- column -> true if it has an undiggable obstruction
}

local function is_airlike(name)
	return name == nil or name == "air" or name == "ignore"
end

local function find_item_slot(name, listname)
	local inv = core.get_inventory("current_player")
	if not inv then return nil end
	local list = inv[listname or "main"]
	if not list then return nil end
	for i, s in ipairs(list) do
		if not s:is_empty() and s:get_name() == name then
			return i
		end
	end
	return nil
end

local function count_main(name)
	local total = 0
	local inv = core.get_inventory("current_player")
	if inv and inv.main then
		for _, s in ipairs(inv.main) do
			if not s:is_empty() and s:get_name() == name then
				total = total + s:get_count()
			end
		end
	end
	return total
end

local function ender_empty_slot(inv)
	if not inv or not inv.enderchest then return nil end
	for i, s in ipairs(inv.enderchest) do
		if s:is_empty() then return i end
	end
	return nil
end

local function find_placed_enderchest()
	if not core.localplayer then return nil end
	local lp = core.localplayer:get_pos()
	local found = core.find_nodes_near(lp, 6,
		{"mcl_chests:ender_chest", "mcl_chests:ender_chest_small"}, true)
	if not found or #found == 0 then return nil end
	table.sort(found, function(a, b)
		return vector.distance(lp, a) < vector.distance(lp, b)
	end)
	return found[1]
end

-- Sequential step runner. Each step calls done(ok, err) (possibly async);
-- steps run 0.25s apart under a shared deadline.
local function run_steps(steps, on_done, timeout)
	local i = 0
	local deadline = os.clock() + (timeout or 150)
	local function next_step()
		i = i + 1
		local step = steps[i]
		if not step then return on_done(true) end
		if os.clock() > deadline then
			return on_done(false, "setup timed out at '" .. step.label .. "'")
		end
		if not core.localplayer then
			return on_done(false, "player left during '" .. step.label .. "'")
		end
		local ok, err = pcall(step.fn, function(dok, msg)
			if dok then
				core.after(0.25, next_step)
			else
				on_done(false, step.label .. ": " .. tostring(msg))
			end
		end)
		if not ok then
			on_done(false, step.label .. " errored: " .. tostring(err))
		end
	end
	core.after(0.2, next_step)
end

-- Wait until a dropped item is back in the main inventory; teleports the
-- player onto the drop position briefly if the pickup does not happen.
local function wait_pickup(name, base, drop_pos, timeout, done)
	local deadline = os.clock() + (timeout or 10)
	local nudged = false
	local return_pos = core.localplayer and core.localplayer:get_pos()
	local function poll()
		if count_main(name) > base then
			if return_pos and core.localplayer then
				core.localplayer:set_pos(return_pos)
			end
			return done(true)
		end
		if not core.localplayer or os.clock() > deadline then
			if return_pos and core.localplayer then
				core.localplayer:set_pos(return_pos)
			end
			return done(true)
		end
		if not nudged and drop_pos and os.clock() > deadline - 3 then
			nudged = true
			core.localplayer:set_pos(vector.add(drop_pos, {x = 0, y = 0.5, z = 0}))
		end
		core.after(0.3, poll)
	end
	core.after(0.4, poll)
end

-- Place a shulker, move contents into it, dig it: the recovered item keeps
-- its contents. done(ok, err) with the filled kit back in main.
local function build_kit(shulker_name, contents, done)
	local pos = sbots.place_in_air(shulker_name)
	if not pos then return done(false, "could not place " .. shulker_name) end
	sbots.open_container(pos)
	local cloc = "nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z

	local idx = 0
	local function give_next()
		idx = idx + 1
		local entry = contents[idx]
		if not entry then
			-- Everything moved in: break the shulker to recover it as item.
			local base = count_main(shulker_name)
			ws.dig(pos)
			return wait_pickup(shulker_name, base, pos, 10, function()
				done(true)
			end)
		end
		local slot = find_item_slot(entry.name)
		if not slot then
			return done(false, "missing " .. entry.name .. " for " .. shulker_name)
		end
		ws.move_stack("current_player", "main", slot, cloc, "main", idx, entry.count)
		core.after(0.3, give_next)
	end

	-- Wait for the node inventory to sync after placement, then fill it.
	local tries = 0
	local function wait_inv()
		local kinv = core.get_inventory(cloc)
		if kinv then
			return core.after(0.4, give_next)
		end
		tries = tries + 1
		if tries > 10 then
			return done(false, "kit node inventory never synced")
		end
		sbots.open_container(pos)
		core.after(0.4, wait_inv)
	end
	core.after(0.5, wait_inv)
end

-- Move both kit shulkers from main into the ender chest list.
local function move_kits_into_enderchest(done)
	local function loop()
		if not core.localplayer then return done(false, "player left") end
		local inv = core.get_inventory("current_player")
		local slot = inv and (find_item_slot(RAILKIT) or find_item_slot(STATIONKIT))
		if slot then
			local eslot = ender_empty_slot(inv)
			if not eslot then return done(false, "ender chest list full") end
			ws.move_stack("current_player", "main", slot,
				"current_player", "enderchest", eslot)
			return core.after(0.3, loop)
		end
		if find_item_slot(RAILKIT, "enderchest")
				and find_item_slot(STATIONKIT, "enderchest") then
			return done(true)
		end
		done(false, "kits did not reach the ender chest")
	end
	core.after(0.3, loop)
end

-- Dig out rail_y-1 .. rail_y+2 along columns 2..12 so the bot has to place
-- its own redstone supports there. Columns with undiggable obstructions are
-- marked skipped and excluded from assertions.
local function clear_corridor(done)
	local targets = {}
	for i = CORRIDOR_FROM, CORRIDOR_TO do
		for dy = 0, 3 do
			table.insert(targets, {pos = {
				x = S.start.x + S.dir.x * i,
				y = S.rail_y - 1 + dy,
				z = S.start.z + S.dir.z * i,
			}, col = i})
		end
	end
	local idx = 0
	local function dig_batch()
		if not core.localplayer then return done(false, "player left") end
		for _ = 1, 6 do
			idx = idx + 1
			local t = targets[idx]
			if not t then break end
			local nd = core.get_node_or_nil(t.pos)
			if nd and not is_airlike(nd.name) then
				if ws.is_diggable(t.pos) then
					ws.dig(t.pos)
					if t.pos.y == S.rail_y - 1 then
						S.cleared[t.col] = true
					end
				else
					S.skipped[t.col] = true
				end
			end
		end
		if idx < #targets then
			return core.after(0.25, function() dig_batch() end)
		end
		done(true)
	end
	core.after(0.2, function() dig_batch() end)
end

-- Poll until the rail line exists; done(ok, msg).
local function verify_line(done)
	local deadline = os.clock() + 150
	local function column_pos(i)
		return {
			x = S.start.x + S.dir.x * i,
			y = S.rail_y,
			z = S.start.z + S.dir.z * i,
		}
	end
	local function check_all()
		local failure
		for i = 0, LINE_COLUMNS do
			if not S.skipped[i] then
				local c = column_pos(i)
				local rn = core.get_node_or_nil(c)
				if not (rn and RAILS[rn.name]) then
					failure = failure or ("rail missing at column " .. i
						.. " (" .. dump(rn and rn.name) .. ")")
				end
				local sn = core.get_node_or_nil({x = c.x, y = c.y - 1, z = c.z})
				if not sn or is_airlike(sn.name) then
					failure = failure or ("support missing at column " .. i)
				elseif i >= CORRIDOR_FROM and S.cleared[i]
						and sn.name ~= REDSTONE then
					failure = failure or ("support at column " .. i .. " is "
						.. sn.name .. ", expected " .. REDSTONE)
				end
			end
		end
		for _, i in ipairs(LINE_LIGHTS) do
			if not S.skipped[i] then
				local c = column_pos(i)
				local ln = core.get_node_or_nil(
					{x = c.x, y = S.rail_y + 2, z = c.z})
				local def = ln and core.get_node_def(ln.name)
				if not (def and (def.light_source or 0) >= LIGHT_MIN) then
					failure = failure or ("light post missing at column " .. i
						.. " (" .. dump(ln and ln.name) .. ")")
				end
			end
		end
		return failure
	end
	local function poll()
		if not core.localplayer then return done(false, "player left") end
		local failure = check_all()
		if not failure then
			-- Also confirm the bot actually advanced along the line.
			local lp = core.localplayer:get_pos()
			local advanced = (lp.x - S.start.x) * S.dir.x
				+ (lp.z - S.start.z) * S.dir.z
			if advanced < 2.5 then
				failure = "bot did not advance along the line ("
					.. string.format("%.1f", advanced) .. ")"
			end
		end
		if not failure then return done(true) end
		if os.clock() > deadline then
			return done(false, "line incomplete after deadline: " .. failure)
		end
		core.after(1, poll)
	end
	core.after(2, poll)
end

-- Second activation with an emptied inventory: the bot must restock from the
-- railkit in the ender chest and keep building.
local function restock_cycle(done)
	-- Furthest built column at this moment.
	local furthest = 0
	for i = 0, 32 do
		local rn = core.get_node_or_nil({
			x = S.start.x + S.dir.x * i,
			y = S.rail_y,
			z = S.start.z + S.dir.z * i,
		})
		if rn and RAILS[rn.name] then
			furthest = i
		end
	end

	core.settings:set_bool("railbuilder", false)
	core.after(1.5, function()
		-- Move all building materials out of main (into the ender chest
		-- list) so the bot has to restock.
		local zero_deadline = os.clock() + 20
		local function zero_one()
			if not core.localplayer then return done(false, "player left") end
			local inv = core.get_inventory("current_player")
			local eslot = ender_empty_slot(inv)
			if inv then
				for i, s in ipairs(inv.main) do
					if not s:is_empty() and (s:get_name() == RAIL
							or s:get_name() == REDSTONE
							or s:get_name() == LIGHT_ITEM) then
						if not eslot then
							return done(false, "ender chest list full")
						end
						ws.move_stack("current_player", "main", i,
							"current_player", "enderchest", eslot)
						if os.clock() > zero_deadline then
							return done(false, "zeroing timed out")
						end
						return core.after(0.25, function() zero_one() end)
					end
				end
			end
			-- Inventory zeroed: re-enable and verify restock + resume.
			core.after(0.5, function()
				core.settings:set_bool("railbuilder", true)
				local vdeadline = os.clock() + 120
				local function poll()
					if not core.localplayer then return done(false, "player left") end
					local rails = ws.count_item(RAIL)
					local c1 = core.get_node_or_nil({
						x = S.start.x + S.dir.x * (furthest + 1),
						y = S.rail_y,
						z = S.start.z + S.dir.z * (furthest + 1)})
					local c2 = core.get_node_or_nil({
						x = S.start.x + S.dir.x * (furthest + 2),
						y = S.rail_y,
						z = S.start.z + S.dir.z * (furthest + 2)})
					local kit_back = find_item_slot(RAILKIT, "enderchest")
					if rails > 0 and kit_back and c1 and RAILS[c1.name]
							and c2 and RAILS[c2.name] then
						return done(true)
					end
					if os.clock() > vdeadline then
						return done(false, string.format(
							"restock incomplete: rails=%d, kit_in_ec=%s, col%d=%s, col%d=%s",
							rails, tostring(kit_back ~= nil),
							furthest + 1, dump(c1 and c1.name),
							furthest + 2, dump(c2 and c2.name)))
					end
					core.after(1, poll)
				end
				core.after(1, poll)
			end)
		end
		zero_one()
	end)
end

local function run_setup_steps()
	local steps = {
		{label = "give materials", fn = function(done)
			local idx = 0
			local function give_next()
				idx = idx + 1
				local entry = GIVE_ITEMS[idx]
				if not entry then return done(true) end
				core.send_chat_message("/giveme " .. entry[1] .. " " .. entry[2])
				core.after(0.4, give_next)
			end
			give_next()
		end},

		{label = "build railkit", fn = function(done)
			build_kit(RAILKIT, KIT_RAIL_CONTENTS, done)
		end},

		{label = "build stationkit", fn = function(done)
			build_kit(STATIONKIT, KIT_STATION_CONTENTS, done)
		end},

		{label = "place ender chest", fn = function(done)
			-- Behind the line start: out of the corridor, within the restock
			-- job's find range. It is found (not placed) by the restock job,
			-- so it is never consumed.
			local candidate = {x = S.start.x - 3, y = S.rail_y - 1, z = S.start.z}
			if ws.place(candidate, ENDER_CHEST) then
				sbots.open_container(candidate)
			else
				local p = sbots.place_in_air(ENDER_CHEST)
				if not p then return done(false, "could not place ender chest") end
				sbots.open_container(p)
			end
			core.after(0.6, function() done(true) end)
		end},

		{label = "move kits into ender chest", fn = function(done)
			move_kits_into_enderchest(done)
		end},

		{label = "clear corridor", fn = function(done)
			clear_corridor(done)
		end},

		{label = "enable bot", fn = function(done)
			core.settings:set_string("railbuilder.direction", "+x")
			core.settings:set("railbuilder.redstone_sparsity", "1")
			core.settings:set("railbuilder.light_every", "8")
			core.settings:set("railbuilder.light_above", "3")
			core.settings:set("railbuilder.min_light", tostring(LIGHT_MIN))
			core.settings:set("railbuilder.station_every", "200")
			core.settings:set_bool("railbuilder", true)
			core.after(0.5, function() done(true) end)
		end},
	}

	return steps
end

local function railbot_run_integration(T)
	-- Wait until the player is settled on the ground, capture the anchor,
	-- then run setup -> line verification -> restock verification.
	local tries = 0
	local function wait_ground()
		local lp = core.localplayer
		if not (lp and lp:is_touching_ground()) then
			tries = tries + 1
			if tries > 30 then
				T.finish("railbot runs and builds a rail line", false,
					"player never touched the ground")
				T.report()
				return
			end
			return core.after(0.5, wait_ground)
		end

		local pos = lp:get_pos()
		S.start = {x = math.floor(pos.x + 0.5), z = math.floor(pos.z + 0.5)}
		S.rail_y = math.floor(pos.y + 0.5)
		core.log("action", "[AL_TEST] railbot start ("
			.. S.start.x .. "," .. S.rail_y .. "," .. S.start.z .. ")")

		run_steps(run_setup_steps(), function(ok, msg)
			if not ok then
				T.finish("railbot runs and builds a rail line", false, msg)
				core.settings:set_bool("railbuilder", false)
				T.report()
				return
			end
			verify_line(function(vok, vmsg)
				T.finish("railbot runs and builds a rail line", vok, vmsg)
				if not vok then
					core.settings:set_bool("railbuilder", false)
					T.report()
					return
				end
				restock_cycle(function(rook, rmsg)
					T.finish("railbot restocks from the kit", rook,
						rook and nil or rmsg)
					core.settings:set_bool("railbuilder", false)
					T.report()
				end)
			end)
		end, 240)
	end
	core.after(1, wait_ground)
end

function test_railbot_integration(T)
	if not core.get_item_def(RAIL) then
		core.log("info", "[AL_TEST] SKIP: railbot integration (mineclonia only)")
		return
	end
	if type(sbots) ~= "table" or not sbots.refill_materials then
		core.log("info", "[AL_TEST] SKIP: railbot integration (sbots not loaded)")
		return
	end
	T.defer("railbot integration setup", function()
		railbot_run_integration(T)
	end)
end
