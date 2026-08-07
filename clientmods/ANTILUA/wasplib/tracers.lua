-- Antilua — Entity/Player/Node tracer cheats
-- SPDX-License-Identifier: LGPL-2.1-or-later
--
-- Tracer lines are rendered from Lua via core.draw3d instead of the C++
-- DrawTracersAndESP pipeline step (which now only handles ESP hitbox boxes and
-- wallhack). Each cheat clears its group and re-adds lines every step while
-- enabled (delay = 0).

-- Draw3D group IDs, one per cheat so lines can be refreshed independently.
local ENTITY_TRACER_GROUP = 1001
local PLAYER_TRACER_GROUP = 1002
local NODE_TRACER_GROUP = 1003

-- Match the old C++ getActiveObjects range (1000 blocks).
local TRACER_RANGE = 1000

-- Read an "(R,G,B)" color setting into a draw3d color table. Alpha 200
-- matches the alpha the old C++ tracer lines used.
local function tracer_color(setting)
	local c = core.setting_get_pos(setting) or { x = 255, y = 255, z = 255 }
	return { r = c.x, g = c.y, b = c.z, a = 200 }
end

-- Tracer origin: camera position nudged slightly forward along the view
-- direction to avoid near-plane clipping (mirrors the old C++ tracer_origin).
local function tracer_origin()
	if not core.camera then
		return nil
	end
	local p = core.camera:get_pos()
	local look = core.camera:get_look_dir()
	return {
		x = p.x + look.x * 0.2,
		y = p.y + look.y * 0.2,
		z = p.z + look.z * 0.2,
	}
end

ws.rg("EntityTracers", {
	category = "Render",
	setting = "enable_entity_tracers",
	description = "Draw tracer lines to entities",
	delay = 0,
	on_step = function()
		if not core.draw3d then
			return
		end
		core.draw3d:clear(ENTITY_TRACER_GROUP)
		local origin = tracer_origin()
		if not origin then
			return
		end
		local color = tracer_color("entity_esp_color")
		for _, obj in ipairs(core.get_objects_inside_radius(origin, TRACER_RANGE)) do
			if not obj:is_player() and not obj:is_local_player() then
				core.draw3d:add_line(origin, obj:get_pos(), color, ENTITY_TRACER_GROUP)
			end
		end
	end,
	on_stop = function()
		core.draw3d:clear(ENTITY_TRACER_GROUP)
	end,
})

ws.rg("PlayerTracers", {
	category = "Render",
	setting = "enable_player_tracers",
	description = "Draw tracer lines to players",
	delay = 0,
	on_step = function()
		if not core.draw3d then
			return
		end
		core.draw3d:clear(PLAYER_TRACER_GROUP)
		local origin = tracer_origin()
		if not origin then
			return
		end
		local color = tracer_color("player_esp_color")
		for _, obj in ipairs(core.get_objects_inside_radius(origin, TRACER_RANGE)) do
			if obj:is_player() and not obj:is_local_player() then
				core.draw3d:add_line(origin, obj:get_pos(), color, PLAYER_TRACER_GROUP)
			end
		end
	end,
	on_stop = function()
		core.draw3d:clear(PLAYER_TRACER_GROUP)
	end,
})

ws.rg("NodeTracers", {
	category = "Render",
	setting = "enable_node_tracers",
	description = "Draw tracer lines to selected nodes",
	delay = 0,
	on_step = function()
		if not core.draw3d then
			return
		end
		core.draw3d:clear(NODE_TRACER_GROUP)
		if not core.camera then
			return
		end
		local cam = core.camera:get_pos()
		local color = tracer_color("node_tracers_color")
		for _, p in ipairs(core.get_node_esp_positions()) do
			core.draw3d:add_line(cam, p, color, NODE_TRACER_GROUP)
		end
	end,
	on_stop = function()
		core.draw3d:clear(NODE_TRACER_GROUP)
	end,
})
