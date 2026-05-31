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
				local nd = minetest.get_node_or_nil(v)
				local dst = vector.distance(lp, v)
				ws.dig(v)
				if dst < maxv and (not nd or nd.name ~= "air") then
					minetest.settings:set_bool("continuous_forward", false)
				end
			end
		end
	end
end

ws.rg("DigHead", {
	category = "Dig",
	setting = "dighead",
	on_step = function()
		ws.dig(ws.dircoord(0, 1, 0))
	end,
})

ws.rg("Excavator", {
	category = "Dig",
	setting = "excavator",
	on_step = function()
		minetest.settings:set_bool("continuous_forward", true)
		excavate(function(p)
			return p.y >= ws.dircoord(0, 0, 0).y
		end)
	end,
	daughters = {"axissnap"},
	delay = 0.2,
	cheat_settings = {
		width = { type = "number", default = 5, min = 1, max = 50 },
		depth = { type = "number", default = 1, min = 1, max = 20 },
	},
	on_start = function()
		core.settings:set("dig.width", tostring(get_width()))
		core.settings:set("dig.depth", tostring(get_depth()))
	end,
})

ws.rg("TBM", {
	category = "Dig",
	setting = "excavator",
	on_step = function()
		minetest.settings:set_bool("continuous_forward", true)
		excavate(function(p)
			return p.y >= ws.dircoord(0, 0, 0).y
		end)
		local width = get_width()
		for f = -1, 1 do
			for y = 0, 5 do
				ws.place(ws.dircoord(f, y, -width - 1), nlist.get("TBM"))
				ws.place(ws.dircoord(f, y, width + 1), nlist.get("TBM"))
			end
		end
	end,
	daughters = {"axissnap"},
	delay = 0.2,
})

ws.rg("TExcavator", {
	category = "Dig",
	setting = "texcavator",
	on_step = function()
		minetest.settings:set_bool("continuous_forward", true)
		excavate()
	end,
	daughters = {"axissnap"},
	delay = 0.2,
})

ws.rg("WallExcavator", {
	category = "Dig",
	setting = "wallexcavator",
	on_step = function()
		minetest.settings:set_bool("continuous_forward", true)
		local lp = ws.dircoord(0, 0, 0)
		if tps_client and tps_client.ping and tps_client.ping > 1000 then
			minetest.settings:set_bool("continuous_forward", false)
			return
		end
		local width = get_width()
		local depth = get_depth()
		for a = -depth, depth do
			for b = -width, width do
				local v = ws.dircoord(1, a, b)
				local nd = minetest.get_node_or_nil(v)
				local dst = vector.distance(lp, v)
				if ws.inside_wall(v) then ws.dig(v) end
				if not ws.inside_wall(v) and dst < 2 and (not nd or nd.name ~= "air") then
					minetest.settings:set_bool("continuous_forward", false)
				end
			end
		end
	end,
	daughters = {"axissnap"},
	delay = 0.05,
})
