function ws.s(name, value)
	if value == nil then
		return ws.c.settings:get(name)
	else
		ws.c.settings:set(name, value)
		return ws.c.settings:get(name)
	end
end

function ws.sb(name, value)
	if value == nil then
		return ws.c.settings:get_bool(name)
	else
		ws.c.settings:set_bool(name, value)
		return ws.c.settings:get_bool(name)
	end
end

function ws.dcm(msg)
	return core.display_chat_message(msg)
end

function ws.set_bool_bulk(settings, value)
	if type(settings) ~= 'table' then return false end
	for k, v in pairs(settings) do
		core.settings:set_bool(v, value)
	end
	return true
end

function ws.shuffle(tbl)
	for i = #tbl, 2, -1 do
		local j = math.random(i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
	return tbl
end

function ws.in_list(val, list)
	if type(list) ~= "table" then return false end
	for i, v in pairs(list) do
		if v == val then
			return true
		end
	end
	return false
end

function ws.random_table_element(tbl)
	local ks = {}
	for k in pairs(tbl) do
		table.insert(ks, k)
	end
	return tbl[ks[math.random(#ks)]]
end

function ws.register_chatcommand_alias(old, ...)
	local def = assert(core.registered_chatcommands[old])
	def.name = nil
	for i = 1, select('#', ...) do
		core.register_chatcommand(select(i, ...), table.copy(def))
	end
end

function ws.round2(num, numDecimalPlaces)
	return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end

function ws.pos_to_string(pos)
	if type(pos) == 'table' then
		pos = core.pos_to_string(vector.round(pos))
	end
	if type(pos) == 'string' then
		return pos
	end
	return pos
end

function ws.string_to_pos(pos)
	if type(pos) == 'string' then
		pos = core.string_to_pos(pos)
	end
	if type(pos) == 'table' then
		return vector.round(pos)
	end
	return pos
end

function ws.get_number(setting, key, default)
	return tonumber(core.settings:get(setting .. "." .. key)) or default
end

function ws.get_bool(setting, key, default)
	local v = core.settings:get(setting .. "." .. key)
	if v == "" then return default end
	return v == "true"
end

function ws.between(x, y, z)
	return y <= x and x <= z
end
