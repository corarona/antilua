async(function()
	while true do
		if minetest.settings:get_bool("digcustom") and minetest.localplayer then
			local list = (minetest.settings:get("digcustom_nodes") or ""):split(",")
			local node_pos = minetest.find_node_near(minetest.localplayer:get_pos(), 5, list, true)
			local max_time = tonumber(minetest.settings:get("digcustom_max_time"))

			if node_pos then
				await(diglib.dig_node(node_pos, max_time))
			end
		end

		lua_async.yield()
	end
end)()

minetest.register_list_command("digcustom", "Configue custom autodig nodes", "digcustom_nodes")

minetest.register_cheat("DigCustom", "World", "digcustom")
