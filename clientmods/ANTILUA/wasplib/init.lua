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

-- No-op stub for legacy register_list_command calls
function core.register_list_command() end

dofile(core.get_modpath("wasplib") .. "/settings.lua")
dofile(core.get_modpath("wasplib") .. "/coord.lua")
dofile(core.get_modpath("wasplib") .. "/inventory.lua")
dofile(core.get_modpath("wasplib") .. "/tools.lua")
dofile(core.get_modpath("wasplib") .. "/world.lua")
dofile(core.get_modpath("wasplib") .. "/combat.lua")
dofile(core.get_modpath("wasplib") .. "/waypoints.lua")
dofile(core.get_modpath("wasplib") .. "/compat.lua")
dofile(core.get_modpath("wasplib") .. "/notification.lua")

local cheat_defaults = {

	on_step   = function() end,
	on_start  = function() end,
	on_stop   = function() end,
	daughters = {},
	delay     = 0.2,
}

local startup_done = false

function ws.globalhacktemplate(def)
	local setting = def.setting
	return function(dtime)
		if not core.localplayer then return end
		if core.settings:get_bool(setting) then
			if tps_client and tps_client.ping and tps_client.ping > 1000 then return end
			if nextact[setting] and nextact[setting] > os.clock() then return end
			nextact[setting] = os.clock() + (def.delay or 0.2)
			if not ghwason[setting] then
				local ok, msg = def.on_start(def)
				if ok ~= false then
					if startup_done then
						ws.notify_cheat(def.name, true)
					end
					ws.set_bool_bulk(def.daughters, true)
					ghwason[setting] = true
				else
					if startup_done then
						ws.notify(msg or (def.name .. " failed to activate"), ws.NOTIFY_ERROR)
					end
					core.settings:set_bool(setting, false)
				end
			else
				def.on_step(def, dtime)
			end
		elseif ghwason[setting] then
			ghwason[setting] = false
			ws.set_bool_bulk(def.daughters, false)
			if startup_done then
				ws.notify_cheat(def.name, false)
			end
			def.on_stop(def)
		end
	end
end

function ws.register_globalhack(func)
	table.insert(ws.registered_globalhacks, func)
end

function ws.register_globalhacktemplate(name, ...)
	local def
	if type(name) == "string" and type(select(1, ...)) == "table" then
		-- New style: ws.rg("name", def_table)
		def = select(1, ...)
		def.name = name
		setmetatable(def, { __index = cheat_defaults })
		ws.register_globalhack(ws.globalhacktemplate(def))
		core.register_cheat(def.name, def)
	elseif type(name) == "string" then
		-- Old style: ws.rg("name", "Category", "setting", func, funcstart, funcstop, daughters, delay)
		-- Wrap old-style functions: they expect (dtime) not (self, dtime)
		local category, setting, func, funcstart, funcstop, daughters, delay = ...
		local f = func
		local fs = funcstart
		local fe = funcstop
		def = {
			category  = category,
			setting   = setting,
			on_step   = function(_, dtime) if f then f(dtime) end end,
			on_start  = function(_) if fs then return fs() end end,
			on_stop   = function(_) if fe then fe() end end,
			daughters = daughters,
			delay     = delay,
		}
		ws.register_globalhacktemplate(name, def)
	end
end

ws.rg = ws.register_globalhacktemplate

dofile(core.get_modpath("wasplib") .. "/integrations.lua")


function ws.step_globalhacks(dtime)
	for i, v in ipairs(ws.registered_globalhacks) do
		v(dtime)
	end
	startup_done = true
end

core.register_globalstep(function(dtime) ws.step_globalhacks(dtime) end)
core.settings:set_bool('continuous_forward', false)

function ws.on_connect(func)
	if not core.localplayer then
		core.after(0, function() ws.on_connect(func) end)
		return
	end
	if func then func() end
end

core.register_chatcommand('giveme', {
	func = function(param)
		for k, v in ipairs(nlist.get(nlist.selected)) do
			core.send_chat_message("/giveme " .. v .. " -1")
		end
	end
})

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

--
-- AutoSneak and AutoSprint keypress cheats (merged from autokey)
--

if ws.register_keypress_cheat then
	ws.register_keypress_cheat("autosneak", "AutoSneak", "Movement", "sneak", function()
		return core.localplayer:is_touching_ground()
	end, "Automatically sneak when moving")
	ws.register_keypress_cheat("autosprint", "AutoSprint", "Movement", "aux1", nil, "Automatically sprint when moving")
end
