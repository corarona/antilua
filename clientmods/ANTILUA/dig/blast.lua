-- Nuke: radius dig (from scaffold)

local nuke_i = 0

ws.rg("Nuke", {
	category = "Dig",
	setting = "nuke",
	description = "Create a large explosion",
	on_step = function()
		local npt = ws.get_nodes_per_tick()
		local radius = tonumber(core.settings:get("nuke.radius")) or 4
		local pos = ws.dircoord(0, 0, 0)
		nuke_i = 0
		for x = pos.x - radius, pos.x + radius do
			for y = pos.y - radius, pos.y + radius do
				for z = pos.z - radius, pos.z + radius do
					local p = vector.new(x, y, z)
					local node = core.get_node_or_nil(p)
					local def = node and core.get_node_def(node.name)
					if def and def.diggable then
						if nuke_i > npt then return end
						core.dig_node(p)
						nuke_i = nuke_i + 1
					end
				end
			end
		end
	end,
	cheat_settings = {
		radius = { type = "number", default = 4, min = 1, max = 20 },
	},
})
