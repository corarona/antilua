local farmnodes = {
	"farming:wheat_8", "farming:cotton_8",
	"mcl_farming:wheat", "mcl_farming:carrot", "mcl_farming:potato",
	"mcl_farming:melon", "mcl_farming:pumpkin_face", "mcl_farming:beetroot",
	"default:papyrus",
}

local keepbottom = {
	"mcl_core:cactus", "mcl_core:reeds", "default:papyrus",
}

local farmsoil = {
	"mcl_farming:soil", "mcl_farming:soil_wet", "farming:soil", "farming:soil_wet",
}

local dirt = {
	"mcl_core:dirt_with_grass", "mcl_core:dirt",
}

local seeds = {
	["mcl_farming:wheat"] = "mcl_farming:wheat_seeds",
	["mcl_farming:carrot"] = "mcl_farming:carrot_item",
	["mcl_farming:potato"] = "mcl_farming:potato_item",
	["mcl_farming:pumpkin_face"] = "mcl_farming:pumpkin_seeds",
	["mcl_farming:melon"] = "mcl_farming:melon_seeds",
	["mcl_farming:beetroot"] = "mcl_farming:beetroot_seeds",
	["farming:cotton"] = "farming:seed_wheat",
	["farming:wheat"] = "farming:seed_cotton",
}

local water = {
	"mcl_core:water_source", "mcl_core:river_water_source",
}

local waterbowl = {
	vector.new(1, 0, 0), vector.new(-1, 0, 0),
	vector.new(0, 0, 1), vector.new(0, 0, -1),
	vector.new(0, -1, 0),
}

local seed_items = {}
for _, v in pairs(seeds) do
	table.insert(seed_items, v)
end

ws.rg("Reap", { category = "Place", setting = "farmtool_reap",
	on_step = function(self)
		local range = tonumber(core.settings:get(self.setting .. ".range")) or ws.range
		local nds = minetest.find_nodes_near(ws.dircoord(0, 0, 0), range, farmnodes, true)
		for k, v in ipairs(nds) do
			local nd = minetest.get_node_or_nil(v)
			if nd then
				ws.dig(v)
				local s = seeds[nd.name]
				ws.place(v, s)
			end
		end
		local knds = minetest.find_nodes_near(ws.dircoord(0, 0, 0), range, keepbottom, true)
		for k, v in ipairs(knds) do
			local bt = minetest.get_node_or_nil(vector.offset(v, 0, -1, 0))
			local nd = minetest.get_node_or_nil(v)
			if bt and bt.name == nd.name then
				ws.dig(v)
			end
		end
	end,
	cheat_settings = {
		range = { type = "number", default = ws.range, min = 1, max = 20 },
	},
})

ws.rg("Till", { category = "Place", setting = "farmtool_till",
	on_step = function(self)
		local range = tonumber(core.settings:get(self.setting .. ".range")) or 5
		local hoe = core.settings:get(self.setting .. ".hoe_item") or "mcl_tools:hoe_diamond"
		local p = core.localplayer:get_pos()
		local nds = core.find_nodes_near(p, range, dirt, true)
		ws.switch_to_item(hoe)
		for _, v in pairs(nds) do
			core.place_node(v)
		end
	end,
	cheat_settings = {
		range = { type = "number", default = 5, min = 1, max = 20 },
		hoe_item = { type = "string", default = "mcl_tools:hoe_diamond" },
	},
})

local sseed = "mcl_farming:wheat_seed"

ws.rg("Sow", { category = "Place", setting = "farmtool_sow",
	on_step = function(self)
		local range = tonumber(core.settings:get(self.setting .. ".range")) or ws.range
		local nds = minetest.find_nodes_near(ws.dircoord(0, 0, 0), range, farmsoil, true)
		for _, v in pairs(nds) do
			ws.place(vector.add(vector.new(0, 1, 0), v), sseed)
		end
	end,
	on_start = function(self)
		local s = minetest.localplayer:get_wielded_item():get_name()
		for _, v in pairs(seeds) do
			if v == s then
				ws.notify("Sowing started with " .. s, ws.NOTIFY_INFO, {toast=false})
				sseed = s
				return
			end
		end
		ws.notify("No seed wielded.", ws.NOTIFY_WARNING)
		return true
	end,
	cheat_settings = {
		range = { type = "number", default = ws.range, min = 1, max = 20 },
	},
})

ws.rg("FarmRepair", { category = "Place", setting = "farmrepair",
	on_step = function(self)
		local range = tonumber(core.settings:get(self.setting .. ".range")) or 5
		local channel = tonumber(core.settings:get(self.setting .. ".channel_range")) or 5
		local p = core.localplayer:get_pos()
		local nds = core.find_nodes_near(p, range, water, true)
		for _, v in pairs(nds) do
			for __, vv in pairs(waterbowl) do
				local tp = vector.add(v, vv)
				ws.place(tp, dirt)
			end
			local airs = core.find_nodes_in_area(v:offset(-channel, 0, -channel), v:offset(channel, 0, channel), {"air", "mcl_core:water_flowing"})
			for _, vv in pairs(airs) do
				ws.place(vv, dirt)
			end
		end
	end,
	cheat_settings = {
		range = { type = "number", default = 5, min = 1, max = 20 },
		channel_range = { type = "number", default = 5, min = 1, max = 20 },
	},
})

local function find_soil(pos, r)
	return minetest.find_nodes_in_area_under_air(pos:offset(-r, -r, -r), pos:offset(r, r, r), farmsoil)
end

sbots.register_bot("FarmBot", {
	spos = vector.new(0, 0, 0),
	on_activate = function(self)
		self.start_pos = core.localplayer:get_pos()
		core.settings:set_bool("block_lava_sources", true)
	end,
	get_spos = function(self)
		return core.localplayer:get_pos()
	end,
	find_pos = function(self, pos)
		self.spos = self:get_spos()
		local nds = find_soil(pos, 35)
		if not nds or #nds == 0 then return end
		table.sort(nds, function(a, b) return vector.distance(self.spos, a) < vector.distance(self.spos, b) end)
		return nds[1]
	end,
	do_pos = function(self, pos)
		table.shuffle(seed_items)
		for _, v in pairs(find_soil(pos, 4)) do
			ws.place(v:offset(0, 1, 0), seed_items)
		end
		return true
	end,
})
