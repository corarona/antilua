local fb_state=0
local fb_obpos=vector.new(0,0,0)

local function find_closest_water_source()
	local lp=ws.dircoord(0,0,0)
	local nds=minetest.find_nodes_near(lp,10,{"mcl_core:water_source"})
	local odst=100
	local rt=vector.new()
	for k,v in ipairs(nds) do
		local dst=vector.distance(lp,v)
		if dst < odst then rt=v odst=dst end
	end
	return rt
end

local function get_bobber_pos()
	local obs=minetest.get_objects_inside_radius(ws.dircoord(0,0,0),10)
	for k,v in ipairs(obs) do
		local txt = (v.get_properties and v:get_properties().textures[1]) or (v.get_item_textures and v:get_item_textures())  or ""
		if txt:find("bobber") then
			return v:get_pos()
		end
	end
	return false
end

ws.rg('FishBot','Bots','fishbot',function()
	if not ws.switch_to_item('mcl_fishing:fishing_rod_enchanted') then
		ws.switch_to_item('mcl_fishing:fishing_rod')
	end
	local bpos=get_bobber_pos()
	if not bpos then fb_state=0 end
	if fb_state == 0 then --init
		minetest.interact("activate",{type="nothing"})
		fb_state=1
	elseif fb_state == 1 then --waiting for bobber to settle
		if vector.distance(bpos,fb_obpos) == 0 then
			fb_state=2
		end
	elseif fb_state == 2 then --waiting for bobber to move
		local nd=minetest.get_node_or_nil(vector.add(bpos,vector.new(0,-0.5,0)))
		if vector.distance(bpos,fb_obpos) > 0 then
			minetest.after('0.1',function()
				minetest.interact("activate",{type="nothing"})
			end)
			fb_state=3
		end
		if nd.name ~= "mcl_core:water_source" then
			fb_state=0
		end
	elseif fb_state == 3 then --waiting til bobber is gone
		if not get_bobber_pos() then fb_state=0 end
	end
	if bpos then fb_obpos=bpos end
end,function()
	if ws.game ~= "mineclone" then ws.dcm("Fishbot only works on mineclone/ia") end
	if not ws.switch_to_item('mcl_fishing:fishing_rod_enchanted') and not ws.switch_to_item('mcl_fishing:fishing_rod') then
		ws.dcm("Put a fishing rod in the hotbar")
		return true
	end
end, function()
	fb_state=0
end,{'autodump','autoeject','lockview'})
