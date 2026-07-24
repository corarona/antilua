local pos = core.localplayer:get_pos()
local r = {}
-- Look in a wider area for wood
local logs = core.find_nodes_in_area(
	{x = pos.x - 20, y = pos.y - 5, z = pos.z - 20},
	{x = pos.x + 20, y = pos.y + 10, z = pos.z + 20},
	"mcl_trees:tree_pale_oak"
)
table.insert(r, #logs .. " pale oak logs found")
if #logs > 0 then
	table.insert(r, "first at " .. dump(logs[1]))
end

-- Also check for other tree types
local all_logs = core.find_nodes_in_area(
	{x = pos.x - 20, y = pos.y - 5, z = pos.z - 20},
	{x = pos.x + 20, y = pos.y + 10, z = pos.z + 20},
	{"group:tree", "mcl_trees:tree_pale_oak"}
)
table.insert(r, #all_logs .. " total tree logs found")

-- Check ground
local g = core.get_node_or_nil({x = pos.x, y = pos.y - 1, z = pos.z})
table.insert(r, "ground: " .. (g and g.name or "nil"))
return table.concat(r, "\n")
