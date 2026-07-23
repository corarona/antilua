function core.setting_get_pos(name)
	local value = core.settings:get(name)
	if not value then
		return nil
	end
	return core.string_to_pos(value)
end


-- old non-method sound functions

-- Sync nlist to C++ for Node ESP
local last_node_esp_list = ""
core.register_globalstep(function()
	if not core.settings:get_bool("enable_node_esp") then
		last_node_esp_list = ""
		return
	end
	if not nlist then
		return
	end
	local current = table.concat(nlist.get(nlist.selected), ",")
	if current ~= last_node_esp_list then
		last_node_esp_list = current
		core.set_node_esp_list(nlist.get(nlist.selected))
	end
end)

function core.sound_stop(handle, ...)
	return handle:stop(...)
end

function core.sound_fade(handle, ...)
	return handle:fade(...)
end
