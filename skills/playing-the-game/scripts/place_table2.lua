-- Move crafting table to hotbar
local act = InventoryAction("move")
act:from("current_player", "main", 9)
act:to("current_player", "main", 8)
act:set_count(0)
act:apply()

-- Select hotbar slot 8
core.localplayer:set_wield_index(8)

-- Check what's wielded
local item = core.localplayer:get_wielded_item()
if item then
	-- Find a place to put it
	local pos = core.localplayer:get_pos()
	local place_pos = {x = pos.x + 1, y = pos.y, z = pos.z}
	local node = core.get_node_or_nil(place_pos)
	if not node or node.name ~= "air" then
		place_pos = {x = pos.x - 1, y = pos.y, z = pos.z}
		node = core.get_node_or_nil(place_pos)
	end
	if not node or node.name ~= "air" then
		place_pos = {x = pos.x, y = pos.y, z = pos.z + 1}
		node = core.get_node_or_nil(place_pos)
	end
	if not node or node.name ~= "air" then
		place_pos = {x = pos.x, y = pos.y, z = pos.z - 1}
		node = core.get_node_or_nil(place_pos)
	end
	
	-- Check if the node is placeable there
	if node and node.name == "air" then
		-- Place the node
		core.place_node(place_pos)
		return "placed at " .. dump(place_pos)
	else
		return "no air spot found near " .. dump(pos)
	end
else
	return "no wielded item"
end
