function ws.find_item_in_table(items, rnd)
	if type(items) == 'string' then
		return minetest.find_item(items)
	end
	if type(items) ~= 'table' then return end
	if rnd then items = ws.shuffle(items) end
	for i, v in pairs(items) do
		local n = minetest.find_item(v)
		if n then
			return n
		end
	end
	return false
end

function ws.find_empty(inv)
	for i, v in ipairs(inv) do
		if v:is_empty() then
			return i
		end
	end
	return false
end

function ws.count_empty_slots(inv)
	local n = 0
	for i, v in ipairs(inv) do
		if v:is_empty() then
			n = n + 1
		end
	end
	return n
end

function ws.find_named(inv, name)
	if not inv then return -1 end
	if not name then return end
	for i, v in ipairs(inv) do
		if v:get_name() == name then
			return i
		end
	end
end

function ws.itemnameformat(description)
	description = description:gsub(string.char(0x1b) .. "%(.@[^)]+%)", "")
	description = description:match("([^\n]*)")
	return description
end

function ws.find_nametagged(list, name)
	for i, v in ipairs(list) do
		if ws.itemnameformat(v:get_description()) == name then
			return i
		end
	end
end

function ws.to_hotbar(it, hslot)
	local tpos = nil
	local plinv = minetest.get_inventory("current_player")
	if hslot and hslot < 10 then
		tpos = hslot
	else
		for i, v in ipairs(plinv.main) do
			if i < 10 and v:is_empty() then
				tpos = i
				break
			end
		end
	end
	if tpos == nil then tpos = ws.hotbar_slot end
	local mv = InventoryAction("move")
	mv:from("current_player", "main", it)
	mv:to("current_player", "main", tpos)
	mv:apply()
	return tpos
end

function ws.switch_to_item(itname, hslot)
	if not minetest.localplayer then return false end
	local plinv = minetest.get_inventory("current_player")
	for i, v in ipairs(plinv.main) do
		if i < 10 and v:get_name() == itname then
			minetest.localplayer:set_wield_index(i)
			return true
		end
	end
	local pos = ws.find_named(plinv.main, itname)
	if pos then
		minetest.localplayer:set_wield_index(ws.to_hotbar(pos, hslot))
		return true
	end
	return false
end

function ws.in_inv(itname)
	if not minetest.localplayer then return false end
	local plinv = minetest.get_inventory("current_player")
	local pos = ws.find_named(plinv.main, itname)
	if pos then
		return true
	end
end

function ws.inv_full(item_to_add)
	if not core.localplayer then return true end
	local plinv = core.get_inventory("current_player")
	for _, v in pairs(plinv.main) do
		if v:is_empty() or (item_to_add and v:get_name() == item_to_add and v:get_count() < v:get_stack_max()) then
			return false
		end
	end
	return true
end

function ws.inv_get_space(item_to_add)
	if not core.localplayer then return 0 end
	local plinv = core.get_inventory("current_player")
	local its = item_to_add and ItemStack(item_to_add):get_stack_max() or 99
	local i = 0
	for _, v in pairs(plinv.main) do
		if v:is_empty() then
			i = i + its
		elseif v:get_name() == item_to_add and v:get_count() < its then
			i = i + its - v:get_count()
		end
	end
	return i
end

function core.switch_to_item(item)
	return ws.switch_to_item(item)
end

function ws.switch_inv_or_echest(name, max_count, hslot)
	if not minetest.localplayer then return false end
	local plinv = minetest.get_inventory("current_player")
	if ws.switch_to_item(name) then return true end

	local epos = ws.find_named(plinv.enderchest, name)
	if epos then
		local tpos
		for i, v in ipairs(plinv.main) do
			if i < 9 and v:is_empty() then
				tpos = i
				break
			end
		end
		if not tpos then tpos = ws.hotbar_slot end

		if tpos then
			local mv = InventoryAction("move")
			mv:from("current_player", "enderchest", epos)
			mv:to("current_player", "main", tpos)
			if max_count then
				mv:set_count(max_count)
			end
			mv:apply()
			minetest.localplayer:set_wield_index(tpos)
			return true
		end
	end
	return false
end

local function posround(n)
	return math.floor(n + 0.5)
end

local function fmt(c)
	return tostring(posround(c.x)) .. "," .. tostring(posround(c.y)) .. "," .. tostring(posround(c.z))
end

local function map_pos(value)
	if value.x then
		return value
	else
		return {x = value[1], y = value[2], z = value[3]}
	end
end

function ws.invparse(location)
	if type(location) == "string" then
		if string.match(location, "^[-]?[0-9]+,[-]?[0-9]+,[-]?[0-9]+$") then
			return "nodemeta:" .. location
		else
			return location
		end
	elseif type(location) == "table" then
		return "nodemeta:" .. fmt(map_pos(location))
	end
end

function ws.invpos(p)
	return "nodemeta:" .. p.x .. "," .. p.y .. "," .. p.z
end
