local mclminer_tgt
local tpactive
local tpstep = 3.8

local function pos_ok(pos)
	local p = minetest.find_node_near(pos, 10, {"mcl_core:lava_source","mcl_core:lava_flowing","mcl_nether:nether_lava_source","mcl_nether:nether_lava_flowing"}, true)
	return not p
end

local function get_miner_node(pos)
	local nds=minetest.find_nodes_near(pos,50,nlist.get(nlist.selected),true)
	table.sort(nds,function(a, b) return vector.distance(pos,a) < vector.distance(pos,b) end)
	for _,p in ipairs(nds) do
		if pos_ok(p) then
			return p
		end
	end
end

local function do_tp(tpos)
	if tpactive then return end
	tpactive = true
	local lp = minetest.localplayer:get_pos()
	minetest.after(1,function(lp,tpos)
		if not pos_ok(tpos) then
			minetest.localplayer:set_pos(vector.offset(lp,0,25,0))
			mclminer_tgt = nil
			tpactive = false
			ws.dcm("LAVAAA")
			minetest.settings:set_bool("mclminer", false)
			return
		end
		minetest.localplayer:set_pos(tpos)
		tpactive = false
	end,lp,tpos)
end

local function lavapanic()
	local head = vector.offset(minetest.localplayer:get_pos(),0,1,0)
	local headnode = minetest.get_node_or_nil(head)
	if headnode and headnode.name:find("lava") then
		minetest.localplayer:set_pos(vector.offset(head,0,10,0))
	end
end

ws.rg('DigHead','Player','dighead',function() ws.dig(ws.dircoord(0,1,0)) end)

ws.rg("Mclminer","Bots","mclminer",function()
	lavapanic()
	local lp=minetest.localplayer:get_pos()
	local hp=minetest.localplayer:get_hp()
	if hp < 15 then return end
	if mclminer_tgt then
		local its = minetest.get_objects_inside_radius(lp,2)
		for _,o in pairs(its) do
			local p = o:get_properties()
			if not o:is_local_player() and not p.wield_item then
				return
			end
		end
		local n=minetest.get_node_or_nil(mclminer_tgt)
		if n.name == "air" then
			mclminer_tgt = nil
			return
		end

		local tpos=vector.offset(mclminer_tgt,0,-1,0)
		if not tpactive and vector.distance(lp,tpos) > tpstep then
			local tppos = vector.add(lp,vector.multiply(vector.direction(lp,tpos),tpstep))
			do_tp(tppos)
		elseif not tpactive and pos_ok(tpos) then
			do_tp(tpos)
		else
			do_tp(vector.offset(lp,0,25,0))
		end
	else
		mclminer_tgt=get_miner_node(lp)
	end
end,function()
	minetest.settings:set_bool("autoeat",true)
	minetest.settings:set_bool("dighead",true)
	mclminer_tgt = nil
end,function()

end)
