ws = {}
ws.registered_globalhacks = {}
ws.displayed_wps = {}
ws.c = core
ws.range = 4
ws.hotbar_slot = 8

local nextact = {}
local ghwason = {}
local state = {}

local games = {
	["mcl_core:stone"] = "mcl",
	["default:stone"] = "mtg",
	["nc_core:sonte"] = "nc",
	["default"] = "unknown",

}

function ws.get_game()
	for nd, game in pairs(games) do
		if core.get_item_def(nd) then
			return game
		end
	end
	return "unknown"
end

dofile(core.get_modpath("wasplib") .. "/settings.lua")
dofile(core.get_modpath("wasplib") .. "/coord.lua")
dofile(core.get_modpath("wasplib") .. "/inventory.lua")
dofile(core.get_modpath("wasplib") .. "/tools.lua")
dofile(core.get_modpath("wasplib") .. "/world.lua")
dofile(core.get_modpath("wasplib") .. "/combat.lua")
dofile(core.get_modpath("wasplib") .. "/waypoints.lua")
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
			if nextact[setting] and nextact[setting] > core.get_us_time() / 1000000 then return end
			nextact[setting] = core.get_us_time() / 1000000 + (def.delay or 0.2)
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

core.register_chatcommand('giveme', {
	func = function(param)
		for k, v in ipairs(nlist.get(nlist.selected)) do
			core.send_chat_message("/giveme " .. v .. " -1")
		end
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

-- Lifecycle registries: shared on_death / on_connect / on_disconnect
local on_death_callbacks = {}
local on_connect_callbacks = {}

function ws.on_death(fn)
	table.insert(on_death_callbacks, fn)
end

function ws.on_connect(fn)
	table.insert(on_connect_callbacks, fn)
end

core.register_on_death(function()
	for _, fn in ipairs(on_death_callbacks) do
		fn()
	end
end)

core.register_on_connect(function()
	for _, fn in ipairs(on_connect_callbacks) do
		fn()
	end
end)
