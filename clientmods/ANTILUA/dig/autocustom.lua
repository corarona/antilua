-- DigList: dig all nodes from the selected nlist within range

local diglist_next = 0

ws.rg("DigList", {
	category = "Dig",
	setting = "diglist",
	description = "Dig all nodes from selected nlist in range",
	delay = 0,
	on_step = function(self)
		local now = core.get_us_time() / 1000000
		if now < diglist_next then return end
		diglist_next = now + (tonumber(core.settings:get(self.setting .. ".delay")) or 0.5)

		local range = tonumber(core.settings:get(self.setting .. ".range")) or ws.range
		local lp = core.localplayer:get_pos()
		local tnodes = nlist.get(nlist.selected)
		if #tnodes == 0 then return end
		local nds = core.find_nodes_near(lp, range, tnodes, true)
		if nds then
			for _, n in ipairs(nds) do
				if ws.inside_constraints(n) then
					ws.select_best_tool(n)
					dig.dig_node(n)
					return
				end
			end
		end
	end,
	cheat_settings = {
		range = { type = "number", default = 4, min = 1, max = 20 },
		delay = { type = "number", default = 0.5, min = 0.1, max = 10 },
	},
})
