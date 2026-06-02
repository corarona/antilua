-- Sponge/hole-digging operations (from scaffold/spongebot.lua)

ws.rg("DigFreeSponge", {
	category = "Dig",
	setting = "autospongedig",
	on_step = function(self)
		local range = tonumber(core.settings:get(self.setting .. ".range")) or 4
		local water_dist = tonumber(core.settings:get(self.setting .. ".water_distance")) or 6
		local lp = minetest.localplayer:get_pos()
		for _, sp in pairs(minetest.find_nodes_near(lp, range, {"mcl_sponges:sponge", "mcl_sponges:sponge_wet"})) do
			if not minetest.find_node_near(sp, water_dist, "mcl_core:water_source") then
				ws.dig(sp)
			end
		end
	end,
	cheat_settings = {
		range = { type = "number", default = 4, min = 1, max = 20 },
		water_distance = { type = "number", default = 6, min = 1, max = 20 },
	},
})

local digcyl_mid
local digcyl_rad

minetest.register_chatcommand("digcyl", {
	description = "Set dig cylinder center",
	params = "[x,y,z]",
	func = function(p)
		local pos = minetest.string_to_pos(p)
		if pos then
			digcyl_mid = pos
			ws.notify("Digcyl center set to " .. p, ws.NOTIFY_INFO, {toast=false})
		else
			digcyl_mid = ws.dircoord(0, 0, 0)
			ws.notify("Digcyl center set to player pos", ws.NOTIFY_INFO, {toast=false})
		end
	end,
})

minetest.register_chatcommand("digcyl_rad", {
	description = "Set dig cylinder radius",
	params = "<radius>",
	func = function(p)
		local n = tonumber(p)
		if n then
			digcyl_rad = n
			ws.notify("Digcyl radius set to " .. n, ws.NOTIFY_INFO, {toast=false})
		end
	end,
})

ws.rg("Digcyl", {
	category = "Dig",
	setting = "digcyl",
	on_step = function(self)
		if not digcyl_mid or not digcyl_rad then return end
		local floor_y = tonumber(core.settings:get(self.setting .. ".floor_y")) or -125
		local lp = minetest.localplayer:get_pos()
		for _, v in pairs(minetest.find_nodes_near(lp, ws.range, nlist.get(nlist.selected), true)) do
			local n = minetest.get_node_or_nil(v)
			if v.y > floor_y and vector.distance(vector.new(v.x, 0, v.z), vector.new(digcyl_mid.x, 0, digcyl_mid.z)) < digcyl_rad and n and n.name ~= "air" then
				ws.dig(v)
			end
		end
	end,
	delay = 2,
	cheat_settings = {
		floor_y = { type = "number", default = -125, min = -31000, max = 31000 },
	},
})
