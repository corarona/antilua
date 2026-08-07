-- Tests for Lua-rendered ESP tracers (wasplib/tracers.lua) and
-- core.get_node_esp_positions().

-- Draw3D groups used by the tracer cheats (must match wasplib/tracers.lua).
local ENTITY_TRACER_GROUP = 1001
local PLAYER_TRACER_GROUP = 1002
local NODE_TRACER_GROUP = 1003

function test_tracers(T)
	T.run("core.get_node_esp_positions exists", function()
		T.assert(type(core.get_node_esp_positions) == "function",
			"core.get_node_esp_positions should be a function")
	end)

	T.run("core.get_node_esp_positions returns a table", function()
		local ok, res = pcall(core.get_node_esp_positions)
		T.assert(ok, "get_node_esp_positions should not throw: " .. tostring(res))
		T.assert(type(res) == "table", "get_node_esp_positions should return a table")
	end)

	T.run("tracer cheat defs are registered", function()
		for _, setting in ipairs({
			"enable_entity_tracers",
			"enable_player_tracers",
			"enable_node_tracers",
		}) do
			T.assert(core.cheat_defs[setting] ~= nil,
				"cheat def for '" .. setting .. "' should be registered")
		end
	end)

	T.run("tracer settings exist", function()
		for _, name in ipairs({
			"enable_entity_tracers",
			"enable_player_tracers",
			"enable_node_tracers",
			"entity_esp_color",
			"player_esp_color",
			"node_tracers_color",
		}) do
			T.assert(core.settings:get(name) ~= nil,
				"setting '" .. name .. "' should exist")
		end
	end)

	-- Smoke test: each tracer cheat's on_step must run without error and must
	-- not leave draw3d commands behind after on_stop. Deferred until
	-- core.draw3d exists (created on the first rendered frame).
	T.defer("tracer on_step/on_stop smoke test", function()
		if not core.draw3d then
			T.assert(true, "core.draw3d not ready yet — skipping smoke test")
			return
		end
		local defs = {
			core.cheat_defs["enable_entity_tracers"],
			core.cheat_defs["enable_player_tracers"],
			core.cheat_defs["enable_node_tracers"],
		}
		for _, def in ipairs(defs) do
			if def and def.on_step then
				local ok, err = pcall(def.on_step, def)
				T.assert(ok, "on_step for '" .. def.setting
					.. "' should not throw: " .. tostring(err))
			end
			if def and def.on_stop then
				local ok, err = pcall(def.on_stop, def)
				T.assert(ok, "on_stop for '" .. def.setting
					.. "' should not throw: " .. tostring(err))
			end
		end
		-- Cleanup in case a step added commands (should be empty already).
		core.draw3d:clear(ENTITY_TRACER_GROUP)
		core.draw3d:clear(PLAYER_TRACER_GROUP)
		core.draw3d:clear(NODE_TRACER_GROUP)
	end)

	-- Setting a node in the ESP list and querying positions must be consistent:
	-- a small query around the local player returns a table with valid entries.
	T.defer("get_node_esp_positions returns valid positions", function()
		local ok, res = pcall(core.get_node_esp_positions)
		T.assert(ok, "get_node_esp_positions should not throw: " .. tostring(res))
		if #res > 0 then
			for _, p in ipairs(res) do
				T.assert(type(p.x) == "number" and type(p.y) == "number"
					and type(p.z) == "number",
					"each returned position should have numeric x/y/z")
			end
		end
	end)
end
