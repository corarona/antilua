-- Check current position and surroundings
local pos = core.localplayer:get_pos()
local check = {}
for y = 0, 10 do
  local n = core.get_node_or_nil({x = pos.x, y = y, z = pos.z})
  if n then
    check[#check + 1] = "y" .. y .. "=" .. n.name
  end
end
return "pos=" .. dump(pos) .. " | " .. table.concat(check, ", ")
