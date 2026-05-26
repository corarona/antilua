local underdirt={
	"mcl_core:stone",
	"mcl_core:bedrock",
	"mcl_core:sand",
	"mcl_core:cobble",
	"mcl_core:granite",
	"mcl_core:diorite",
	"mcl_core:andesite",
	"mcl_core:obsidian",
	"mcl_core:gravel",
	"default:stone"
}



local dirt = {
	"mcl_core:dirt",
	"mcl_core:dirt_with_grass",
	"mcl_core:dirt_with_grass_snow",
	"mcl_core:podzol",
	"default:dirt",
	"default:dirt_with_grass",
	"default:dirt_with_coniferous_litter",
	"default:dry_dirt_with_dry_grass",
	"default:dirt_with_rainforest_litter",
	"default:dirt_with_snow",
	"default:dirt_with_grass_footsteps"
}

local saplings = {
	"mcl_core:sapling",
	"mcl_core:darksapling",
	"mcl_core:junglesapling",
	"mcl_core:sprucesapling",
	"mcl_core:birchsapling",
	"mcl_core:acaciasapling",
	"default:junglesapling",
	"default:sapling",
	"default:aspen_sapling",
	"default:pine_sapling"
}
math.randomseed(os.clock())
ws.rg("TreePlanter","Scaffold","scaffold_treeplanter",function() 
	local lp=ws.dircoord(0,0,0)
	local nds=minetest.find_nodes_near_under_air(lp,ws.range,dirt,true)
	local rnd=math.random(1,5)
	local rnd2=math.random(1,5)
	for k,v in pairs(nds) do
		if k > 8 then return end
		if v.x%rnd==0 and v.z%rnd2==0 then
			ws.place(vector.add(v,vector.new(0,1,0)),saplings)
		end
	end
end)

ws.rg("SapScaffold","Scaffold" ,"scaffold_saplings", function()end,function()end,function()end,{"scaffold_treeplanter","scaffold_dirtspam"})

ws.rg("DirtSpam","Scaffold","scaffold_dirtspam",function() 
	local lp=ws.dircoord(0,0,0)
	local nds=minetest.find_nodes_near_under_air(lp,ws.range,underdirt)
	for k,v in ipairs(nds) do
		if k<8 then
			ws.place(ws.dircoord(0,1,0,v),dirt)
		end
	end
end)
