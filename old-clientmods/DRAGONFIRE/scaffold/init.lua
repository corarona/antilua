-- CC0/Unlicense Emilia & cora 2020

scaffold = {}
scaffold.lockdir = false
scaffold.locky = false
scaffold.constrain1 = false
scaffold.constrain2 = false
local hwps = {}


function scaffold.template(setting, func, offset, funcstop )
	offset = offset or {x = 0, y = -1, z = 0}
	funcstop = funcstop or function() end

	return function()
		if minetest.localplayer and minetest.settings:get_bool(setting) then
			local tgt = vector.add(minetest.localplayer:get_pos(), offset)
			if scaffold.constrain1 and not inside_constraints(tgt) then return end
			func(tgt)
		end
	end
end

function scaffold.register_template_scaffold(name, setting, func, offset, funcstop)
	ws.rg(name,'Scaffold',setting,scaffold.template(setting, func, offset),funcstop )
end

scaffold.in_cube = ws.in_cube

local function set_hwp(name, pos)
	hwps[#hwps + 1] = ws.display_wp(pos, name)
end

function scaffold.set_pos1(pos)
	if not pos or pos == "" then
		pos = minetest.localplayer:get_pos()
	else
		pos = core.string_to_pos(pos)
		if not pos then return false, "invalid pos" end
	end
	scaffold.constrain1=vector.round(pos)
	local pstr=minetest.pos_to_string(scaffold.constrain1)
	set_hwp('scaffold_pos1 '..pstr,scaffold.constrain1)
	minetest.display_chat_message("scaffold pos1 set to "..pstr)
end
function scaffold.set_pos2(pos)
	if not pos or pos == "" then
		pos = minetest.localplayer:get_pos()
	else
		pos = core.string_to_pos(pos)
		if not pos then return false, "invalid pos" end
	end
	scaffold.constrain2=vector.round(pos)
	local pstr=minetest.pos_to_string(scaffold.constrain2)
	set_hwp('scaffold_pos2 '..pstr,scaffold.constrain2)
	minetest.display_chat_message("scaffold pos2 set to "..pstr)
end

function scaffold.reset()
	scaffold.constrain1=false
	scaffold.constrain2=false
	for k,v in pairs(hwps) do
		minetest.localplayer:hud_remove(v)
		table.remove(hwps,k)
	end
end

local function inside_constraints(pos)
	if (scaffold.constrain1 and scaffold.constrain2 and scaffold.in_cube(pos,scaffold.constrain1,scaffold.constrain2)) then return true
	elseif not scaffold.constrain1 then return true
	end
	return false
end

minetest.register_chatcommand("sc_pos1", { func = scaffold.set_pos1 })
minetest.register_chatcommand("sc_pos2", { func = scaffold.set_pos2 })
minetest.register_chatcommand("sc_reset", { func = scaffold.reset })




scaffold.can_place_at = ws.can_place_at
scaffold.can_place_wielded_at = ws.can_place_wielded_at
scaffold.find_any_swap = ws.find_any_swap
scaffold.in_list = ws.in_list

-- swaps to any of the items and places if need be
-- returns true if placed and in inventory or already there, false otherwise

function scaffold.place_if_needed(items, pos, place)
	if not inside_constraints(pos) then return end
	if not pos then return end

	place = place or minetest.place_node

	local node = minetest.get_node_or_nil(pos)
	if not node then return end
	-- already there
	if node and scaffold.in_list(node.name, items) then
		return true
	else
		local swapped = scaffold.find_any_swap(items)

		-- need to place
		if swapped and scaffold.can_place_at(pos) then
			--minetest.after("0.05",place,pos)
			place(pos)
			return true
		-- can't place
		else
			return false
		end
	end
end

function scaffold.place_if_able(pos)
	if not pos then return end
	if not inside_constraints(pos) then return end
	if scaffold.can_place_wielded_at(pos) then
		minetest.place_node(pos)
	end
end

function scaffold.dig(pos)
	if not inside_constraints(pos) then return false end
	return ws.dig(pos)
end


local mpath = minetest.get_modpath(minetest.get_current_modname())
--dofile(mpath .. "/sapscaffold.lua")
--dofile(mpath .. "/slowscaffold.lua")
dofile(mpath .. "/autofarm.lua")
dofile(mpath .. "/railscaffold.lua")
--dofile(mpath .. "/wallbot.lua")
--dofile(mpath .. "/ow2bot.lua")
--dofile(mpath .. "/canalbot.lua")
dofile(mpath .. "/bot_tools.lua")
dofile(mpath .. "/spongebot.lua")
dofile(mpath .. "/sbots.lua")
--dofile(mpath .. "/squarry.lua")
dofile(mpath .. "/greenup.lua")

ws.rg('DigHead', { category = 'Player', setting = 'dighead',
	on_step = function(self) ws.dig(ws.dircoord(0,1,0)) end,
})

local multiscaff_node = nil

local function mscaffold(f)
	f = f or 0
	if not multiscaff_node then return end
	local width = scaffold.setting("width") or 5
	local depth = scaffold.setting("depth") or 1
	local above = scaffold.setting("above") or 0
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
				local nd = p and minetest.get_node_or_nil(p)
				if nd then
					ws.place(p, {multiscaff_node})
				end
			end
		end
	end
end

ws.rg('PlaceOn', { category = 'Scaffold', setting = 'scaffold_placeon',
	on_step = function(self)
		local nds = minetest.find_nodes_near(ws.dircoord(0,0,0), ws.range, nlist.selected)
		for k, v in ipairs(nds) do
			ws.switch_to_item(multiscaff_node)
			minetest.place(vector.add(v, vector.new(0, 1, 0)))
		end
	end,
	on_start = function(self)
		multiscaff_node = minetest.localplayer:get_wielded_item():get_name()
		ws.dcm("PlaceOn started. Selected node: " .. multiscaff_node)
	end,
	on_stop = function(self)
		ws.dcm("PlaceOn stopped")
	end,
})

ws.rg('MultiScaff', { category = 'Scaffold', setting = 'scaffold',
	on_step = function(self, dtime)
		if tps_client and tonumber(tps_client.ping) and tps_client.ping > (tps_client and tps_client.ping_tolerance or 0.5) then return end
		mscaffold(0)
	end,
	on_start = function(self)
		multiscaff_node = minetest.localplayer:get_wielded_item():get_name()
		ws.dcm("Multiscaff started. Width: " .. (scaffold.setting("width") or 5) .. ", depth:" .. (scaffold.setting("depth") or 1) .. " Selected node: " .. multiscaff_node)
	end,
	on_stop = function(self)
		ws.dcm("Multiscaff stopped")
	end,
	cheat_settings = {
		width = { type = "number", default = 5, min = 1, max = 50 },
		depth = { type = "number", default = 1, min = 1, max = 20 },
		above = { type = "number", default = 0, min = 0, max = 20 },
		mod  = { type = "number", default = 1, min = 1, max = 20 },
	},
})

ws.rg('MScaffModulo', { category = 'Scaffold', setting = 'multiscaffm',
	on_step = function(self)
		if not multiscaff_node then return end
		ws.switch_to_item(multiscaff_node)
		local width = scaffold.setting("width") or 5
		local depth = scaffold.setting("depth") or 1
		local mod = scaffold.setting("mod") or 1
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
		multiscaff_node = minetest.localplayer:get_wielded_item():get_name()
		ws.dcm("ModuloScaff started. Width: " .. (scaffold.setting("width") or 5) .. ", depth:" .. (scaffold.setting("depth") or 1) .. " Selected node: " .. multiscaff_node)
	end,
	on_stop = function(self)
		ws.dcm("Moduloscaff stopped")
	end,
})



scaffold.register_template_scaffold("WallScaffold", "scaffold_five_down", function(pos)
	scaffold.place_if_able(ws.dircoord(0, -1, 0))
	scaffold.place_if_able(ws.dircoord(0, -2, 0))
	scaffold.place_if_able(ws.dircoord(0, -3, 0))
	scaffold.place_if_able(ws.dircoord(0, -4, 0))
	scaffold.place_if_able(ws.dircoord(0, -5, 0))
end)


scaffold.register_template_scaffold("headTriScaff", "scaffold_three_wide_head", function(pos)
	scaffold.place_if_able(ws.dircoord(0, 3, 0))
	scaffold.place_if_able(ws.dircoord(0, 3, 1))
	scaffold.place_if_able(ws.dircoord(0, 3, -1))
end)

scaffold.register_template_scaffold("RandomScaff", "scaffold_rnd", function()
	local below=ws.dircoord(0,-1,0)
	local n = minetest.get_node_or_nil(below)
	local nl=nlist.get('randomscaffold')
	table.shuffle(nl)
	if n and not ws.in_list(n.name, nl) then
		scaffold.dig(below)
		scaffold.place_if_needed(nl, below)
	end
end)

local function excavate(condition)
	local lp = ws.dircoord(0, 0, 0)
	local width = scaffold.setting("width") or 5
	local depth = scaffold.setting("depth") or 1
	local maxv = width
	if depth > width then maxv = depth end
	for a = -depth, depth - 1 do
		local n = math.floor(width / 2)
		for b = -n, n do
			local v = ws.dircoord(1, a, b)
			if condition == nil or condition(v) then
				local n = minetest.get_node_or_nil(v)
				local dst = vector.distance(lp, v)
				ws.dig(v)
				if dst < maxv and (not n or n.name ~= "air") then
					minetest.settings:set_bool('continuous_forward', false)
				end
			end
		end
	end
end

ws.rg('Excavator', { category = 'Diggers', setting = 'excavator',
	on_step = function(self)
		minetest.settings:set_bool('continuous_forward', true)
		excavate(function(p)
			return p.y >= ws.dircoord(0, 0, 0).y
		end)
	end,
	daughters = {'axissnap'},
	delay = 0.2,
})

ws.rg('TBM', { category = 'Diggers', setting = 'excavator',
	on_step = function(self)
		minetest.settings:set_bool('continuous_forward', true)
		excavate(function(p)
			return p.y >= ws.dircoord(0, 0, 0).y
		end)
		local width = scaffold.setting("width") or 5
		for f = -1, 1 do
			for y = 0, 5 do
				ws.place(ws.dircoord(f, y, -width - 1), nlist.get("TBM"))
				ws.place(ws.dircoord(f, y, width + 1), nlist.get("TBM"))
			end
		end
	end,
	daughters = {'axissnap'},
	delay = 0.2,
})

ws.rg('TExcavator', { category = 'Diggers', setting = 'texcavator',
	on_step = function(self)
		minetest.settings:set_bool('continuous_forward', true)
		excavate()
	end,
	daughters = {'axissnap'},
	delay = 0.2,
})

ws.rg('WallExcavator', { category = 'Diggers', setting = 'wallexcavator',
	on_step = function(self)
		minetest.settings:set_bool('continuous_forward', true)
		local lp = ws.dircoord(0, 0, 0)
		if tps_client and tps_client.ping and tps_client.ping > 1000 then
			minetest.settings:set_bool('continuous_forward', false)
			return
		end
		local width = scaffold.setting("width") or 5
		local depth = scaffold.setting("depth") or 1
		for a = -depth, depth do
			for b = -width, width do
				local v = ws.dircoord(1, a, b)
				local n = minetest.get_node_or_nil(v)
				local dst = vector.distance(lp, v)
				if ws.inside_wall(v) then ws.dig(v) end
				if not ws.inside_wall(v) and dst < 2 and (not n or n.name ~= "air") then
					minetest.settings:set_bool('continuous_forward', false)
				end
			end
		end
	end,
	daughters = {'axissnap'},
	delay = 0.05,
})

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

ws.rg("Highway", { category = "Scaffold", setting = "highwaymaker",
	on_step = function(self)
		for i = -2, 2 do
			mscaffold(i)
			local lightblock = "mcl_ocean:sea_lantern"
			local dir = ws.getdir()
			local lp = vector.round(ws.dircoord(0, 0, 0))
			local pl = is_lantern(lp)
			if pl then
				local lpos = ws.dircoord(0, 3, 0)
				local nd = minetest.get_node_or_nil(lpos)
				if nd and nd.name ~= lightblock then
					ws.dig(lpos)
					ws.place(lpos, lightblock, 5)
				end
			end
		end
	end,
	on_start = function(self)
		core.settings:set("scaffold.width", "5")
		core.settings:set("scaffold.depth", "3")
		multiscaff_node = minetest.localplayer:get_wielded_item():get_name()
	end,
	daughters = {'excavator', 'block_sources'},
	delay = 0.05,
})

ws.rg("HighwayZ", { category = "World", setting = "highwayz",
	on_step = function(self)
		local npt = tonumber(core.settings:get("nodes_per_tick")) or 8
		local positions = {
			{x = 0, y = 0, z = z},
			{x = 1, y = 0, z = z},
			{x = 2, y = 1, z = z},
			{x = -2, y = 1, z = z},
			{x = -2, y = 0, z = z},
			{x = -1, y = 0, z = z},
			{x = 2, y = 0, z = z}
		}
		for i, p in pairs(positions) do
			if i > npt then break end
			minetest.place_node(p)
		end
	end,
	on_start = function(self) end,
})

ws.rg("BlockWater", { category = "World", setting = "block_water",
	on_step = function(self)
		local npt = tonumber(core.settings:get("nodes_per_tick")) or 8
		local lp = ws.dircoord(0, 0, 0)
		local positions = minetest.find_nodes_near(lp, 5, {"mcl_core:water_source", "mcl_core:water_flowing"}, true)
		for i, p in pairs(positions) do
			if i > npt then return end
			minetest.place_node(p)
		end
	end,
	on_start = function(self)
		-- nodes_per_tick now read directly from settings
	end,
})

ws.rg("BlockLava", { category = "World", setting = "block_lava",
	on_step = function(self)
		local npt = tonumber(core.settings:get("nodes_per_tick")) or 8
		local lp = ws.dircoord(0, 0, 0)
		local positions = minetest.find_nodes_near(lp, 5, {"mcl_core:lava_source", "mcl_core:lava_flowing"}, true)
		for i, p in pairs(positions) do
			if i > npt then return end
			minetest.place_node(p)
		end
	end,
	on_start = function(self)
		-- nodes_per_tick now read directly from settings
	end,
})

ws.rg("BlockSources", { category = "World", setting = "block_sources",
	on_step = function(self)
		if not multiscaff_node then
			multiscaff_node = minetest.localplayer:get_wielded_item():get_name()
			return
		end
		local npt = tonumber(core.settings:get("nodes_per_tick")) or 8
		local lp = ws.dircoord(0, 0, 0)
		local positions = minetest.find_nodes_near(lp, 5, {"mcl_core:lava_source","mcl_nether:nether_lava_source","mcl_core:water_source"}, true)
		for i, p in pairs(positions) do
			if i > npt then return end
			if p.y < 2 then
				if p.x > 250 and p.z > 250 then return end
			end
			ws.place(p, multiscaff_node)
		end
	end,
	on_start = function(self)
		multiscaff_node = minetest.localplayer:get_wielded_item():get_name()
		if not multiscaff_node then return true end
		-- nodes_per_tick now read directly from settings
	end,
})

ws.rg("BlockLavaSources", { category = "World", setting = "block_lava_sources",
	on_step = function(self)
		if not multiscaff_node then return false end
		local npt = tonumber(core.settings:get("nodes_per_tick")) or 8
		local lp = ws.dircoord(0, 0, 0)
		local positions = minetest.find_nodes_near(lp, 5, {"mcl_core:lava_source","mcl_nether:nether_lava_source"}, true)
		for i, p in pairs(positions) do
			if i > npt then return end
			if p.y < 2 then
				if p.x > 250 and p.z > 250 then return end
			end
			ws.place(p, multiscaff_node)
		end
	end,
	on_start = function(self)
		multiscaff_node = minetest.localplayer:get_wielded_item():get_name()
		if not multiscaff_node then return true end
		-- nodes_per_tick now read directly from settings
	end,
})

ws.rg("PlaceOnTop", { category = "World", setting = "place_on_top",
	on_step = function(self)
		if not multiscaff_node then return end
		local npt = tonumber(core.settings:get("nodes_per_tick")) or 8
		local lp = ws.dircoord(0, 0, 0)
		local item = minetest.localplayer:get_wielded_item():get_name()
		if not item then return end
		local positions = minetest.find_nodes_near_under_air_except(lp, 5, {multiscaff_node}, true)
		for i, p in pairs(positions) do
			if i > npt then break end
			ws.place(vector.add(p, {x = 0, y = 1, z = 0}), multiscaff_node)
		end
	end,
	on_start = function(self)
		if not minetest.localplayer then return true end
		local it = minetest.localplayer:get_wielded_item()
		if it.type ~= "node" then return true end
		multiscaff_node = it:get_name()
		if not multiscaff_node then return true end
		-- nodes_per_tick now read directly from settings
	end,
})

ws.rg("Nuke", { category = "World", setting = "nuke",
	on_step = function(self)
		local npt = tonumber(core.settings:get("nodes_per_tick")) or 8
		local radius = tonumber(core.settings:get("nuke.radius")) or 4
		local pos = ws.dircoord(0, 0, 0)
		local i = 0
		for x = pos.x - radius, pos.x + radius do
			for y = pos.y - radius, pos.y + radius do
				for z = pos.z - radius, pos.z + radius do
					local p = vector.new(x, y, z)
					local node = minetest.get_node_or_nil(p)
					local def = node and minetest.get_node_def(node.name)
					if def and def.diggable then
						if i > npt then return end
						minetest.dig_node(p)
						i = i + 1
					end
				end
			end
		end
	end,
	on_start = function(self)
		-- nodes_per_tick now read directly from settings
	end,
	cheat_settings = {
		radius = { type = "number", default = 4, min = 1, max = 20 },
	},
})

local lightblock = nil
ws.rg("LanternTBM", { category = "Scaffold", setting = "scaffold_ltbm",
	on_step = function(self)
		local dir = ws.getdir()
		local lp = vector.round(ws.dircoord(0, 0, 0))
		local pl = is_lantern(lp)
		local ypos = scaffold.setting("depth") or 1
		if lightblock and pl then
			local lpos = ws.dircoord(0, ypos, 0)
			local nd = minetest.get_node_or_nil(lpos)
			if nd and nd.name ~= lightblock then
				ws.dig(lpos)
				ws.place(lpos, lightblock, 5)
			end
		end
	end,
	on_start = function(self)
		lightblock = minetest.localplayer:get_wielded_item():get_name()
		ws.dcm("LTBM started. Selected node: " .. lightblock)
	end,
	on_stop = function(self)
		ws.dcm("LTBM stopped")
	end,
})

