-- CC0/Unlicense Emilia/cora 2020

-- south:5,1.5
--west:-x,1.5,-5
--east:-x,1.5,5
-- north 5,1.5(3096:2.5,25025:1.5),z
local place_ecs = false
local direction = ""
local ground = {
	"mcl_redstone_torch:redstoneblock"
}

local rails = {
	"mcl_minecarts:golden_rail",
	"mcl_minecarts:rail"
}

local tunnelmaterial = {
	'mcl_core:glass_light_blue',
	'mcl_core:glass',
	"mcl_deepslate:deepslate_cobbled",
	'mcl_nether:nether_brick',
	'mcl_core:stone',
	'mcl_nether:netherrack',
	'mcl_core:cobble',
	'mcl_core:dirt',
	'mcl_core:andesite',
	'mcl_core:diorite',
	'mcl_core:granite',
	"mcl_redstone_torch:redstoneblock",
	"mcl_core:obsidian",
}

local lightnode = "mcl_nether:glowstone"
--local lightnode = "mcl_crimson:shroomlight"
--local lightblock = "mcl_nether:glowstone"

local colorcodes = {
	r1="mcl_colorblocks:concrete_red",
	r2="mcl_colorblocks:concrete_yellow",
	r3="mcl_colorblocks:concrete_blue",
	r4="mcl_colorblocks:concrete_purple",
	r5="mcl_colorblocks:concrete_black",
	north="mcl_core:diorite_smooth",
	west="mcl_core:stonebrickcarved",
	south="mcl_core:granite_smooth",
	east="mcl_core:andesite_smooth"
}

local nodes_border = {
	"mcl_deepslate:deepslate_cobbled",
	"mcl_end:end_bricks",
	'mcl_nether:nether_brick',
	"mcl_core:cobble",
}

local rings={r1=420,r2=666,r3=1337,r4=2666,r5=3860}

function scaffold.get_nether_pos(pos)
	return vector.new(math.floor(pos.x/8),-29000,math.floor(pos.z/8))
end

function scaffold.get_rail_station(dpos)

end

function scaffold.get_dir_from_speed(vel)
	vel=vel or minetest.localplayer:get_velocity()
	if vel.x > vel.z then
		if vel.x < 0 then
			return "west"
		else
			return "east"
		end
	elseif vel.x < vel.z then
		if vel.z < 0 then
			return "south"
		else
			return "north"
		end
	end
end

function scaffold.get_railline(pos)
	pos=vector.round(pos)
	if pos.x == 0 then
		if pos.z > 0 then return "north" end
		if pos.z < 0 then return "south" end
	elseif pos.z == 0 then
		if pos.x > 0 then return "east" end
		if pos.x < 0 then return "west" end
	end
	for k,v in pairs(rings) do
		if math.abs(pos.x)==v or math.abs(pos.z)==v then
			return k
		end
	end
end


local function is_lantern(pos, n)
	local n = n or 8
   local dir=ws.getdir()
   pos=vector.round(pos)
   if dir == "north" or dir == "south" then
		if pos.z % n == 0 then
			return true
		end
   else
		if pos.x % n == 0 then
			return true
		end
   end
   return false
end

local function checknode(pos)
	local lp = ws.dircoord(0,0,0)
	local node = minetest.get_node_or_nil(pos)
	if pos.y == lp.y then
		if node and not node.name:find("_rail") then return true end
	elseif node and node.name ~="mcl_redstone_torch:redstoneblock" then return true
	end
	return false
end


local function blockliquids()
	local lp=ws.dircoord(0,0,0)
	local liquids={'mcl_core:lava_source','mcl_core:water_source','mcl_core:lava_flowing','mcl_core:water_flowing','mcl_nether:nether_lava_source','mcl_nether:nether_lava_flowing'}
	local bn=minetest.find_nodes_near(lp, 6, liquids, true)
	if not bn then return rt end
	local rt = #bn > 0
	for _, v in pairs(bn) do
		ws.place(v, tunnelmaterial)
	end
	return rt
end

local function rnd(n)
	return math.ceil(n)
end

local function fmt(c)
	return tostring(rnd(c.x))..","..tostring(rnd(c.y))..","..tostring(rnd(c.z))
end
local function map_pos(value)
	if value.x then
		return value
	else
		return {x = value[1], y = value[2], z = value[3]}
	end
end

local function invparse(location)
	if type(location) == "string" then
		if string.match(location, "^[-]?[0-9]+,[-]?[0-9]+,[-]?[0-9]+$") then
			return "nodemeta:" .. location
		else
			return location
		end
	elseif type(location) == "table" then
		return "nodemeta:" .. fmt(map_pos(location))
	end
end

local function take_railkit(pos)
	local plinv = minetest.get_inventory(invparse(pos))
	local epos=ws.find_named(plinv,'railkit')
   local mv = InventoryAction("move")
	mv:from(invparse(pos), "main", epos)
	mv:to("current_player", "main", 8)
	mv:apply()
	minetest.localplayer:set_wield_index(8)
	return true

end

local restashing=false
function scaffold.restash()
	if restashing then return end
	restashing=true
	ws.dig(ws.dircoord(1,0,1))
	ws.dig(ws.dircoord(1,1,1))
	ws.dig(ws.dircoord(2,0,1))
	ws.dig(ws.dircoord(2,1,1))

	ws.place(ws.dircoord(1,0,1),{'mcl_chests:chest_small','mcl_chests:chest'})
	ws.place(ws.dircoord(1,1,1),{'railroad'})
	take_railkit(ws.dircoord(1,1,1))
	minetest.after("0.5",function()
		ws.place(ws.dircoord(2,0,1),{'railkit'})
		ws.dig(ws.dircoord(1,1,1))
	end)
	minetest.after("1.0",function()
		autodupe.invtake(ws.dircoord(2,0,1))
		restashing=false
	end)
end


local function node_near(nodes)
	return minetest.find_node_near(ws.dircoord(0,0,0), 15, nodes, true)
end

function scaffold.make_sideportal(offset)
	local pnodes = {
		ws.dircoord(0,offset-1,3),
		ws.dircoord(1,offset,3),
		ws.dircoord(-1,offset,3),
		ws.dircoord(2,offset + 1,3),
		ws.dircoord(-2,offset + 1,3),
		ws.dircoord(2,offset + 2,3),
		ws.dircoord(-2,offset + 2,3),
		ws.dircoord(0,offset + 2,3),
		ws.dircoord(1,offset + 3,3),
		ws.dircoord(-1,offset + 3,3),
	}

	local anodes = {
		ws.dircoord(0,offset,3),
		ws.dircoord(0,offset + 1,3),
		ws.dircoord(-1,offset + 1,3),
		ws.dircoord(1,offset + 1,3),
		ws.dircoord(-1,offset + 2,3),
		ws.dircoord(1,offset + 2,3),

		ws.dircoord(1,offset,2),
		ws.dircoord(0,offset,2),
		ws.dircoord(-1,offset,2),
		ws.dircoord(0,offset + 1,2),
		ws.dircoord(-1,offset + 1,2),
		ws.dircoord(1,offset + 1,2),
		ws.dircoord(2,offset + 1,2),
		ws.dircoord(-2,offset + 1,2),
		ws.dircoord(-1,offset + 2,2),
		ws.dircoord(1,offset + 2,2),
		ws.dircoord(0,offset + 2,2),
		ws.dircoord(2,offset + 2,2),
		ws.dircoord(-2,offset + 2,2),
		ws.dircoord(-1,offset + 3,2),
		ws.dircoord(1,offset + 3,2),
		ws.dircoord(0,offset + 3,2),
		ws.dircoord(2,offset + 3,2),
		ws.dircoord(-2,offset + 3,2),

		ws.dircoord(1,offset,1),
		ws.dircoord(0,offset,1),
		ws.dircoord(-1,offset,1),
		ws.dircoord(0,offset + 1,1),
		ws.dircoord(-1,offset + 1,1),
		ws.dircoord(1,offset + 1,1),
		ws.dircoord(2,offset + 1,1),
		ws.dircoord(-2,offset + 1,1),
		ws.dircoord(-1,offset + 2,1),
		ws.dircoord(1,offset + 2,1),
		ws.dircoord(0,offset + 2,1),
		ws.dircoord(2,offset + 2,1),
		ws.dircoord(-2,offset + 2,1),
		ws.dircoord(-1,offset + 3,1),
		ws.dircoord(1,offset + 3,1),
		ws.dircoord(0,offset + 3,1),
		ws.dircoord(2,offset + 3,1),
		ws.dircoord(-2,offset + 3,1),

	}
	for k,v in pairs(pnodes) do
		ws.dig(v)
		ws.switch_to_item('mcl_core:obsidian')
		minetest.place_node(v)
	end
	for k,v in pairs(anodes) do
		ws.dig(v)
		blockliquids(ws.dircoord(0,0,0,v))
	end

	minetest.settings:set_bool('dighead',false)

	if ws.switch_to_item("mcl_chests:ender_chest") then
		minetest.place_node(ws.dircoord(2,0,2))
	end
	if not node_near({"mcl_portals:portal"}) then
		if ws.switch_to_item('mcl_fire:flint_and_steel') then
			minetest.place_node(ws.dircoord(0,-1,3))
		end
	end
	return ws.dircoord(0,-1,3)
end





local rail_limit = 30912
minetest.register_chatcommand("raillim", {
	description = "Rail limit",
	param = "lim",
	func = function(param)
		local p=math.abs(tonumber(param))
		if p < 0 or p > 30927 then return false,"invalid number" end
		rail_limit=p
		minetest.settings:set("rail_limit",p)
		return true,"rail limit set to "..tostring(p)
	end
})
minetest.register_chatcommand("gimmerails", {
	description = "gimmerails",
	func = function(param)
		minetest.send_chat_message("/giveme mcl_minecarts:golden_rail -1")
		minetest.send_chat_message("/giveme mcl_redstone_torch:redstoneblock -1")
		minetest.send_chat_message("/giveme mcl_ocean:sea_lantern -1")
		minetest.send_chat_message("/giveme mcl_core:obsidian -1")
		minetest.send_chat_message("/giveme mcl_ocean:sea_lantern -1")
		minetest.send_chat_message("/giveme mcl_fire:flint_and_steel")
	end
})
local rail_dir
minetest.register_chatcommand("raildir", {
	description = "Rail direction",
	param = "north|east|south|west",
	func = function(param)
		if not param == "north" or not param == "east" or not param == "west" or not param == "south" then return false,"invalid direction. must be north, east, south or west." end
		rail_dir=param
		minetest.settings:set("rail_dir",param)
		return true,"rail direction set to "..param
	end
})

local function is_solid(pos)
	local n = core.get_node_or_nil(pos)
	return n and n.name and core.get_node_def(n.name).drawtype == "normal"
end

ws.rg("RailBot","Bots", "railbot", function()

	minetest.localplayer:set_pitch(12)
	ws.setdir(rail_dir)
	local goon=false
	local lp=minetest.localplayer:get_pos()
	local dir=ws.getdir()

	if blockliquids(ws.dircoord(0,0,0)) then
		minetest.settings:set_bool('continuous_forward',false)
		return
	end
	for i=-4,4,1 do
		local lpos=ws.dircoord(i,3,0)
		local deconode=colorcodes[scaffold.get_railline(lpos)]
		local lpn=minetest.get_node_or_nil(ws.dircoord(i,0,0))
		local bln=minetest.get_node_or_nil(ws.dircoord(i,-1,0))
		local lant = is_lantern(lpos)
		local ln=minetest.get_node_or_nil(lpos)

		if is_lantern(lpos, 4) then
			local c1pos = ws.dircoord(i,1,2)
			local c2pos = ws.dircoord(i,1,-2)
			local c1node = core.get_node_or_nil(c1pos)
			local c2node = core.get_node_or_nil(c2pos)
			if c1node and c1node.name ~= lightnode then
				ws.dig(c1pos)
				ws.place(c1pos,{lightnode})
			end
			if c2node and c2node.name ~= lightnode then
				ws.dig(c2pos)
				ws.place(c2pos,{lightnode})
			end
		end
		if lant then
			local deco1=ws.dircoord(1,0,0,lpos)
			local deco2=ws.dircoord(-1,0,0,lpos)
			local d1n=minetest.get_node_or_nil(deco1)
			local d2n=minetest.get_node_or_nil(deco2)
			if d1n and d1n.name ~= deconode then
			   -- ws.dig(deco1)
				ws.place(deco1,{deconode})
			end
			if d2n and d2n.name ~= deconode then
			   -- ws.dig(deco2)
				ws.place(deco2,{deconode})
			end
--            if ln and ln.name ~= lightnode then
--                ws.dig(lpos)
--                ws.place(lpos,{lightnode})
--            end
			if checknode(ws.dircoord(i,-1,0)) then
				ws.dig(ws.dircoord(i,-1,0))
				ws.place(ws.dircoord(i,-1,0),ground,7)
			end

		elseif not is_solid(ws.dircoord(i,-1,0)) and checknode(ws.dircoord(i,-1,0)) then
			ws.dig(ws.dircoord(i,-1,0))
			ws.place(ws.dircoord(i,-1,0),ground,7)
		end

		if not ( lpn and lpn.name == "mcl_minecarts:golden_rail_on" ) then
			goon=false
		else
			goon=true
		end

		--digob(ws.dircoord(i,0,0))

		for ii=-1,1 do
			--blockliquids(ws.dircoord(i,2,ii))
			--blockliquids(ws.dircoord(i,1,ii))
			--blockliquids(ws.dircoord(i,0,ii))
			ws.dig(ws.dircoord(i,2,ii))
			ws.dig(ws.dircoord(i,1,ii))
			if ii ~= 0 then
				ws.dig(ws.dircoord(i,0,ii))
			end
		end
		if checknode(ws.dircoord(i,0,0)) then ws.dig(ws.dircoord(i,0,0)) end
		ws.place(ws.dircoord(i,0,0), rails,6)
		ws.place(ws.dircoord(i,-1,1), nodes_border, 6)
		ws.place(ws.dircoord(i,-1,-1), nodes_border, 6)
	end

	if rail_limit and rail_limit ~= 0 then
		local lp=ws.dircoord(0,0,0)
		local stopit=false
		if dir == "west" then
			if lp.x <= -rail_limit  then
				goon=false
				stopit=true
			end
		elseif dir == "east" then
			if lp.x >= rail_limit  then
				goon=false
				stopit=true
			end
		elseif dir == "south" then
			if lp.z <= -rail_limit  then
				goon=false
				stopit=true
			end
		elseif dir == "north" then
			if lp.z >= rail_limit then
				goon=false
				stopit=true
			end
		end

		if stopit == true then
			minetest.settings:set_bool("railbot",false)
			return
		end
	end

	if (goon) then
		local rlp=vector.round(lp)
		minetest.localplayer:set_pos(vector.new(rlp.x,lp.y,rlp.z))
		minetest.settings:set_bool('continuous_forward',true)
	else
		minetest.settings:set_bool('continuous_forward',false)
	end




end,
function()--startfunc
	minetest.settings:set_bool('continuous_forward',false)
	rail_dir=scaffold.get_dir_from_speed(minetest.localplayer:get_velocity())
	if not rail_dir then
		local olddir=minetest.settings:get("rail_dir")
		if olddir then rail_dir=olddir end
	end
	local oldlim=minetest.settings:get("rail_lim")
	if oldlim then rail_limit=oldlim end

	if not rail_dir then return true end
	ws.dcm("railbot started. direction: "..rail_dir.. ", limit: "..tostring(rail_limit))
end,function() --stopfunc
	minetest.settings:set_bool('continuous_forward',false)
	ws.dcm("railbot stopped.")
end,{'autorefill'})

local wtp_i = 1
local wtp_active = false

local function wtp_step()
	ws.dcm("wtp: "..tostring(wtp_i))
	if wtp_active then
		local pos = minetest.localplayer:get_pos()
		if pos.x > 30927 - 80 then
			pos.x = 40
			pos.z = pos.z + 80
		end
		if pos.z > 30927 - 80 then
			pos.z = 40
			pos.y = pos.y + 80
		end
		pos = vector.offset(pos,80,0,0)
		minetest.run_server_chatcommand("teleport", pos.x.." "..pos.y.." "..pos.z )
		wtp_i = wtp_i + 1
		minetest.after(1,wtp_step)
	end
end

ws.rg("WorldTP","Exploit", "worldtp",
	function() end,
	function()
		wtp_active = true
		wtp_step()
	end,
	function()
		wtp_active = false
	end,
{})
