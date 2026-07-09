local inv = core.get_inventory("player:singleplayer")
local r = {}
for k, v in pairs(inv) do
  if type(v) == "table" then
    for i = 1, #v do
      local s = v[i]
      if s and s:get_count() > 0 and s:get_name() ~= "" then
        table.insert(r, k .. "[" .. i .. "]: " .. s:get_name() .. " x" .. s:get_count())
      end
    end
  end
end
return table.concat(r, "\n")
