local GROUP = 9999
local REF_GROUP = 9998

ws.rg("ShowRange", {
	category = "Render",
	setting = "show_range",
	delay = 0,
	cheat_settings = {
		range = { default = 6.6, min = 1, max = 50 },
	},
	on_step = function()
		core.draw3d:clear(GROUP)
		core.draw3d:clear(REF_GROUP)

		local pos = core.localplayer and core.localplayer:get_pos()
		if not pos then return end

		local r = tonumber(core.settings:get("show_range.range")) or 6.6

		-- Reference: 10-block line with tick marks
		for i = 0, 10 do
			core.draw3d:add_line(
				{x = pos.x + i, y = pos.y - 0.3, z = pos.z},
				{x = pos.x + i, y = pos.y + 0.3, z = pos.z},
				"#FFFF00", REF_GROUP)
		end
		core.draw3d:add_line(pos, {x = pos.x + 10, y = pos.y, z = pos.z}, "#FF0000", REF_GROUP)

		-- Range sphere
		core.draw3d:add_wiresphere(pos, r, "#FFFFFF", 48, GROUP)
	end,
	on_stop = function()
		core.draw3d:clear(GROUP)
		core.draw3d:clear(REF_GROUP)
	end,
})
