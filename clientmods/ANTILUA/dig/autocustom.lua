-- DigCustom: auto-dig configurable nodes (from digcustom)

coroutine.wrap(function()
	while true do
		if core.settings:get_bool("digcustom") and core.localplayer then
			local list = (core.settings:get("digcustom_nodes") or ""):split(",")
			local node_pos = core.find_node_near(core.localplayer:get_pos(), 5, list, true)
			local max_time = tonumber(core.settings:get("digcustom_max_time"))
			if node_pos then
				dig.dig_node(node_pos, max_time)
			end
		end
		lua_async.yield()
	end
end)()

core.register_cheat("DigCustom", { category = "Dig", setting = "digcustom", description = "Custom digging pattern" })
