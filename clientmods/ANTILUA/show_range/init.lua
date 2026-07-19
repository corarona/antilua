local GROUP = 9999

local function add_box_lines(pos, r, color, group)
	local mi = {x = pos.x - r, y = pos.y - r, z = pos.z - r}
	local ma = {x = pos.x + r, y = pos.y + r, z = pos.z + r}

	local function line(a, b)
		core.draw3d:add_line(a, b, color, group)
	end

	line({x = mi.x, y = mi.y, z = mi.z}, {x = ma.x, y = mi.y, z = mi.z})
	line({x = ma.x, y = mi.y, z = mi.z}, {x = ma.x, y = mi.y, z = ma.z})
	line({x = ma.x, y = mi.y, z = ma.z}, {x = mi.x, y = mi.y, z = ma.z})
	line({x = mi.x, y = mi.y, z = ma.z}, {x = mi.x, y = mi.y, z = mi.z})
	line({x = mi.x, y = ma.y, z = mi.z}, {x = ma.x, y = ma.y, z = mi.z})
	line({x = ma.x, y = ma.y, z = mi.z}, {x = ma.x, y = ma.y, z = ma.z})
	line({x = ma.x, y = ma.y, z = ma.z}, {x = mi.x, y = ma.y, z = ma.z})
	line({x = mi.x, y = ma.y, z = ma.z}, {x = mi.x, y = ma.y, z = mi.z})
	line({x = mi.x, y = mi.y, z = mi.z}, {x = mi.x, y = ma.y, z = mi.z})
	line({x = ma.x, y = mi.y, z = mi.z}, {x = ma.x, y = ma.y, z = mi.z})
	line({x = ma.x, y = mi.y, z = ma.z}, {x = ma.x, y = ma.y, z = ma.z})
	line({x = mi.x, y = mi.y, z = ma.z}, {x = mi.x, y = ma.y, z = ma.z})
end

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

		-- Scale reference: 1-block cube + 10-block line with tick marks
		add_box_lines(pos, 0.5, "#00FF00", GROUP)
		for i = 0, 10 do
			core.draw3d:add_line(
				{x = pos.x + i, y = pos.y - 0.3, z = pos.z},
				{x = pos.x + i, y = pos.y + 0.3, z = pos.z},
				"#FFFF00", GROUP)
		end
		core.draw3d:add_line(pos, {x = pos.x + 10, y = pos.y, z = pos.z}, "#FF0000", GROUP)

		-- SINGLE diagnostic line from player to pos.x + r
		core.draw3d:add_line(pos,
			{x = pos.x + r, y = pos.y, z = pos.z},
			"#00FFFF", GROUP)

		-- Box using lines via add_line
		add_box_lines(pos, r, "#FF8800", GROUP)

		-- Sphere using add_wiresphere
		core.draw3d:add_wiresphere(pos, r, "#FFFFFF", 48, GROUP)
	end,
	on_stop = function()
		core.draw3d:clear(GROUP)
	end,
})
