local sb_state=0
local sb_target=nil
local sb_startpos
local is_spongebot = false
math.randomseed(os.clock())

minetest.register_on_mods_loaded(function()
	for k,v in pairs(minetest.registered_items) do
		minetest.override_item(k, {
			node_placement_prediction = "",
		})
	end
end)

ws.on_connect(function()
	if minetest.settings:get_bool("autoclog") then
		is_spongebot = true
		local lp = minetest.localplayer:get_pos()
		minetest.localplayer:set_pos(vector.new(lp.x,lp.y+30,lp.z))

		minetest.register_on_damage_taken(function(hp)
			--minetest.log("DAMAGED")
			--minetest.disconnect()
		end)
	end
end)
local function dig_sponges_in_range()
	local lp=ws.dircoord(0,0,0)
	local nds=minetest.find_nodes_near(lp,ws.range,nlist.get(nlist.selected),true)
	for k,v in ipairs(nds) do
		if k < 8 then
			ws.dig(v)
		end
	end
end

local function find_closest(ndnames,range,nneighbor)
	range = range or ws.range
	local lp=ws.dircoord(0,0,0)
	local nds=minetest.find_nodes_near(lp,range,ndnames,true)
	--local nds=minetest.find_nodes_in_area(vector.offset(lp,-200,-40,-200),vector.offset(lp,200,40,200),ndnames,true)
--	table.sort(nds,function(a, b)
--		return vector.distance(lp,a) < vector.distance(lp,b) end)
--		return a.y > b.y end)

	local odst=100
	local rt = nil
--[[	if sb_target then
		for i = 1,6 do
			local tp = vector.add(sb_target,vector.multiply(vector.floor(vector.direction(lp,sb_target)),i))
			local tn = minetest.get_node_or_nil(tp)
			if tn and tn.name == "mcl_core:water_source" then
				return tp,i
			end
		end
	end--]]
	for _,v in ipairs(nds) do
		local dst = vector.distance(lp,v)
		--local nda = minetest.get_node_or_nil(vector.offset(v,0,1,0))
		--if nda and nda.name == "air" and dst < odst and not minetest.find_node_near(v,1,nneighbor) then odst=dst rt=v end
		if dst < odst and v.y > 1 then odst=dst rt=v end
		--and not minetest.find_node_near(v,1,nneighbor)
	end
	--if nds then
	--	return nds[1],vector.distance(lp,nds[1])
	--end
	if not rt then
		minetest.settings:set_bool("continuous_forward",false)
		minetest.sound_play("mcl_bells_bell_stroke", { pitch = 1.5, gain = 1.5})
		minetest.settings:set_bool("spongebot",false)
		--minetest.disconnect()
	end
	return rt,odst
	--return nil,100
end

local function checknode(pos)
	if pos then
		local tn = minetest.get_node_or_nil(pos)
		if tn and tn.name ~= "air" then return true end
	end
end
local function axissnap()
	local y=minetest.localplayer:get_yaw()
	local yy
	if ( y < 45 or y > 315 ) then
	    yy=0
	elseif (y < 135) then
	    yy=90
	elseif (y < 225 ) then
	    yy=180
	else
	    yy=270
	end
	minetest.localplayer:set_yaw(yy)
end

ws.rg("SpongeBot","Bots","spongebot",function()
	local dst=200
	local lp = minetest.localplayer:get_pos()
	if sb_state == 0 then
				--minetest.log("st 0")
		--sb_target,dst=find_closest(nlist.get(nlist.selected),50)
		sb_target,dst=find_closest({"mcl_core:water_source"},50)
		--sb_target,dst=find_closest({"mcl_core:water_flowing"},70)
		if checknode(sb_target) then
			--minetest.display_chat_message("found: "..minetest.pos_to_string(sb_target).." dst: "..dst)
			local blk=minetest.find_nodes_in_area(ws.dircoord(0,-1,0), ws.dircoord(1,2,0), {'mcl_core:bedrock','mcl_core:obsidian'})
			if blk and #blk > 0 then
				minetest.localplayer:set_pos(ws.dircoord(math.random(-1,1),2,math.random(-1,1)))
			end
			sb_state=1
			return
		--elseif sb_startpos then
			--ws.aim(sb_startpos)
		end
	elseif sb_state == 1 then
	--minetest.log("st 1")
		ws.aim(sb_target)
		if not checknode(sb_target) then
			sb_state=0
			return
		end
	end
	--dig_sponges_in_range()
	if sb_target and vector.distance(lp,sb_target) < 1 then
		minetest.settings:set_bool("continuous_forward",false)
		ws.dig(sb_target)
	else
		minetest.settings:set_bool("continuous_forward",true)
	end
	--axissnap()
end,function()
	sb_state=0
	sb_target=nil
	math.randomseed(os.clock())
	sb_startpos = minetest.localplayer:get_pos()
	minetest.settings:set_bool("pitch_move",true)
	minetest.settings:set_bool("free_move",true)
	minetest.settings:set_bool("autosponge",true)
	minetest.settings:set_bool("autoclog",true)
	minetest.settings:set_bool("autoeat",true)
end,function()
	minetest.settings:set_bool("pitch_move",false)
end,{})

ws.rg("Autosponge","Scaffold","autosponge",function()
	--if minetest.localplayer:get_wielded_item():get_name() ~= "mcl_sponges:sponge" then return end
	local water = minetest.find_node_near(minetest.localplayer:get_pos(), 10, "mcl_core:water_source")
	if water then
		ws.place(water,"mcl_sponges:sponge")
		--minetest.place_node(water)
	end
end)

ws.rg("DigFreeSponge","Dig","autospongedig",function()
	local lp = minetest.localplayer:get_pos()
	--if minetest.localplayer:get_wielded_item():get_name() ~= "mcl_sponges:sponge" then return end
	for _,sp in pairs(minetest.find_nodes_near(lp,4,{"mcl_sponges:sponge","mcl_sponges:sponge_wet"})) do
		if not minetest.find_node_near(sp, 6, "mcl_core:water_source") then
			ws.dig(sp)
		end
	end
end)

local chatscore = 0
local chatlimit = 10

local function chat(msg)
	if chatscore < chatlimit then
		minetest.send_chat_message(msg)
		chatscore = chatscore + 1
		minetest.after(5,function()
			chatscore = math.max(0,chatscore - 1)
		end)
	end
end

minetest.register_on_receiving_chat_message(function(message)
	if not is_spongebot then return end
	if message:find("greeferdude Left$") then
		chat(" I AM TEH GREEFADOOD HEET  MA EVAL PROPER GANDER! WE ARE TEH SOLDIRS   OFF ANACRY WE AR TOTALY NOD KINDAGARDN  (WE ALRDY PRESKOOL). WE DO NOT FROGIV! EXCEPT UZ!")
	elseif message:find("^<greeferdude>") then
		if math.random(20) == 1 then
			chat("WE ARE TEH SOLDIRS OFF ANACRY WE AR TOTALY NOD KINDAGARDN (WE ALRDY PRESKOOL). WE DO NOT FROGIV! EXCEPT UZ!")
		end
	elseif message:find("^Burrowing_Owl Joined$") then
		chat("Hi!")
	elseif message:find("^Burrowing_Owl Left$") then
		chat("Another satisfied customer!")
	end
end)

local digcyl_mid
local digcyl_rad

minetest.register_chatcommand("digcyl",{func=function(p)
	local pos = minetest.string_to_pos(p)
	if pos then
		digcyl_mid = pos
		ws.dcm("digcyl mid set to "..p)
	else
		digcyl_mid = ws.dircoord(0,0,0)
		ws.dcm("digcyl mid set to player pos")
	end
end})
minetest.register_chatcommand("digcyl_rad",{func=function(p)
	local n = tonumber(p)
	if n then
		digcyl_rad = n
		ws.dcm("digcyl rad set to "..n)
	end
end})

ws.rg("Digcyl","Dig","digcyl",function()
	if not digcyl_mid or not digcyl_rad then return end
	local lp = minetest.localplayer:get_pos()
	for _,v in pairs(minetest.find_nodes_near(lp,ws.range,nlist.get(nlist.selected),true)) do
		local n = minetest.get_node_or_nil(v)
		if v.y > -125 and vector.distance(vector.new(v.x,0,v.z),vector.new(digcyl_mid.x,0,digcyl_mid.z)) < digcyl_rad and n and n.name ~= "air" then
			ws.dig(v)
		end
	end
end,function()end,function()end,{},2)
