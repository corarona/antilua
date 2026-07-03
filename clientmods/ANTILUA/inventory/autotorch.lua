local torch_items = { "default:torch", "mcl_torches:torch" }
local torch_threshold = 7

if nlist and nlist.get then
	local custom = nlist.get("auto_torch_items")
	if #custom > 0 then
		torch_items = custom
	end
end

local torch_etime = 0

core.register_globalstep(function(dtime)
	if not core.settings:get_bool("auto_torch") then
		return
	end
	local player = core.localplayer
	if not player then return end
	if not player:is_touching_ground() then return end

	torch_etime = torch_etime + dtime
	if torch_etime < 0.5 then return end
	torch_etime = 0

	local pos = player:get_pos()
	if not pos then return end

	local light = core.get_node_light(vector.offset(pos, 0, 1, 0))
	if not light or light >= torch_threshold then return end

	for _, item in ipairs(torch_items) do
		local idx = core.find_item(item)
		if idx then
			core.switch_to_item(item)
			local below = { x = pos.x, y = math.floor(pos.y) - 1, z = pos.z }
			ws.place(below)
			return
		end
	end
end)

core.register_cheat("AutoTorch", {
	category = "Place",
	setting = "auto_torch",
	description = "Auto-place light source in dark areas",
})
