local GROUP = 9999
local DEBUG_GROUP = 9998

ws.rg("ShowRange", {
	category = "Render",
	setting = "show_range",
	delay = 0,
	cheat_settings = {
		range = { default = 6.6, min = 1, max = 50 },
	},
	on_step = function()
		core.draw3d:clear(GROUP)
		core.draw3d:clear(DEBUG_GROUP)

		local pos = core.localplayer and core.localplayer:get_pos()
		if not pos then return end

		local r = tonumber(core.settings:get("show_range.range")) or 6.6

		core.draw3d:add_wiresphere(pos, r, "#FFFFFFFF", 48, GROUP)
		core.draw3d:add_wirebox(
			{x = pos.x - r, y = pos.y - r, z = pos.z - r},
			{x = pos.x + r, y = pos.y + r, z = pos.z + r},
			"#FF0000", DEBUG_GROUP
		)
	end,
	on_stop = function()
		core.draw3d:clear(GROUP)
		core.draw3d:clear(DEBUG_GROUP)
	end,
})
