-- CC0/Unlicense Emilia 2020

local seeds = {
	"mcl_farming:wheat_seeds",
	"mcl_farming:beetroot_seeds",
	"mcl_farming:carrot_item",
	"mcl_farming:potato_item"
}

local nodeseeds = {
	"mcl_farming:melon_seeds",
	"mcl_farming:pumpkin_seeds"
}

local tillable = {
	"default:dirt",
	"mcl_core:dirt",
	"default:dirt_with_grass",
	"mcl_core:dirt_with_grass",
	"mcl_farming:soil"
}

local hoes = {
	"mcl_farming:hoe_wood",
	"mcl_farming:hoe_stone",
	"mcl_farming:hoe_iron",
	"mcl_farming:hoe_gold",
	"mcl_farming:hoe_diamond"
}

local water = {
	"mcl_core:water_source",
	"mcl_buckets:bucket_water",
	"mcl_buckets:bucket_river_water"
}
local sownode
ws.rg("Sow", "Place", "farmtool_sow", function()
	local lp = vector.round(minetest.localplayer:get_pos())
	local farm = minetest.find_nodes_in_area_under_air(vector.offset(lp,-4,-4,-4),vector.offset(lp,4,4,4),{"mcl_farming:soil","mcl_farming:soil_wet"})
	for _,v in pairs(farm) do
		local ab = vector.offset(v,0,1,0)
		local n = minetest.get_node_or_nil(ab)
		if n and sownode and n.name == "air" then
			ws.place(ab,sownode)
		end
	end
end,function()
	sownode = minetest.localplayer:get_wielded_item():get_name()
end)

ws.rg("AutoFarm", "Place", "scaffold_farm", function()
	local lp = vector.round(minetest.localplayer:get_pos())
	local below = vector.offset(lp,0,-1,0)

	-- farmland
	if below.x % 5 ~= 0 or below.z % 5 ~= 0 then
		if scaffold.place_if_needed(tillable, below) then
			if scaffold.can_place_at(lp) then
				if scaffold.find_any_swap(hoes) then
					minetest.interact("place", below)
					scaffold.place_if_needed(seeds, lp)
				end
			end
		end
	-- water
	else
		local n=minetest.get_node_or_nil(below)
		if n and n.name ~= "air" and n.name ~= "mcl_core:water_source" then
			ws.dig(below)
		end
	end
end)

ws.rg("AutoMelon","Place","scaffold_melon", function(bb)
	local playerpos = vector.floor(ws.dircoord(0,0,0))
	local poss= ws.get_reachable_positions(2,true)
	local range=2
	for xx = -range,range,1 do
		for zz = -range,range,1 do
			local below = vector.new(playerpos.x + xx,playerpos.y-1,playerpos.z+zz)
			local lp = vector.new(below.x,playerpos.y,below.z)
			local x = vector.floor(below).x % 5
			local z = vector.floor(below).z % 5

			-- water
			if x == 0 and z == 0 then
				scaffold.place_if_needed(water, below)
			-- dirt
			elseif z == 2 or z == 4 or ((x == 2 or x == 4) and z == 0) then
				scaffold.place_if_needed(tillable, below)
			-- farmland
			elseif (x == 1 or z == 1) or (x == 3 or z == 3) then
				if scaffold.place_if_needed(tillable, below) then
					if scaffold.can_place_at(lp) then
						if scaffold.find_any_swap(hoes) then
							minetest.interact("place", below)
							scaffold.place_if_needed(nodeseeds, lp)
						end
					end
				end
			end
		end
	end
end)
