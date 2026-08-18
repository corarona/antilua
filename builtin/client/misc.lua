function core.setting_get_pos(name)
	local value = core.settings:get(name)
	if not value then
		return nil
	end
	return core.string_to_pos(value)
end


-- old non-method sound functions

-- Sync nlist to C++ for Node ESP and Node Tracers
local last_node_esp_list = ""
core.register_globalstep(function()
	if not (core.settings:get_bool("enable_node_esp") or core.settings:get_bool("enable_node_tracers")) then
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

--------------------------------------------------------------------------------
-- Mirrors of server-side builtin API functions (pure-Lua, client-local data)
--------------------------------------------------------------------------------

function core.hash_node_position(pos)
	return (pos.z + 0x8000) * 0x100000000 + (pos.y + 0x8000) * 0x10000 + (pos.x + 0x8000)
end

function core.get_position_from_hash(hash)
	local x = (hash % 65536) - 32768
	hash  = math.floor(hash / 65536)
	local y = (hash % 65536) - 32768
	hash  = math.floor(hash / 65536)
	local z = (hash % 65536) - 32768
	return vector.new(x, y, z)
end

-- Client-side mirror of core.get_item_group. The client's core.registered_items
-- table is empty, so look the groups up via the item/node definition managers.
function core.get_item_group(name, group)
	local def = core.get_item_def(name)
	if not def then
		local n = core.get_node_def(name)
		if not n then
			return 0
		end
		return n.groups[group] or 0
	end
	return def.groups[group] or 0
end

-- See l_env.cpp for the other functions
function core.get_artificial_light(param1)
	return math.floor(param1 / 16)
end

function core.get_pointed_thing_position(pointed_thing, above)
	if pointed_thing.type == "node" then
		if above then
			-- The position where a node would be placed
			return pointed_thing.above
		end
		-- The position where a node would be dug
		return pointed_thing.under
	elseif pointed_thing.type == "object" then
		return pointed_thing.ref and pointed_thing.ref:get_pos()
	end
end

function core.is_player(player)
	-- a table being a player is also supported because it quacks sufficiently
	-- like a player if it has the is_player function
	local t = type(player)
	return (t == "userdata" or t == "table") and
		type(player.is_player) == "function" and player:is_player()
end

-- Last received player inventory formspec (formname ""), captured from the
-- TOCLIENT_INVENTORY_FORMSPEC packet so creative inventories can be sniffed.
local last_inventory_formspec = ""
core.register_on_receiving_inventory_form(function(formname, formspec)
	if formname ~= "" then
		return formspec
	end
	last_inventory_formspec = formspec
	return formspec
end)

core.register_on_disconnect(function()
	last_inventory_formspec = ""
end)

-- Mineclonia/VoxeLibre detect creative mode from the creative inventory
-- formspec (the detached:creative_<name> item grid); all other games use
-- the "creative" privilege.
function core.is_creative_enabled()
	if core.get_item_def("mcl_core:stone") then
		return last_inventory_formspec:find("detached:creative_", 1, true) ~= nil
	end
	return core.get_privilege_list().creative == true
end

function core.itemstring_with_palette(item, palette_index)
	local stack = ItemStack(item) -- convert to ItemStack
	stack:get_meta():set_int("palette_index", palette_index)
	return stack:to_string()
end

function core.itemstring_with_color(item, colorstring)
	local stack = ItemStack(item) -- convert to ItemStack
	stack:get_meta():set_string("color", colorstring)
	return stack:to_string()
end

-- get_node implementation (mirrors builtin/game/item.lua)
function core.get_node(pos)
	local content, param1, param2 = core.get_node_raw(pos.x, pos.y, pos.z)
	return {name = core.get_name_from_content_id(content), param1 = param1, param2 = param2}
end

-- Returns two position vectors representing a box of `radius` in each
-- direction centered around the given player (client-side, local player only)
function core.get_player_radius_area(player_name, radius)
	local player = core.get_player_by_name(player_name)
	if player == nil then
		return nil
	end

	local p1 = player:get_pos()
	local p2 = p1

	if radius then
		p1 = vector.subtract(p1, radius)
		p2 = vector.add(p2, radius)
	end

	return p1, p2
end
