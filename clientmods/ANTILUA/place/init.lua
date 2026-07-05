-- CC0/Unlicense Emilia & cora 2020
-- place: world-building/block-placement cheats (renamed from scaffold)

scaffold = {}

function scaffold.setting(key)
	return tonumber(core.settings:get("place." .. key))
end

scaffold.in_cube = ws.in_cube
scaffold.can_place_at = ws.can_place_at
scaffold.can_place_wielded_at = ws.can_place_wielded_at
scaffold.find_any_swap = ws.find_any_swap
scaffold.in_list = ws.in_list

function scaffold.place_if_needed(items, pos, place)
	return ws.place_if_needed(items, pos, place)
end

function scaffold.place_if_able(pos)
	return ws.place_if_able(pos)
end

function scaffold.dig(pos)
	return ws.dig_if_able(pos)
end

local function inside_constraints(pos)
	return ws.inside_constraints(pos)
end

function scaffold.set_pos1(pos)
	ws.set_pos1(pos)
end

function scaffold.set_pos2(pos)
	ws.set_pos2(pos)
end

function scaffold.reset()
	ws.reset_constraints()
end

function scaffold.template(setting, func, offset, funcstop)
	offset = offset or {x = 0, y = -1, z = 0}
	funcstop = funcstop or function() end
	return function()
		if core.localplayer and core.settings:get_bool(setting) then
			local tgt = vector.add(core.localplayer:get_pos(), offset)
			if not inside_constraints(tgt) then return end
			func(tgt)
		end
	end
end

function scaffold.register_template_scaffold(name, setting, func, offset, funcstop, description)
	ws.rg(name, {
		category = "Place",
		setting = setting,
		description = description,
		on_step = scaffold.template(setting, func, offset),
		on_stop = funcstop,
	})
end
local mpath = core.get_modpath(core.get_current_modname())
dofile(mpath .. "/bot_tools.lua")
dofile(mpath .. "/spongebot.lua")
dofile(mpath .. "/greenup.lua")
dofile(mpath .. "/walls.lua")

local multiscaff_node = nil

local function mscaffold(f)
	f = f or 0
	if not multiscaff_node then return end
	local width = tonumber(core.settings:get("scaffold.width")) or 5
	local depth = tonumber(core.settings:get("scaffold.depth")) or 1
	local above = tonumber(core.settings:get("scaffold.above")) or 0
	local yf = -depth
	local yt = -1
	if above > 0 then
		yf = above
		yt = above + depth
	end
	local n = math.floor(width / 2)
	for fo = -2, 2 do
		for i = -n, n do
			for j = yf, yt do
				local p = ws.dircoord(fo, j, i)
				local nd = p and core.get_node_or_nil(p)
				if nd then
					ws.place(p, {multiscaff_node})
				end
			end
		end
	end
end

ws.rg('MultiScaff', { category = 'Place', setting = 'scaffold', description = "Build scaffold beneath you",
	on_step = function(self, dtime)
		if tps_client and tonumber(tps_client.ping) and tps_client.ping > (tps_client and tps_client.ping_tolerance or 0.5) then return end
		mscaffold(0)
	end,
	on_start = function(self)
		multiscaff_node = core.localplayer:get_wielded_item():get_name()
	end,
	on_stop = function(self)
	end,
	cheat_settings = {
		width = { type = "number", default = 5, min = 1, max = 50 },
		depth = { type = "number", default = 1, min = 1, max = 20 },
		above = { type = "number", default = 0, min = 0, max = 20 },
		mod  = { type = "number", default = 1, min = 1, max = 20 },
	},
})

ws.rg('MScaffModulo', { category = 'Place', setting = 'multiscaffm', description = "Scaffold with spaced placement",
	on_step = function(self)
		if not multiscaff_node then return end
		ws.switch_to_item(multiscaff_node)
		local width = tonumber(core.settings:get("multiscaffm.width")) or 5
		local depth = tonumber(core.settings:get("multiscaffm.depth")) or 1
		local mod = tonumber(core.settings:get("multiscaffm.mod")) or 1
		local n = math.floor(width / 2)
		for i = -n, n do
			for j = (depth * -1), -1 do
				local p = vector.round(ws.dircoord(0, j, i))
				if p.z % mod == 0 then
					if p.x % mod ~= 0 then
						core.place_node(p)
					end
				else
					if p.x % mod == 0 then
						core.place_node(p)
					end
				end
			end
		end
	end,
	on_start = function(self)
		multiscaff_node = core.localplayer:get_wielded_item():get_name()
	end,
	on_stop = function(self)
	end,
})



scaffold.register_template_scaffold("WallScaffold", "place_five_down", function(pos)
	scaffold.place_if_able(ws.dircoord(0, -1, 0))
	scaffold.place_if_able(ws.dircoord(0, -2, 0))
	scaffold.place_if_able(ws.dircoord(0, -3, 0))
	scaffold.place_if_able(ws.dircoord(0, -4, 0))
	scaffold.place_if_able(ws.dircoord(0, -5, 0))
end, nil, nil, "Place wall scaffold below")


scaffold.register_template_scaffold("headTriScaff", "place_three_wide_head", function(pos)
	scaffold.place_if_able(ws.dircoord(0, 3, 0))
	scaffold.place_if_able(ws.dircoord(0, 3, 1))
	scaffold.place_if_able(ws.dircoord(0, 3, -1))
end, nil, nil, "Place three-wide scaffold at head level")

scaffold.register_template_scaffold("RandomScaff", "place_rnd", function()
	local below=ws.dircoord(0,-1,0)
	local n = core.get_node_or_nil(below)
	local nl=nlist.get('randomscaffold')
	table.shuffle(nl)
	if n and not ws.in_list(n.name, nl) then
		scaffold.dig(below)
		scaffold.place_if_needed(nl, below)
	end
end, nil, nil, "Place random block scaffold")



local function is_lantern(pos)
   local dir=ws.getdir()
   pos=vector.round(pos)
   if dir == "north" or dir == "south" then
		if pos.z % 8 == 0 then
			return true
		end
   else
		if pos.x % 8 == 0 then
			return true
		end
   end
   return false
end

ws.rg("Highway", { category = "Place", setting = "highwaymaker", description = "Build a road beneath you",
	on_step = function(self)
		for i = -2, 2 do
			mscaffold(i)
			local lightblock = "mcl_ocean:sea_lantern"
			local dir = ws.getdir()
			local lp = vector.round(ws.dircoord(0, 0, 0))
			local pl = is_lantern(lp)
			if pl then
				local lpos = ws.dircoord(0, 3, 0)
				local nd = core.get_node_or_nil(lpos)
				if nd and nd.name ~= lightblock then
					ws.dig(lpos)
					ws.place(lpos, lightblock, 5)
				end
			end
		end
	end,
	on_start = function(self)
		core.settings:set("place.width", "5")
		core.settings:set("place.depth", "3")
		multiscaff_node = core.localplayer:get_wielded_item():get_name()
	end,
	daughters = {'block_sources'},
	delay = 0.05,
})

ws.rg("HighwayZ", { category = "Place", setting = "highwayz", description = "Build a road along the Z axis",
	on_step = function(self)
		local npt = ws.get_nodes_per_tick()
		local positions = {
			ws.dircoord(0, 0, 1),
			ws.dircoord(1, 0, 1),
			ws.dircoord(2, 1, 1),
			ws.dircoord(-2, 1, 1),
			ws.dircoord(-2, 0, 1),
			ws.dircoord(-1, 0, 1),
			ws.dircoord(2, 0, 1),
		}
		for i, p in pairs(positions) do
			if i > npt then break end
			if p then core.place_node(p) end
		end
	end,
})

ws.rg("BlockSources", {
	category = "Place",
	setting = "block_sources",
	description = "Block liquid sources while placing",
	on_step = function(self)
		local block_water = core.settings:get_bool(self.setting .. ".block_water", true)
		local block_lava = core.settings:get_bool(self.setting .. ".block_lava", true)
		local block_nether_lava = core.settings:get_bool(self.setting .. ".block_nether_lava", true)
		local use_wielded = core.settings:get_bool(self.setting .. ".use_wielded", false)
		local npt = ws.get_nodes_per_tick()
		local lp = ws.dircoord(0, 0, 0)
		local targets = {}
		if block_water then
			for _, v in ipairs({"mcl_core:water_source", "mcl_core:water_flowing"}) do
				table.insert(targets, v)
			end
		end
		if block_lava then
			for _, v in ipairs({"mcl_core:lava_source", "mcl_core:lava_flowing"}) do
				table.insert(targets, v)
			end
		end
		if block_nether_lava then
			for _, v in ipairs({"mcl_nether:nether_lava_source", "mcl_nether:nether_lava_flowing"}) do
				table.insert(targets, v)
			end
		end
		if #targets == 0 then return end
		local positions = core.find_nodes_near(lp, 5, targets, true)
		for i, p in pairs(positions) do
			if i > npt then return end
			if use_wielded then
				ws.place(p, multiscaff_node)
			else
				core.place_node(p)
			end
		end
	end,
	on_start = function(self)
		multiscaff_node = core.localplayer:get_wielded_item():get_name()
		if not multiscaff_node then return true end
	end,
	cheat_settings = {
		block_water = { type = "bool", default = true },
		block_lava = { type = "bool", default = true },
		block_nether_lava = { type = "bool", default = true },
		use_wielded = { type = "bool", default = false },
	},
})

ws.rg("PlaceOnTop", { category = "Place", setting = "place_on_top", description = "Place on top of pointed node",
	on_step = function(self)
		if not multiscaff_node then return end
		local npt = ws.get_nodes_per_tick()
		local lp = ws.dircoord(0, 0, 0)
		local item = core.localplayer:get_wielded_item():get_name()
		if not item then return end
		local positions = core.find_nodes_near_under_air_except(lp, 5, {multiscaff_node}, true)
		for i, p in pairs(positions) do
			if i > npt then break end
			ws.place(vector.add(p, {x = 0, y = 1, z = 0}), multiscaff_node)
		end
	end,
	on_start = function(self)
		if not core.localplayer then return true end
		local it = core.localplayer:get_wielded_item()
		if it.type ~= "node" then return true end
		multiscaff_node = it:get_name()
		if not multiscaff_node then return true end
		-- nodes_per_tick now read directly from settings
	end,
})



local lightblock = nil
ws.rg("LanternTBM", { category = "Place", setting = "place_ltbm", description = "Place lanterns on ceilings",
	on_step = function(self)
		local dir = ws.getdir()
		local lp = vector.round(ws.dircoord(0, 0, 0))
		local pl = is_lantern(lp)
		local ypos = tonumber(core.settings:get("place_ltbm.depth")) or 1
		if lightblock and pl then
			local lpos = ws.dircoord(0, ypos, 0)
			local nd = core.get_node_or_nil(lpos)
			if nd and nd.name ~= lightblock then
				ws.dig(lpos)
				ws.place(lpos, lightblock, 5)
			end
		end
	end,
	on_start = function(self)
		lightblock = core.localplayer:get_wielded_item():get_name()
	end,
	on_stop = function(self)
	end,
})

local mossable = {
	"mcl_core:stone",
	"mcl_core:diorite",
	"mcl_core:andesite",
	"mcl_core:granite",
}

ws.rg("AutoMoss", {
	category = "Place",
	setting = "automoss",
	description = "Auto-place mossy variants of blocks",
	on_step = function()
		local p = core.localplayer:get_pos()
		local pos1 = vector.offset(p, -4, -4, -4)
		local pos2 = vector.offset(p, 4, 4, 4)
		local moss = core.find_nodes_in_area_under_air(pos1, pos2, {"mcl_lush_caves:moss"})
		if moss and #moss > 0 then
			for _, v in pairs(moss) do
				local sp1 = vector.offset(v, -4, -4, -4)
				local sp2 = vector.offset(v, 4, 4, 4)
				local stonz = core.find_nodes_in_area_under_air(sp1, sp2, mossable)
				if stonz and #stonz > 0 then
					core.switch_to_item("mcl_bone_meal:bone_meal")
					core.place_node(v)
				end
			end
		end
	end,
})

