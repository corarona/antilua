ws = {}
ws.registered_globalhacks = {}
ws.displayed_wps = {}
ws.c = core
ws.range = 4
ws.target = nil
ws.targetpos = nil
ws.hotbar_slot = 8

local nextact = {}
local ghwason = {}

if not core.register_cheat then
	function core.register_cheat() end
end

if not core.register_list_command then
	function core.register_list_command() end
end

dofile(minetest.get_modpath("wasplib") .. "/settings.lua")
dofile(minetest.get_modpath("wasplib") .. "/coord.lua")
dofile(minetest.get_modpath("wasplib") .. "/inventory.lua")
dofile(minetest.get_modpath("wasplib") .. "/tools.lua")
dofile(minetest.get_modpath("wasplib") .. "/world.lua")
dofile(minetest.get_modpath("wasplib") .. "/combat.lua")
dofile(minetest.get_modpath("wasplib") .. "/waypoints.lua")

function ws.globalhacktemplate(setting, func, funcstart, funcstop, daughters, delay)
	funcstart = funcstart or function() end
	funcstop = funcstop or function() end
	delay = delay or 0.2
	return function(dtime)
		if not minetest.localplayer then return end
		if minetest.settings:get_bool(setting) then
			if tps_client and tps_client.ping and tps_client.ping > 1000 then return end
			if nextact[setting] and nextact[setting] > os.clock() then return end
			nextact[setting] = os.clock() + delay
			if not ghwason[setting] then
				if not funcstart() then
					ws.set_bool_bulk(daughters, true)
					ghwason[setting] = true
				else
					minetest.settings:set_bool(setting, false)
				end
			else
				func(dtime)
			end
		elseif ghwason[setting] then
			ghwason[setting] = false
			ws.set_bool_bulk(daughters, false)
			funcstop()
		end
	end
end

function ws.register_globalhack(func)
	table.insert(ws.registered_globalhacks, func)
end

function ws.register_globalhacktemplate(name, category, setting, func, funcstart, funcstop, daughters, delay)
	ws.register_globalhack(ws.globalhacktemplate(setting, func, funcstart, funcstop, daughters, delay))
	if minetest.settings:get(setting) == nil then
		minetest.settings:set(setting, "false")
	end
	minetest.register_cheat(name, category, setting)
end

ws.rg = ws.register_globalhacktemplate

function ws.step_globalhacks(dtime)
	for i, v in ipairs(ws.registered_globalhacks) do
		v(dtime)
	end
end

minetest.register_globalstep(function(dtime) ws.step_globalhacks(dtime) end)
minetest.settings:set_bool('continuous_forward', false)

function ws.on_connect(func)
	if not minetest.localplayer then
		minetest.after(0, function() ws.on_connect(func) end)
		return
	end
	if func then func() end
end

-- Debug
local function printwieldedmeta()
	local wi = minetest.localplayer:get_wielded_item()
	ws.dcm(wi:get_name())
	ws.dcm(dump(wi:get_meta():to_table()))
end

local function printptdnodedmeta()
	local m = minetest.get_meta(minetest.get_pointed_thing_position(minetest.get_pointed_thing()))
	ws.dcm(dump(m:to_table()))
end

minetest.register_cheat('ItemMeta', 'Test', printwieldedmeta)
minetest.register_cheat('PtdNodeMeta', 'Test', printptdnodedmeta)

minetest.register_chatcommand('giveme', {
	func = function(param)
		for k, v in ipairs(nlist.get(nlist.selected)) do
			minetest.send_chat_message("/giveme " .. v .. " -1")
		end
	end
})

minetest.register_chatcommand('givegear', {
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
			minetest.send_chat_message("/giveme " .. v)
		end
		for k, v in ipairs(armor) do
			minetest.send_chat_message("/giveme " .. v)
		end
		minetest.after(1, function()
			local name = minetest.localplayer:get_name()
			for k, v in ipairs(tools) do
				ws.switch_to_item(v)
				minetest.send_chat_message("/forceenchant " .. name .. " unbreaking 3")
				minetest.send_chat_message("/forceenchant " .. name .. " mending")
			end
			for k, v in ipairs(armor) do
				ws.switch_to_item(v)
				minetest.send_chat_message("/forceenchant " .. name .. " unbreaking 3")
				minetest.send_chat_message("/forceenchant " .. name .. " protection 4")
			end
		end)
	end
})
