-- Equip pickaxe
core.localplayer:set_wield_index(6)

-- Move to ground level
core.localplayer:set_pos({x = -116, y = 5, z = 99})

-- Look for stone nearby
local pos = core.localplayer:get_pos()
local stone_nodes = core.find_nodes_in_area(
  {x = pos.x - 5, y = pos.y - 20, z = pos.z - 5},
  {x = pos.x + 5, y = pos.y - 1, z = pos.z + 5},
  "mcl_core:stone"
)
if #stone_nodes > 0 then
  return "found " .. #stone_nodes .. " stone blocks, first at " .. dump(stone_nodes[1])
end

-- Try other stone variants
local variants = {
  "mcl_core:stone",
  "mcl_core:cobble",
  "mcl_core:stone_granite",
  "mcl_core:stone_diorite",
  "mcl_core:stone_andesite",
}
for _, v in ipairs(variants) do
  local def = core.get_node_def(v)
  if def then
    return v .. " is a valid block"
  end
end
return "no stone found, checking nearby blocks"
