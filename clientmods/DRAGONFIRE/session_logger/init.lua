-- Session logger: merged from cchat + session_stats

local mod_name = minetest.get_current_modname()

local function log(level, message)
	minetest.log(level, ('[%s] %s'):format(mod_name, message))
end

local LOG_LEVEL = 'action'
local server_info = minetest.get_server_info()
local server_id = server_info.address .. ':' .. server_info.port
local my_name = ''

--
-- Chat logging (from cchat)
--

local function safe(func)
	return function(...)
		local status, out = pcall(func, ...)
		if status then
			return out
		else
			log('warning', 'Error (func): ' .. out)
			return nil
		end
	end
end

core.register_on_receiving_chat_message(safe(function(message)
	local msg = core.strip_colors(message)
	if msg ~= '' then
		log(LOG_LEVEL, ('%s@%s %s'):format(my_name, server_id, msg))
	end
end))

--
-- Session stats (from session_stats)
--

local start_time = 0
local deaths = 0
local damage_taken = 0

core.register_on_connect(function()
	start_time = os.clock()
	deaths = 0
	damage_taken = 0
	ws.notify("Session started", ws.NOTIFY_INFO, {toast = false})
end)

core.register_on_death(function()
	deaths = deaths + 1
end)

core.register_on_damage_taken(function(amount)
	damage_taken = damage_taken + amount
end)

core.registered_chatcommands["stats"] = {
	params = "",
	description = "Show session stats (play time, deaths, damage)",
	func = function()
		local elapsed = os.clock() - start_time
		local hours = math.floor(elapsed / 3600)
		local minutes = math.floor((elapsed % 3600) / 60)
		local seconds = math.floor(elapsed % 60)
		local time_str = string.format("%dh %dm %ds", hours, minutes, seconds)
		core.display_chat_message(string.format(
			"Session: %s | Deaths: %d | Damage taken: %d",
			time_str, deaths, damage_taken))
		return true
	end,
}
