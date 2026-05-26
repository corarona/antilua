local mod_name = minetest.get_current_modname()

local function log(level, message)
	minetest.log(level, ('[%s] %s'):format(mod_name, message))
end

local LOG_LEVEL = 'action'

local server_info = minetest.get_server_info()
local server_id = server_info.address .. ':' .. server_info.port
local my_name = ''

local function safe(func)
	return function(...)
		local status, out = pcall(func, ...)
		if status then
			return out
		else
			log('warning', 'Error (func):  ' .. out)
			return nil
		end
	end
end

--[[
core.register_on_sending_chat_message(safe(function(message)
	local msg = core.strip_colors(message)
	if msg ~= '' then
		log(LOG_LEVEL, ('%s@%s [sent] %s'):format(my_name, server_id, msg))
	end
end))
--]]

core.register_on_receiving_chat_message(safe(function(message)
	local msg = core.strip_colors(message)
	if msg ~= '' then
		log(LOG_LEVEL, ('%s@%s %s'):format(my_name, server_id, msg))
	end
end))
