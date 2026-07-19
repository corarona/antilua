local GROUP = 9999

ws.rg("ShowRange", {
	category = "Render",
	setting = "show_range",
	delay = 0,
	cheat_settings = {
		range = { default = 6.6, min = 1, max = 50 },
	},
	on_step = function()
		core.draw3d:clear(GROUP)

		local pos = core.localplayer and core.localplayer:get_pos()
		if not pos then return end

		local r = tonumber(core.settings:get("show_range.range")) or 6.6

		-- Draw a 1-node reference cube at player feet (should be 1x1x1 block)
		core.draw3d:add_wirebox(
			{x = pos.x - 0.5, y = pos.y - 0.5, z = pos.z - 0.5},
			{x = pos.x + 0.5, y = pos.y + 0.5, z = pos.z + 0.5},
			"#00FF00", GROUP
		)

		-- 10-node line along X axis from player (should cover 10 blocks)
		core.draw3d:add_line(
			pos,
			{x = pos.x + 10, y = pos.y, z = pos.z},
			"#FF0000", GROUP
		)

		-- Tick marks every block along the line
		for i = 1, 10 do
			core.draw3d:add_line(
				{x = pos.x + i, y = pos.y - 0.3, z = pos.z},
				{x = pos.x + i, y = pos.y + 0.3, z = pos.z},
				"#FFFF00", GROUP
			)
		end

		-- Sphere at radius r
		core.draw3d:add_wiresphere(pos, r, "#FFFFFF", 48, GROUP)
	end,
	on_stop = function()
		core.draw3d:clear(GROUP)
	end,
})
