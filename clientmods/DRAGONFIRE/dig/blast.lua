-- Nuke: radius dig (from scaffold)

ws.rg("Nuke", {
	category = "Dig",
	setting = "nuke",
	on_step = function()
		local npt = ws.get_nodes_per_tick()
		local radius = tonumber(core.settings:get("nuke.radius")) or 4
		local pos = ws.dircoord(0, 0, 0)
		local i = 0
		for x = pos.x - radius, pos.x + radius do
			for y = pos.y - radius, pos.y + radius do
				for z = pos.z - radius, pos.z + radius do
					local p = vector.new(x, y, z)
					local node = minetest.get_node_or_nil(p)
					local def = node and minetest.get_node_def(node.name)
					if def and def.diggable then
						if i > npt then return end
						minetest.dig_node(p)
						i = i + 1
					end
				end
			end
		end
	end,
	cheat_settings = {
		radius = { type = "number", default = 4, min = 1, max = 20 },
	},
})
