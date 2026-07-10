local function swim_up()
	if not core.localplayer then return end
	local pos = core.localplayer:get_pos()
	local above = core.get_node_or_nil({x = pos.x, y = pos.y + 2, z = pos.z})
	if not above or above.name == "air"
		or above.name == "ignore" then
		core.localplayer:set_pos({
			x = pos.x, y = pos.y + 2, z = pos.z,
		})
	end
end

local function check_and_swim()
	if not core.localplayer then return end
	if not core.localplayer:is_in_liquid() then return end
	local breath = core.localplayer:get_breath()
	local threshold = ws.get_number("auto_swim", "breath_threshold", 3)
	if breath <= threshold then
		swim_up()
	end
end

core.register_on_breath_changed(function()
	if core.settings:get_bool("auto_swim") then
		check_and_swim()
	end
end)

ws.rg("AutoSwimUp", {
	category = "Movement",
	setting = "auto_swim",
	description = "Automatically swim up when breath is low",
	delay = 0.5,

	on_step = function()
		check_and_swim()
	end,

	cheat_settings = {
		breath_threshold = { type = "int", default = 3, min = 1, max = 10 },
	},
})
