local greenup_node = "mcl_core:dirt_with_grass"

ws.rg("PlaceOn", { category = "Place", setting = "placeon",
	on_step = function(self)
		local range = tonumber(core.settings:get(self.setting .. ".range")) or 4
		local node = core.settings:get(self.setting .. ".node") or greenup_node
		local pos = ws.dircoord(0, 0, 0)
		local poss = core.find_nodes_near_under_air_except(pos, range, {node})
		for _, v in pairs(poss) do
			ws.place(vector.offset(v, 0, 1, 0), node)
		end
	end,
	on_start = function(self)
		greenup_node = core.localplayer:get_wielded_item():get_name()
	end,
	cheat_settings = {
		range = { type = "number", default = 4, min = 1, max = 20 },
		node = { type = "string", default = "mcl_core:dirt_with_grass" },
	},
})

ws.rg("TorchUp", { category = "Place", setting = "torchup",
	on_step = function(self)
		local range = tonumber(core.settings:get(self.setting .. ".range")) or 4
		local threshold = tonumber(core.settings:get(self.setting .. ".light_threshold")) or 8
		local node = core.settings:get(self.setting .. ".node") or "mcl_torches:torch"
		local pos = ws.dircoord(0, 0, 0)
		local poss = core.find_nodes_near_under_air_except(pos, range, {node})
		for _, v in pairs(poss) do
			local ab = vector.offset(v, 0, 1, 0)
			local li = core.get_node_light(ab, 0.0)
			if li and li < threshold then
				ws.place(ab, node)
			end
		end
	end,
	cheat_settings = {
		range = { type = "number", default = 4, min = 1, max = 20 },
		light_threshold = { type = "number", default = 8, min = 0, max = 15 },
		node = { type = "string", default = "mcl_torches:torch" },
	},
})
