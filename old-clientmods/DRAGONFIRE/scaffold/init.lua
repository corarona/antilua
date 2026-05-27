-- CC0/Unlicense Emilia & cora 2020

local category = "Scaffold"

scaffold = {}
scaffold.lockdir = false
scaffold.locky = false
scaffold.constrain1 = false
scaffold.constrain2 = false
local hwps={}

local multiscaff_width=5
local multiscaff_depth=1
local multiscaff_above=0
local multiscaff_mod=1

local storage = minetest.get_mod_storage("scaffold")


local nodes_per_tick = 8

local function setnpt()
	nodes_per_tick = tonumber(minetest.settings:get("nodes_per_tick")) or 8
end

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

ws.rg('DigHead','Player','dighead',function() ws.dig(ws.dircoord(0,1,0)) end)



minetest.register_chatcommand('scaffw', {
	func = function(param) multiscaff_width=tonumber(param) end
})
minetest.register_chatcommand('scaffd', {
	func = function(param) multiscaff_depth=tonumber(param) end
})
minetest.register_chatcommand('scaffa', {
	func = function(param) multiscaff_above=tonumber(param) end
})
minetest.register_chatcommand('scaffm', {
	func = function(param) multiscaff_mod=tonumber(param) end
})

local multiscaff_node=nil

local function mscaffold(f,y_offset)
	f = f or 0
	y_offset = y_offset or 0
	if not multiscaff_node then return end
	local yf=-multiscaff_depth
	local yt=-1
	if multiscaff_above>0 then
		yf=multiscaff_above
		yt=multiscaff_above+multiscaff_depth
	end
	local n=math.floor(multiscaff_width/2)
	for fo =-2,2 do
		for i=-n,n do
			for j=yf, yt do
				local p = ws.dircoord(fo,j,i)
				local nd= p and minetest.get_node_or_nil(p)
				if nd then
					ws.place(p,{multiscaff_node})
				end
			end
		end
	end
end

ws.rg('PlaceOn','Scaffold','scaffold_placeon',function()
	local nds=minetest.find_nodes_near(ws.dircoord(0,0,0),ws.range,nlist.selected)
	for k,v in ipairs(nds) do
		ws.switch_to_item(multiscaff_node)
		minetest.place(vector.add(v,vector.new(0,1,0)))
	end
end,function()
	multiscaff_node=minetest.localplayer:get_wielded_item():get_name()
	ws.dcm("PlaceOn started. Selected node: "..multiscaff_node)
end,function()
	ws.dcm("PlaceOn stopped")
end)

ws.rg('MultiScaff','Scaffold','scaffold',function()
	if tps_client and tonumber(tps_client.ping) and tps_client.ping > (tps_client and tps_client.ping_tolerance or 0.5) then return end
	mscaffold(0)
end,function()
	multiscaff_node=minetest.localplayer:get_wielded_item():get_name()
	ws.dcm("Multiscaff started. Width: "..multiscaff_width..', depth:'..multiscaff_depth..' Selected node: '..multiscaff_node)
end,function()
	ws.dcm("Multiscaff stopped")
end)

ws.rg('MScaffModulo','Scaffold','multiscaffm',function()
	if not multiscaff_node then return end
	ws.switch_to_item(multiscaff_node)
	local n=math.floor(multiscaff_width/2)
	for i=-n,n do
		for j=(multiscaff_depth * -1), -1 do
			local p=vector.round(ws.dircoord(0,j,i))
			if p.z % multiscaff_mod == 0 then
				if p.x % multiscaff_mod ~= 0 then
					core.place_node(p)
				end
			else
				if p.x % multiscaff_mod == 0 then
					core.place_node(p)
				end
			end
		end
	end
end,function()
	multiscaff_node=minetest.localplayer:get_wielded_item():get_name()
	ws.dcm("ModuloScaff started. Width: "..multiscaff_width..', depth:'..multiscaff_depth..' Selected node: '..multiscaff_node)
end,function()
	ws.dcm("Moduloscaff stopped")
end)



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
	local lp=ws.dircoord(0,0,0)
	local maxv=multiscaff_width
	if multiscaff_depth > multiscaff_width then maxv=multiscaff_depth end
	for a=-multiscaff_depth,multiscaff_depth - 1 do
		local n=math.floor(multiscaff_width/2)
		for b=-n,n do
			local v=ws.dircoord(1,a,b)
			if(condition == nil or condition(v)) then
				local n=minetest.get_node_or_nil(v)
				local dst=vector.distance(lp,v)
				ws.dig(v)
				if dst < maxv and ( not n or n.name ~= "air" )then
					minetest.settings:set_bool('continuous_forward',false)
				end
			end
		end
	end
end

ws.rg('Excavator','Diggers','excavator',function()
	minetest.settings:set_bool('continuous_forward',true)
	excavate(function(p)
		local lp=ws.dircoord(0,0,0)
		if p.y >= lp.y then
			return true
		end
		return false
	end)
end,function()end,function()end,{'axissnap'},0.2)

ws.rg('TBM','Diggers','excavator',function()
	minetest.settings:set_bool('continuous_forward',true)
	excavate(function(p)
		local lp=ws.dircoord(0,0,0)
		if p.y >= lp.y then
			return true
		end
		return false
	end)
	for f=-1,1 do
		for y=0, 5 do
			ws.place(ws.dircoord(f, y,-multiscaff_width - 1), nlist.get("TBM"))
			ws.place(ws.dircoord(f, y,multiscaff_width + 1), nlist.get("TBM"))
		end
	end

end,function()end,function()end,{'axissnap'},0.2)


ws.rg('TExcavator','Diggers','texcavator',function()
	minetest.settings:set_bool('continuous_forward',true)
	excavate()
end,function()end,function()end,{'axissnap'},0.2)

ws.rg('WallExcavator','Diggers','wallexcavator',function()
	minetest.settings:set_bool('continuous_forward',true)
	local lp=ws.dircoord(0,0,0)
	if tps_client and tps_client.ping and tps_client.ping > 1000 then
		minetest.settings:set_bool('continuous_forward',false)
		return end

	for a=-multiscaff_depth,multiscaff_depth do
		for b=-multiscaff_width,multiscaff_width do
			local v=ws.dircoord(1,a,b)
			local n=minetest.get_node_or_nil(v)
			local dst=vector.distance(lp,v)
			if ws.inside_wall(v) then ws.dig(v)
			--else
				--minetest.settings:set_bool('wallexcavator',false)
				--minetest.settings:set_bool('axissnap',false)
			end
			if not ws.inside_wall(v) and dst < 2 and ( not n or n.name ~= "air" )then
				minetest.settings:set_bool('continuous_forward',false)
			end
		end
	end

end,function()end,function()end,{'axissnap'},0.05)

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

ws.rg("Highway","Scaffold","highwaymaker",function()
	for i=-2,2 do
		mscaffold(i)
		local lightblock = "mcl_ocean:sea_lantern"
	   local dir=ws.getdir()
	   local lp=vector.round(ws.dircoord(0,0,0))
	   local pl=is_lantern(lp)
	   if pl then
			local lpos=ws.dircoord(0,3,0)
			local nd=minetest.get_node_or_nil(lpos)
			if nd and nd.name ~= lightblock then
				ws.dig(lpos)
				ws.place(lpos,lightblock,5)
			end
	   end
	end
end,function()
	multiscaff_width=5
	multiscaff_depth=3
	multiscaff_node=minetest.localplayer:get_wielded_item():get_name()
end,function()end,{'excavator','block_sources'},0.05)

ws.rg("HighwayZ","World","highwayz",function()
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
		if i > nodes_per_tick then break end
		minetest.place_node(p)
	end

end, setnpt)

ws.rg("BlockWater","World","block_water",function()
	local lp=ws.dircoord(0,0,0)
	local positions = minetest.find_nodes_near(lp, 5, {"mcl_core:water_source", "mcl_core:water_flowing"}, true)
	for i, p in pairs(positions) do
		if i > nodes_per_tick then return end
		minetest.place_node(p)
	end
end,setnpt)

ws.rg("BlockLava","World","block_lava",function()
	local lp=ws.dircoord(0,0,0)
	local positions = minetest.find_nodes_near(lp, 5, {"mcl_core:lava_source", "mcl_core:lava_flowing"}, true)
	for i, p in pairs(positions) do
		if i > nodes_per_tick then return end
		minetest.place_node(p)
	end
end,setnpt)

ws.rg("BlockSources","World","block_sources",function()
	if not multiscaff_node then
		multiscaff_node=minetest.localplayer:get_wielded_item():get_name()
		return
	end
	local lp=ws.dircoord(0,0,0)
	local positions = minetest.find_nodes_near(lp, 5, {"mcl_core:lava_source","mcl_nether:nether_lava_source","mcl_core:water_source"}, true)
	for i, p in pairs(positions) do
		if i > nodes_per_tick then return end
		if p.y<2 then
			if p.x>250 and p.z>250 then return end
		end
		ws.place(p,multiscaff_node)
	end
end,function()
	multiscaff_node=minetest.localplayer:get_wielded_item():get_name()
	core.log(multiscaff_node)
	if not multiscaff_node then return true end
	setnpt()
end)

ws.rg("BlockLavaSources","World","block_lava_sources",function()
	if not multiscaff_node then return false end
	local lp=ws.dircoord(0,0,0)
	local positions = minetest.find_nodes_near(lp, 5, {"mcl_core:lava_source","mcl_nether:nether_lava_source"}, true)
	for i, p in pairs(positions) do
		if i > nodes_per_tick then return end
		if p.y<2 then
			if p.x>250 and p.z>250 then return end
		end
		ws.place(p,multiscaff_node)
	end
end,function()
	multiscaff_node=minetest.localplayer:get_wielded_item():get_name()
	if not multiscaff_node then return true end
	setnpt()
end)

ws.rg("PlaceOnTop","World","place_on_top",function()
	if not multiscaff_node then return end
	local lp=ws.dircoord(0,0,0)
	local item=minetest.localplayer:get_wielded_item():get_name()
	if not item then return end
	local positions = minetest.find_nodes_near_under_air_except(lp, 5, {multiscaff_node}, true)
	for i, p in pairs(positions) do
		if i > nodes_per_tick then break end
		ws.place(vector.add(p, {x = 0, y = 1, z = 0}),multiscaff_node)
	end
end,function()
	if not minetest.localplayer then return true end
	local it=minetest.localplayer:get_wielded_item()
	if it.type ~= "node" then return true end
	multiscaff_node=it:get_name()
	if not multiscaff_node then return true end
	setnpt()
end)

ws.rg("Nuke","World","nuke",function()
	local pos=ws.dircoord(0,0,0)
	local i = 0
	for x = pos.x - 4, pos.x + 4 do
		for y = pos.y - 4, pos.y + 4 do
			for z = pos.z - 4, pos.z + 4 do
				local p = vector.new(x, y, z)
				local node = minetest.get_node_or_nil(p)
				local def = node and minetest.get_node_def(node.name)
				if def and def.diggable then
					if i > nodes_per_tick then return end
					minetest.dig_node(p)
					i = i + 1
				end
			end
		end
	end
end,setnpt)

local lightblock=nil
ws.rg("LanternTBM","Scaffold", "scaffold_ltbm", function()
   local dir=ws.getdir()
   local lp=vector.round(ws.dircoord(0,0,0))
   local pl=is_lantern(lp)
   local ypos=multiscaff_depth
   if lightblock and pl then
		local lpos=ws.dircoord(0,ypos,0)
		local nd=minetest.get_node_or_nil(lpos)
		if nd and nd.name ~= lightblock then
			ws.dig(lpos)
			ws.place(lpos,lightblock,5)
		end
   end
end,function()
	lightblock=minetest.localplayer:get_wielded_item():get_name()
	ws.dcm("LTBM started. Selected node: "..lightblock)
end,function()
	ws.dcm("LTBM stopped")
end)

