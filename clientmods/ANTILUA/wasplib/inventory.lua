
function ws.find_empty(inv)
	-- Prefer the main inventory above the hotbar so bots keep the hotbar
	-- free for wielding.
	for i, v in ipairs(inv) do
		if i > 9 and v:is_empty() then
			return i
		end
	end
	for i, v in ipairs(inv) do
		if i <= 9 and v:is_empty() then
			return i
		end
	end
	return false
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


function ws.to_hotbar(it, hslot)
	local plinv = core.get_inventory("current_player")
	local tpos
	if hslot and hslot < 10 and plinv.main[hslot]:is_empty() then
		tpos = hslot
	else
		for i = 1, 9 do
			if plinv.main[i]:is_empty() then
				tpos = i
				break
			end
		end
	end
	if tpos == nil then
		-- Hotbar is full: swap the source stack into a hotbar slot via any
		-- free main slot. Without a free slot there is nothing to do.
		local empty = ws.find_empty(plinv.main)
		if not empty then
			return nil
		end
		tpos = hslot or ws.hotbar_slot or 8
		if not plinv.main[tpos]:is_empty() then
			ws.move_stack("current_player", "main", tpos, "current_player", "main", empty)
		end
	end
	ws.move_stack("current_player", "main", it, "current_player", "main", tpos)
	return tpos
end

function ws.switch_to_item(itname, hslot)
	if not core.localplayer then return false end
	local plinv = core.get_inventory("current_player")
	for i, v in ipairs(plinv.main) do
		if i < 10 and v:get_name() == itname then
			core.localplayer:set_wield_index(i)
			return true
		end
	end
	local pos = ws.find_named(plinv.main, itname)
	if pos then
		local tpos = ws.to_hotbar(pos, hslot)
		if not tpos then
			return false
		end
		core.localplayer:set_wield_index(tpos)
		return true
	end
	return false
end


function core.switch_to_item(item)
	return ws.switch_to_item(item)
end

function ws.switch_inv_or_echest(name, max_count, hslot)
	if not core.localplayer then return false end
	local plinv = core.get_inventory("current_player")
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
		ws.move_stack("current_player", "enderchest", epos, "current_player", "main", tpos, max_count)
			core.localplayer:set_wield_index(tpos)
			return true
		end
	end
	return false
end



--- Move items between inventories. Wraps InventoryAction("move") boilerplate.
-- If count is nil, moves the entire stack.
function ws.move_stack(from_loc, from_list, from_idx, to_loc, to_list, to_idx, count)
	local act = InventoryAction("move")
	act:from(from_loc, from_list, from_idx)
	act:to(to_loc, to_list, to_idx)
	if count then act:set_count(count) end
	act:apply()
end

--- Read a cheat setting number with fallback.
-- self.setting .. "." .. key -> tonumber result or default

--- Register a key-hold cheat: holds a key while the setting is true.
function ws.register_keypress_cheat(setting, desc, category, keyname, condition, description)
	local was_active = false
	core.register_globalstep(function()
		if not core.localplayer then return end
		local is_active = core.settings:get_bool(setting) and (not condition or condition())
		if is_active then
			core.set_keypress(keyname, true)
		elseif was_active then
			core.set_keypress(keyname, false)
		end
		was_active = is_active
	end)
	core.register_cheat(desc, { category = category, setting = setting, description = description })
end

function ws.make_blocks()
	local it = core.get_wielded_item()
	local wi = core.get_wield_index()
	local nn = it:get_count() / 9
	for i = 1, 9 do
		ws.move_stack("current_player", "main", wi, "current_player", "craft", i, nn)
	end
	local craft_act = InventoryAction("craft")
	craft_act:craft("current_player")
	craft_act:apply()
	local tslot = ws.find_empty(core.get_inventory("current_player").main)
	if not tslot then tslot = 9 end
	ws.move_stack("current_player", "craft_result", 1, "current_player", "main", tslot)
end

core.register_cheat("MakeBlocks", { category = "Inventory", func = ws.make_blocks, description = "Create a block of the selected node type" })

--- Total count of an item across player main inventory and ender chest.
function ws.count_item(name)
	local total = 0
	local inv = core.get_inventory("current_player")
	if not inv then return 0 end
	for _, listname in ipairs({"main", "enderchest"}) do
		local stacks = inv[listname]
		if stacks then
			for _, stack in ipairs(stacks) do
				if not stack:is_empty() and stack:get_name() == name then
					total = total + stack:get_count()
				end
			end
		end
	end
	return total
end

--- Find a light-emitting placeable node in the player inventory.
-- Prefers known-good light blocks, then falls back to any node item whose
-- definition has light_source >= min_light. Returns the item name or nil.
local light_block_prefs = {
	"mcl_nether:glowstone",
	"mcl_ocean:sea_lantern",
	"mcl_crimson:shroomlight",
}

function ws.find_light_block(min_light)
	min_light = min_light or 10
	local inv = core.get_inventory("current_player")
	if not inv then return nil end
	local candidates = {}
	for _, stack in ipairs(inv.main) do
		if not stack:is_empty() then
			local name = stack:get_name()
			local def = core.get_item_def(name)
			if def and def.type == "node" and not candidates[name] then
				local ndef = core.get_node_def(name)
				local ls = ndef and ndef.light_source or 0
				if ls >= min_light then
					candidates[name] = ls
				end
			end
		end
	end
	for _, pref in ipairs(light_block_prefs) do
		if candidates[pref] then return pref end
	end
	local best, best_ls
	for name, ls in pairs(candidates) do
		if not best_ls or ls > best_ls then
			best, best_ls = name, ls
		end
	end
	return best
end

--- Loot matching items from nearby containers into player inventory.
function ws.loot_list(items, range, max_per_scan)
	if not core.localplayer then return 0 end
	range = range or 5
	max_per_scan = max_per_scan or 16
	if #items == 0 then return 0 end

	local needed = {}
	for _, name in ipairs(items) do
		needed[name] = true
	end

	local pos = core.localplayer:get_pos()
	local minp = vector.offset(pos, -range, -range, -range)
	local maxp = vector.offset(pos, range, range, range)
	local containers = core.find_nodes_with_meta(minp, maxp)
	if #containers == 0 then return 0 end

	local plinv = core.get_inventory("current_player")
	if not plinv then return 0 end
	local main_size = #plinv.main

	local moved = 0
	for _, cpos in ipairs(containers) do
		if moved >= max_per_scan then break end
		local loc = "nodemeta:" .. cpos.x .. "," .. cpos.y .. "," .. cpos.z
		local inv = core.get_inventory(loc)
		if inv then
			for listname, stacks in pairs(inv) do
				if moved >= max_per_scan then break end
				for idx, stack in ipairs(stacks) do
					if moved >= max_per_scan then break end
					if not stack:is_empty() then
						local name = stack:get_name()
						if needed[name] then
							for slot = 1, main_size do
								local plstack = plinv.main[slot]
								if plstack:is_empty() then
									ws.move_stack(loc, listname, idx,
										"current_player", "main", slot)
									moved = moved + 1
									break
								end
							end
						end
					end
				end
			end
		end
	end
	return moved
end


