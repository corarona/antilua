-- Move near the tree and dig some wood
local pos = core.localplayer:get_pos()
local tree_pos = {x = -184, y = 9, z = 161}

-- Move near the tree
core.localplayer:set_pos({x = tree_pos.x + 1, y = tree_pos.y, z = tree_pos.z})

-- Find nearby logs and dig them
local nearby = core.find_nodes_in_area(
	{x = tree_pos.x - 3, y = tree_pos.y - 2, z = tree_pos.z - 3},
	{x = tree_pos.x + 3, y = tree_pos.y + 5, z = tree_pos.z + 3},
	"mcl_trees:tree_pale_oak"
)

for _, lp in ipairs(nearby) do
	core.dig_node(lp)
end

-- Walk around to pick up drops
core.localplayer:set_pos({x = tree_pos.x + 2, y = tree_pos.y, z = tree_pos.z})

return "dug " .. #nearby .. " logs"
