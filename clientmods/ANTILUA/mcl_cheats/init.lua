local mpath = core.get_modpath(core.get_current_modname())

-- IceBreaker: dig ice in range
core.register_cheat('IceBreaker', { category = 'Dig', setting = 'icebreaker',
	description = "Break ice by walking on it" })

core.register_globalstep(function()
	if not core.settings:get_bool("icebreaker") then return end
	if not core.localplayer then return end
	local owx = core.localplayer:get_wield_index()
	local nds = core.find_nodes_near(ws.dircoord(0, 0, 0), 4, {'mcl_core:ice'}, true)
	ws.dignodes(nds)
	core.localplayer:set_wield_index(owx)
end)

-- Givegear: spawn full diamond gear with enchants
core.register_chatcommand('givegear', {
	func = function(param)
		local armor = {
			"mcl_armor:helmet_diamond",
			"mcl_armor:chestplate_diamond",
			"mcl_armor:leggings_diamond",
			"mcl_armor:boots_diamond"
		}
		local tools = {
			"mcl_tools:sword_diamond",
			"mcl_tools:pick_diamond",
			"mcl_tools:axe_diamond",
			"mcl_tools:shovel_diamond",
			"mcl_core:apple_gold_enchanted -1"
		}
		for k, v in ipairs(tools) do
			core.send_chat_message("/giveme " .. v)
		end
		for k, v in ipairs(armor) do
			core.send_chat_message("/giveme " .. v)
		end
		core.after(1, function()
			local name = core.localplayer:get_name()
			for k, v in ipairs(tools) do
				ws.switch_to_item(v)
				core.send_chat_message("/forceenchant " .. name .. " unbreaking 3")
				core.send_chat_message("/forceenchant " .. name .. " mending")
			end
			for k, v in ipairs(armor) do
				ws.switch_to_item(v)
				core.send_chat_message("/forceenchant " .. name .. " unbreaking 3")
				core.send_chat_message("/forceenchant " .. name .. " protection 4")
			end
		end)
	end
})