-- SchematicLooter: scan nearby containers for items needed by the current schematic
ws.rg("SchematicLooter", {
	category = "Inventory",
	setting = "schematic_looter",
	description = "Auto-loot materials from schematics",
	on_step = function(self, dtime)
		-- Dynamic delay from setting
		local interval = tonumber(core.settings:get("schematic_looter.delay")) or 1
		self._looter_timer = (self._looter_timer or 0) + dtime
		if self._looter_timer < interval then return end
		self._looter_timer = 0
		if #place_nodes == 0 then return end
		local items = {}
		local seen = {}
		for _, entry in ipairs(place_nodes) do
			if entry.name ~= "air" and entry.name ~= "ignore" and not seen[entry.name] then
				seen[entry.name] = true
				table.insert(items, entry.name)
			end
		end
		if #items == 0 then return end
		local range = tonumber(core.settings:get("schematic_looter.range")) or 5
		local max_per = tonumber(core.settings:get("schematic_looter.max_per_scan")) or 16

		if core.localplayer then
			local pos = core.localplayer:get_pos()
			local minp = vector.offset(pos, -range, -range, -range)
			local maxp = vector.offset(pos, range, range, range)
			for _, cpos in ipairs(core.find_nodes_with_meta(minp, maxp)) do
				add_supply_chest(cpos)
			end
		end

		ws.loot_list(items, range, max_per)
	end,
	cheat_settings = {
		range = { type = "number", default = 5, min = 1, max = 20 },
		max_per_scan = { type = "number", default = 16, min = 1, max = 64 },
		delay = { type = "number", default = 1, min = 0.1, max = 60 },
	},
})
