autoeat = {}

local hud_id = nil

function autoeat.eat()
	local food_index
	local food_count = 0
	for index, stack in pairs(core.get_inventory("current_player").main) do
		local stackname = stack:get_name()
		if stackname ~= "" then
			local def = core.get_item_def(stackname)
			if def and def.groups.food then
				food_count = food_count + 1
				if food_index then
					break
				end
				food_index = index
			end
		end
	end
	if food_index then
		local player = core.localplayer
		local old_index = player:get_wield_index()
		player:set_wield_index(food_index)
		if ws.get_game() == "mcl" then
			core.place_node(core.localplayer:get_pos())
		else
			core.interact("activate", {type = "nothing"})
		end
		player:set_wield_index(old_index)
	end
end

function autoeat.get_hunger()
	if hud_id then
		local def = core.localplayer and core.localplayer:hud_get(hud_id)
		if def then return def.number end
	end
	return 20
end

local function find_hud()
	local player = core.localplayer
	if not player then core.after(3, find_hud); return end
	local def
	local i = -1
	repeat
		i = i + 1
		def = player and player:hud_get(i)
	until not def or def.text == "hbhunger_icon.png"
	if def then
		hud_id = i
	end
end

core.after(3, find_hud)

ws.rg("AutoEat",
	{
		category = "Player",
		setting = "autoeat",
		description = "Auto-eat food when hungry",
		on_step = function()
			local hunger = autoeat.get_hunger()
			core.log("hunger: "..tostring(hunger))
			if hunger < 20 and (core.settings:get_bool("autoeat.always_eat", false) or autoeat.get_hunger() < tonumber(core.settings:get("autoeat.hunger_threshold")) ) then
				autoeat.eat()
			end
		end,
		cheat_settings = {
			always_eat = { type = "bool", default = false },
			hunger_treshold = { type = "number", default = 15, min = 1, max = 19 },
		},
})
