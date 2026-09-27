-- Oysterity session probe: one call that answers "where am I, is this account
-- new, what does the saved map cover, and what is the server telling me".
-- Run through the pipe:
--   skills/playing-the-game/scripts/send_lua.py skills/oysterity/scripts/probe.lua
-- The client Lua sandbox has no io/os.getenv, so per-account state (greeting
-- history, base) lives in skills/oysterity/state via state.py — ask it with
--   skills/oysterity/scripts/state.py get greetings_used

local lp = core.localplayer
if not lp then
	return {ok = false, error = "no local player yet (not joined)"}
end

local pos = lp:get_pos()
local ctx = agent and agent.ctx and agent.ctx(60) or {}

local function is_water(name)
	return name and (name:find("water") ~= nil or name:find("ocean") ~= nil)
end

local function hostile_near(radius)
	local out = {}
	for _, obj in ipairs(core.get_objects_inside_radius(pos, radius or 24)) do
		local ok, name = pcall(obj.get_name, obj)
		local okp, is_player = pcall(obj.is_player, obj)
		if ok and name and name ~= "" and not (okp and is_player) then
			local hp = 0
			pcall(function() hp = obj:get_hp() end)
			out[#out + 1] = {name = name, hp = hp}
		end
	end
	table.sort(out, function(a, b) return (a.hp or 0) > (b.hp or 0) end)
	return out
end

-- Server-provided lines (MOTD, version, population) arrive as chat on join.
local server_lines = {}
if mcp_chat and mcp_chat.recent then
	for _, line in ipairs(mcp_chat.recent(60)) do
		local text = line.text or ""
		if text:find("# Server", 1, true) or text:find("oysterity", 1, true)
				or text:find("anarchy", 1, true) then
			server_lines[#server_lines + 1] = text
		end
	end
end

local bm = core.al_bigmap
local bigmap = {
	available = bm ~= nil,
	save_dir = bm and bm.get_save_dir and bm.get_save_dir() or nil,
	coverage = bm and bm.get_coverage and bm.get_coverage() or nil,
	blocks = bm and bm.get_block_count and bm.get_block_count() or nil,
}
if bm and bm.get_pixel and pos then
	local px = math.floor(pos.x)
	local pz = math.floor(pos.z)
	bigmap.under_player = bm.get_pixel(px, pz)
	bigmap.here_saved = bigmap.under_player ~= nil
end

local ground
if pos then
	local below = core.get_node_or_nil({x = math.floor(pos.x), y = math.floor(pos.y) - 1,
			z = math.floor(pos.z)})
	ground = below and below.name or nil
	local head = core.get_node_or_nil(pos)
	bigmap.head_node = head and head.name or nil
	bigmap.in_water = is_water(ground) or is_water(bigmap.head_node)
end

return {
	ok = true,
	name = lp:get_name(),
	pos = pos and {x = math.floor(pos.x), y = math.floor(pos.y), z = math.floor(pos.z)} or nil,
	ground = ground,
	in_water = bigmap.in_water,
	hp = lp:get_hp(),
	breath = lp:get_breath(),
	dead = lp:get_hp() <= 0,
	ping = ctx.ping,
	tps = ctx.tps,
	day_count = ctx.day_count,
	brightness = ctx.brightness,
	wielded = ctx.wielded and ctx.wielded.name or nil,
	inv = ctx.inv,
	players_near = (function()
		local out = {}
		for _, obj in ipairs(ctx.objects_near or {}) do
			if obj.is_player and obj.name ~= lp:get_name() then
				out[#out + 1] = {name = obj.name, dist = math.floor(obj.dist or 0),
					pos = {x = math.floor(obj.pos.x), y = math.floor(obj.pos.y),
						z = math.floor(obj.pos.z)}}
			end
		end
		return out
	end)(),
	mobs_near = hostile_near(24),
	server_lines = server_lines,
	bigmap = bigmap,
	state_file = "skills/oysterity/state/" .. lp:get_name() .. ".json",
}
