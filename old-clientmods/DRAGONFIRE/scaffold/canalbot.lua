

local rim_material="mcl_nether:netherrack"
local waterb="mcl_buckets:bucket_water"
local emptyb="mcl_buckets:bucket_empty"
local waters="mcl_core:water_source"

local btab={ }

btab[-2]=rim_material
btab[-1]=waters
btab[0] =waters
btab[1] =waters
btab[2] =rim_material


local function get_tnode(r)
	return btab[r] or rim_material
end

local function mstop()
	minetest.settings:set_bool("continuous_forward",false)
end
local function mstart()
	minetest.settings:set_bool("continuous_forward",true)
end

ws.rg("CanalBot","Bots","canalbot",function()
	local move=true
	for i=-1,1,1 do
		for j=-2,2,1 do
			local p=ws.dircoord(i,0,j)
			local n=minetest.get_node_or_nil(p)
			local t=get_tnode(j)
			--if minetest.find_item(emptyb) then
			--	ws.place(waterbot.find_renewable_water_near(ws.dircoord(0,0,0),4),emptyb)
			--end
			if n and n.name ~= t then
				move=false
				if t == waters then
					if j==1 or j==-1 and (p.x % 3 == 0 or p.z %3 == 0) then
						if minetest.find_item(waterb) then
							ws.place(p,waterb)
						end
					end
				else
					if minetest.find_item(t) then 
						ws.place(p,t)
					end
				end
			end
		end
	end
	if move then mstart() else mstop() end
end,function() end,function() end,{'afly_snap','waterbot_refill'})
