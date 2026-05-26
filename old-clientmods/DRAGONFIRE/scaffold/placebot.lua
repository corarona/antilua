-- CC0/Unlicense Emilia/cora 2020

-- south:5,1.5
--west:-x,1.5,-5
--east:-x,1.5,5
-- north 5,1.5(3096:2.5,25025:1.5),z
local storage = minetest.get_mod_storage("scaffold")
local direction = ""
local ground = "mesecons_torch:redstoneblock"

local rails = "mcl_minecarts:golden_rail"

local tunnelmaterial = {
	'mcl_core:glass_light_blue',
	'mcl_core:cobble',
	'mcl_core:stone',
	'mcl_nether:netherrack',
	'mcl_core:dirt',
	'mcl_core:andesite',
	'mcl_core:diorite',
	'mcl_core:granite',
	"mesecons_torch:redstoneblock"
}




local function checknode(pos)
	local lp = ws.dircoord(0,0,0)
	local node = minetest.get_node_or_nil(pos)
	if pos.y == lp.y then
		if node and not node.name:find("_rail") then return true end
	elseif node and node.name ~="mesecons_torch:redstoneblock" then return true
	end
	return false
end

local function dignodes(poss)
	for k,v in pairs(poss) do
		if checknode(v) then ws.dig(v) end
	end
end
local function blockliquids(pos)
	local liquids={'mcl_core:lava_source','mcl_core:water_source','mcl_core:lava_flowing','mcl_core:water_flowing','mcl_nether:nether_lava_source','mcl_nether:nether_lava_flowing'}
	local bn=minetest.find_nodes_near(pos, 1, liquids, true)
	for kk,vv in pairs(bn) do
		if vv.y > 1 or vv.y < -40 then
			scaffold.place_if_needed(tunnelmaterial,vv)
			scaffold.place_if_needed(tunnelmaterial,ws.dircoord(0,2,0))
		end
	end
end

local function invcheck(item)
	if mintetest.switch_to_item(item) then return true end
	refill.refill_at(ws.dircoord(1,1,0),'railkit')
end

function ws.rgbot(name,poss,func,funcstart,funcstop)
	ws.rg(name,"Bots",'bot'..name,function()
		local lp=ws.dircoord(0,0,0)
		for k,ppos in ipair(poss) do
			local fpos=vector.add(lp,ppos.pos)
			ws.place(ppos.node,fpos)
		end
	end,funcstart,funcstop)
end

ws.rg("RailBot","Bots", "railbot", function()
	local lp = ws.dircoord(0,0,0)
	local below = ws.dircoord(0,-1,0)
	blockliquids()

	local goon=true
	for i=-4,4,1 do
		blockliquids(ws.dircoord(i,1,0))
		blockliquids(ws.dircoord(i,0,0))
		ws.dig(ws.dircoord(i,1,0))
		if checknode(ws.dircoord(i,0,0)) then ws.dig(ws.dircoord(i,0,0)) end
		if checknode(ws.dircoord(i,-1,0)) then ws.dig(ws.dircoord(i,-1,0)) end
		scaffold.place_if_needed(ground, ws.dircoord(i,-1,0))
		scaffold.place_if_needed(rails, ws.dircoord(i,0,0))

		local lpn=minetest.get_node_or_nil(ws.dircoord(i,0,0))
		local bln=minetest.get_node_or_nil(ws.dircoord(i,-1,0))
		if not ( bln and bln.name==ground and lpn and lpn.name == "mcl_minecarts:golden_rail_on" ) then
			goon=false
		end
		local lpos=ws.dircoord(i,2,0)
		if is_lantern(lpos) then
			local ln=minetest.get_node_or_nil(lpos)
			if not ln or ln.name ~= 'mcl_ocean:sea_lantern' then
				goon=false
				ws.dig(lpos)
				scaffold.place_if_needed({'mcl_ocean:sea_lantern'}, lpos)
			end
		end
	end

	if (goon) then minetest.settings:set_bool('continuous_forward',true)
	else minetest.settings:set_bool('continuous_forward',false) end


end,
function()--startfunc
	direction=turtle.getdir()
	storage:set_string('BOTDIR', direction)
	minetest.settings:set_bool('autogapp',false)
end,function() --stopfunc
	direction=""
	storage:set_string('BOTDIR',direction)
end,{'afly_snap','continuous_forward','autorefill'}) --'scaffold_ltbm'

ws.on_connect(function()
	   local sdir=storage:get_string('BOTDIR')
		if sdir ~= "" then
			ws.set_dir(sdir)
		else
			minetest.settings:set_bool('railbot',false)
		end
end)
