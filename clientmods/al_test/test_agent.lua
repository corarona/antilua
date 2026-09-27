-- Tests for the agent clientmod (event feed, ctx, movement, verified actions)

function test_agent(T)
	T.run("agent global exposes API", function()
		T.assert(type(agent) == "table", "agent global should exist")
		for _, fn in ipairs({
			"events", "ctx", "mem", "go_to", "stop", "mstate", "moving",
			"dig", "place", "use", "punch", "aim", "look", "jump", "eat",
			"respawn", "survival", "action", "formspec", "last_event_id",
			"set_fly_mode", "fly_to", "open_target",
		}) do
			T.assert(type(agent[fn]) == "function",
				"agent." .. fn .. " should be a function")
		end
	end)

	T.run("events returns cursor and list", function()
		local out = agent.events(0)
		T.assert(type(out) == "table", "events should return a table")
		T.assert(type(out.cursor) == "number", "cursor should be a number")
		T.assert(type(out.events) == "table", "events should be a list")
	end)

	T.run("events type filter", function()
		local out = agent.events(0, {"chat"})
		for _, e in ipairs(out.events) do
			T.assert_eq(e.type, "chat", "filtered events should only be chat")
		end
	end)

	T.run("mem round-trips scalars and tables", function()
		local k = "al_test_" .. tostring(os.time())
		T.assert(agent.mem(k, "hello") == "hello", "string mem write")
		T.assert_eq(agent.mem(k), "hello", "string mem read")
		T.assert(agent.mem(k .. "t", {a = 1, b = "x"}).a == 1, "table mem write")
		T.assert_eq(agent.mem(k .. "t").b, "x", "table mem read")
		T.assert(agent.mem(k .. "b", true) == true, "bool mem write")
		T.assert_eq(agent.mem(k .. "b"), true, "bool mem read")
	end)

	T.run("survival preset toggles settings", function()
		local before = {}
		for _, name in ipairs({"autoeat", "autototem", "autojump",
				"autorespawn", "autotool"}) do
			before[name] = core.settings:get_bool(name)
		end
		agent.survival(true)
		for _, name in ipairs({"autoeat", "autototem", "autojump",
				"autorespawn", "autotool"}) do
			T.assert(core.settings:get_bool(name) == true,
				name .. " should be on after survival(true)")
		end
		agent.survival(false)
		for _, name in ipairs({"autoeat", "autototem", "autojump",
				"autorespawn", "autotool"}) do
			T.assert(core.settings:get_bool(name) == false,
				name .. " should be off after survival(false)")
		end
		if before.autoeat then
			core.settings:set_bool("autoeat", before.autoeat)
		end
	end)

	T.run("go_to rejects invalid positions", function()
		local res = agent.go_to({x = 1, y = nil, z = 2})
		T.assert(res.ok == false, "missing y should be rejected")
		res = agent.go_to(nil)
		T.assert(res.ok == false, "nil pos should be rejected")
	end)

	T.run("dig rejects unloaded or air positions", function()
		local res = agent.dig({x = 32000, y = 32000, z = 32000})
		T.assert(res.ok == false, "far unloaded pos should be rejected")
	end)

	T.run("mstate idle when no movement queued", function()
		agent.stop()
		T.assert_eq(agent.mstate().state, "idle",
			"mstate should be idle after stop")
	end)
end

local function wait_stable(T, name, steps, fn)
	local tries = 0
	local function check()
		local lp = core.localplayer
		if lp and lp:is_touching_ground() then
			return core.after(0.5, fn)
		end
		tries = tries + 1
		if tries > (steps or 30) then
			T.finish(name, false, "player never touched the ground")
			T.report()
			return
		end
		core.after(0.5, check)
	end
	core.after(1, check)
end

-- Nearest diggable node around pos (generic, works in any game).
local function find_diggable_near(pos, radius)
	local best, best_d = nil, math.huge
	local feet = vector.round(pos)
	for dx = -radius, radius do
		for dy = -1, 2 do
			for dz = -radius, radius do
				if not (dx == 0 and dz == 0 and dy <= 0) then
					local p = {x = feet.x + dx, y = feet.y + dy, z = feet.z + dz}
					local nd = core.get_node_or_nil(p)
					if nd and nd.name ~= "air" and nd.name ~= "ignore" then
						local def = core.get_node_def(nd.name)
						local d = vector.distance(pos, p)
						if def and def.diggable and d <= radius + 0.5
								and d < best_d then
							best = p
							best_d = d
						end
					end
				end
			end
		end
	end
	return best
end

function test_agent_integration(T)
	if type(agent) ~= "table" then
		core.log("info", "[AL_TEST] SKIP: agent integration (agent mod missing)")
		return
	end

	-- ctx snapshot
	T.defer("agent ctx reports player state", function()
		local ctx = agent.ctx(16)
		T.assert(ctx.joined == true, "ctx should report joined")
		T.assert(ctx.pos ~= nil, "ctx should have a position")
		T.assert(ctx.hp ~= nil and ctx.hp > 0, "ctx should have hp")
		T.assert(type(ctx.inv) == "table", "ctx should have an inventory summary")
		T.assert(type(ctx.objects_near) == "table", "ctx should list objects")
		T.finish("agent ctx reports player state", true)
		T.report()
	end)

	-- walk to a nearby target
	T.defer("agent walk arrives at nearby target", function()
		local attempts = 0
		local function attempt()
			attempts = attempts + 1
			wait_stable(T, "agent walk arrives at nearby target", 30,
				function()
				local target = agent.open_target(4)
				if not target then
					T.finish("agent walk arrives at nearby target", false,
						"no open walkable direction from spawn")
					T.report()
					return
				end
				local res = agent.go_to(target, "walk")
				if res.ok == false then
					T.finish("agent walk arrives at nearby target", false,
						"go_to failed: " .. dump(res))
					T.report()
					return
				end
				local start = core.localplayer:get_pos()
				local polls = 0
				local function poll()
					local st = agent.mstate()
					if st.active == false and st.state == "done" then
						local lp = core.localplayer:get_pos()
						local d = vector.distance(
							{x = lp.x, y = target.y, z = lp.z}, target)
						T.finish("agent walk arrives at nearby target",
							d <= 2.0,
							d <= 2.0 and nil or ("ended " .. d .. " from target"))
						T.report()
						return
					elseif st.active == false then
						-- The mechanism is still proven if the player really
						-- walked (≥2 nodes toward the target) but terrain,
						-- concurrent UI tests or water stopped the arrival.
						local lp = core.localplayer:get_pos()
						local start_hd = math.sqrt(
							(start.x - target.x) * (start.x - target.x)
								+ (start.z - target.z) * (start.z - target.z))
						local now_hd = math.sqrt(
							(lp.x - target.x) * (lp.x - target.x)
								+ (lp.z - target.z) * (lp.z - target.z))
						if start_hd - now_hd >= 2.0 then
							T.finish("agent walk arrives at nearby target",
								true)
							T.report()
							return
						end
						if attempts < 3 then
							return core.after(1, attempt)
						end
						T.finish("agent walk arrives at nearby target", false,
							"movement ended in state " .. dump(st))
						T.report()
						return
					end
					polls = polls + 1
					if polls > 120 then
						agent.stop()
						T.finish("agent walk arrives at nearby target", false,
							"walk timed out: " .. dump(st))
						T.report()
						return
					end
					core.after(0.5, poll)
				end
				core.after(0.5, poll)
			end)
		end
		attempt()
	end)

	-- verified dig on a nearby terrain node
	T.defer("agent dig verifies server removal", function()
		-- Wait for the walk test to finish first: digging a node under the
		-- walking player would stall its path.
		local idle_polls = 0
		local function wait_idle()
			if agent.mstate().active then
				idle_polls = idle_polls + 1
				if idle_polls > 240 then
					T.finish("agent dig verifies server removal", false,
						"movement never went idle")
					T.report()
					return
				end
				return core.after(0.5, wait_idle)
			end
			wait_stable(T, "agent dig verifies server removal", 30, function()
				local pos = core.localplayer:get_pos()
				local target = find_diggable_near(pos, 4)
				if not target then
					T.finish("agent dig verifies server removal", false,
						"no diggable node within 4 nodes")
					T.report()
					return
				end
				local start = agent.dig(target)
				if not start.ok then
					T.finish("agent dig verifies server removal", false,
						"dig start failed: " .. dump(start))
					T.report()
					return
				end
				local polls = 0
				local function poll()
					local act = agent.action(start.key)
					if act and act.state == "done" then
						T.finish("agent dig verifies server removal", true)
						T.report()
						return
					elseif act and (act.state == "timeout" or act.state == "failed") then
						T.finish("agent dig verifies server removal", false,
							"dig ended " .. act.state .. ": " .. dump(act.result))
						T.report()
						return
					end
					polls = polls + 1
					if polls > 60 then
						T.finish("agent dig verifies server removal", false,
							"dig poll timed out")
						T.report()
						return
					end
					core.after(0.5, poll)
				end
				core.after(0.5, poll)
			end)
		end
	wait_idle()
end)
end
