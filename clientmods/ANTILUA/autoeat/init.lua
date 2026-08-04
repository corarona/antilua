autoeat = {}

local HUD_STAT_NUMBER = 4
local HUD_STAT_ITEM = 5

local hunger = 20
local hunger_id = nil
local hunger_scale = 20

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

local function set_hunger(number)
	hunger = math.max(0, math.min(20, math.floor(number * 20 / hunger_scale + 0.5)))
end

function autoeat.get_hunger()
	return hunger
end

local function on_hud_add(def)
	if def.text == "hbhunger_icon.png" then
		hunger_id = def.server_id
		if def.item and def.item > 0 then
			hunger_scale = def.item
		end
		set_hunger(def.number)
	elseif def.text == "hbhunger_bar.png" then
		hunger_id = def.server_id
		hunger_scale = 160
		set_hunger(def.number)
	end
	return nil
end

local function on_hud_change(id, stat, sdata, v2fdata, v3fdata, intdata)
	if id == hunger_id then
		if stat == HUD_STAT_NUMBER then
			set_hunger(intdata)
		elseif stat == HUD_STAT_ITEM then
			if intdata == 0 then
				hunger = 20
			else
				hunger_scale = intdata
			end
		end
	end
	return nil
end

local function on_hud_remove(id)
	if id == hunger_id then
		hunger_id = nil
		hunger = 20
	end
	return nil
end

core.register_on_hud_add(on_hud_add)
core.register_on_hud_change(on_hud_change)
core.register_on_hud_remove(on_hud_remove)

autoeat._on_hud_add = on_hud_add
autoeat._on_hud_change = on_hud_change
autoeat._on_hud_remove = on_hud_remove
autoeat._reset = function()
	hunger = 20
	hunger_id = nil
	hunger_scale = 20
end

ws.rg("AutoEat",
	{
		category = "Player",
		setting = "autoeat",
		description = "Auto-eat food when hungry",
		on_step = function()
			local h = autoeat.get_hunger()
			if h < 20 and (core.settings:get_bool("autoeat.always_eat", false) or h < tonumber(core.settings:get("autoeat.hunger_threshold"))) then
				autoeat.eat()
			end
		end,
		cheat_settings = {
			always_eat = { type = "bool", default = false },
			hunger_threshold = { type = "number", default = 15, min = 1, max = 19 },
		},
})
