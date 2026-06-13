-- Tunnel/bulk digging cheats (from scaffold: DigHead, Excavator, TBM, etc.)

local function get_width()
	return tonumber(core.settings:get("dig.width")) or 5
end

local function get_depth()
	return tonumber(core.settings:get("dig.depth")) or 1
end

local function excavate(condition)
	local lp = ws.dircoord(0, 0, 0)
	local width = get_width()
	local depth = get_depth()
	local maxv = math.max(width, depth)
	for a = -depth, depth - 1 do
		local n = math.floor(width / 2)
		for b = -n, n do
			local v = ws.dircoord(1, a, b)
			if condition == nil or condition(v) then
				local nd = core.get_node_or_nil(v)
				local dst = vector.distance(lp, v)
				ws.dig(v)
				if dst < maxv and (not nd or nd.name ~= "air") then
					core.settings:set_bool("continuous_forward", false)
				end
			end
		end
	end
end

ws.rg("DigHead", {
	category = "Dig",
	setting = "dighead",
	description = "Dig in front of your head",
	on_step = function()
		ws.dig(ws.dircoord(0, 1, 0))
	end,
})

ws.rg("Excavator", {
	category = "Dig",
	setting = "excavator",
	description = "Dig a large excavation area",
	on_step = function(self)
		local mode = core.settings:get(self.setting .. ".mode") or "normal"
		core.settings:set_bool("continuous_forward", true)
		-- Dig
		if mode == "full" then
			excavate(nil)
		else
			excavate(function(p) return p.y >= ws.dircoord(0, 0, 0).y end)
		end
		-- Place walls (TBM mode)
		if mode == "walls" then
			local width = tonumber(core.settings:get("dig.width")) or 5
			for f = -1, 1 do
				for y = 0, 5 do
					ws.place(ws.dircoord(f, y, -width - 1), nlist.get("TBM"))
					ws.place(ws.dircoord(f, y, width + 1), nlist.get("TBM"))
				end
			end
		end
	end,
	daughters = {"axissnap"},
	delay = 0.2,
	cheat_settings = {
		width = { type = "number", default = 5, min = 1, max = 50 },
		depth = { type = "number", default = 1, min = 1, max = 20 },
		mode = { type = "string", default = "normal", options = {"normal", "walls", "full"} },
	},
	on_start = function()
		core.settings:set("dig.width", tostring(tonumber(core.settings:get("dig.width")) or 5))
		core.settings:set("dig.depth", tostring(tonumber(core.settings:get("dig.depth")) or 1))
	end,
})

ws.rg("WallExcavator", {
	category = "Dig",
	setting = "wallexcavator",
	description = "Excavate walls in a pattern",
	on_step = function()
		core.settings:set_bool("continuous_forward", true)
		local lp = ws.dircoord(0, 0, 0)
		if tps_client and tps_client.ping and tps_client.ping > 1000 then
			core.settings:set_bool("continuous_forward", false)
			return
		end
		local width = get_width()
		local depth = get_depth()
		for a = -depth, depth do
			for b = -width, width do
				local v = ws.dircoord(1, a, b)
				local nd = core.get_node_or_nil(v)
				local dst = vector.distance(lp, v)
				if ws.inside_wall(v) then ws.dig(v) end
				if not ws.inside_wall(v) and dst < 2 and (not nd or nd.name ~= "air") then
					core.settings:set_bool("continuous_forward", false)
				end
			end
		end
	end,
	daughters = {"axissnap"},
	delay = 0.05,
})
