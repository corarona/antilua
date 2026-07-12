local S = {
	IDLE = 0,
	COLLECT = 1,
	PICKUP_WAIT = 2,
	PLACE_CHEST = 3,
	DEPOSIT = 4,
}

local state = S.IDLE
local target_obj = nil
local pickup_timer = 0
local chest_pos = nil
local pending_transfers = nil

local function count_free_slots(inv)
	local n = 0
	for _, stack in ipairs(inv.main) do
		if stack:is_empty() then n = n + 1 end
	end
	return n
end

local function find_nearest_item(pos, range)
	local closest, closest_d = nil, math.huge
	for _, obj in pairs(core.get_objects_inside_radius(pos, range)) do
		if obj:get_name() == "__builtin:item" then
			local d = vector.distance(pos, obj:get_pos())
			if d < closest_d then closest, closest_d = obj, d end
		end
	end
	return closest
end

ws.rg("ItemCollector", {
	category = "Bots",
	setting = "item_collector",
	description = "Collect dropped items and deposit into chests",
	on_step = function(self, dtime)
		local lp = core.localplayer:get_pos()
		if not lp then return end
		local collect_range = tonumber(core.settings:get("item_collector.collect_range")) or 6
		local inv = core.get_inventory("current_player")
		if not inv then return end

		local free_slots = count_free_slots(inv)

		if state == S.IDLE then
			local item = find_nearest_item(lp, collect_range)
			if item then
				target_obj = item
				state = S.COLLECT
			elseif free_slots < 2 then
				state = S.PLACE_CHEST
			end
		end

		if state == S.COLLECT then
			if not target_obj or not target_obj:get_pos() then
				state = S.IDLE
				core.settings:set_bool("continuous_forward", false)
				return
			end
			local ipos = target_obj:get_pos()
			local d = vector.distance(lp, ipos)
			if d < 1.5 then
				core.settings:set_bool("continuous_forward", false)
				state = S.PICKUP_WAIT
				pickup_timer = 0
			else
				ws.aim(ipos)
				core.settings:set_bool("continuous_forward", true)
			end
		end

		if state == S.PICKUP_WAIT then
			if not target_obj or not target_obj:get_pos() then
				state = S.IDLE
				return
			end
			-- If inventory is now fuller, item was picked up
			if count_free_slots(inv) < free_slots then
				free_slots = count_free_slots(inv)
				if free_slots < 2 then
					state = S.PLACE_CHEST
				else
					state = S.IDLE
				end
				return
			end
			pickup_timer = pickup_timer + dtime
			if pickup_timer > 5 then
				-- Stuck, try punching the item to force pickup
				target_obj:punch()
				if target_obj:get_pos() then
					state = S.IDLE
				else
					state = S.IDLE
				end
			end
		end

		if state == S.PLACE_CHEST then
			core.settings:set_bool("continuous_forward", false)
			local chest_item = "mcl_chests:chest"
			if not ws.switch_to_item(chest_item) then
				return
			end

			-- Find an air node above a solid node nearby, or any air node
			local found = nil
			local rlp = vector.round(lp)
			for dy = 0, -3, -1 do
			for dx = -2, 2 do
			for dz = -2, 2 do
				local p = vector.add(rlp, {x = dx, y = dy, z = dz})
				local node = core.get_node_or_nil(p)
				if node and core.get_item_def(node.name) and
						core.get_item_def(node.name).walkable then
					local above = vector.offset(p, 0, 1, 0)
					local an = core.get_node_or_nil(above)
					if an and an.name == "air" then
						found = above
						break
					end
				end
			end
			if found then break end
			end
			if found then break end
			end

			if not found then
				-- Fallback: any air node nearby
				for dx = -2, 2 do
				for dz = -2, 2 do
				for dy = 0, -2, -1 do
					local p = vector.add(rlp, {x = dx, y = dy, z = dz})
					local node = core.get_node_or_nil(p)
					if node and node.name == "air" then
						found = p
						break
					end
				end
				if found then break end
				end
				if found then break end
				end
			end

			if not found then
				ws.place(vector.round(lp), chest_item)
				chest_pos = vector.round(lp)
			else
				ws.place(found, chest_item)
				chest_pos = found
			end
			state = S.DEPOSIT
			pending_transfers = nil
		end

		if state == S.DEPOSIT then
			if not chest_pos then return end
			local cloc = "nodemeta:" .. chest_pos.x .. "," .. chest_pos.y .. "," .. chest_pos.z
			local cinv = core.get_inventory(cloc)
			if not cinv then return end

			if not pending_transfers then
				pending_transfers = {}
				for i, stack in ipairs(inv.main) do
					if not stack:is_empty() then
						table.insert(pending_transfers, i)
					end
				end
			end

			if #pending_transfers == 0 then
				state = S.IDLE
				return
			end

			local slot = table.remove(pending_transfers)
			ws.move_stack("current_player", "main", slot, cloc, "main", slot)
		end
	end,
	cheat_settings = {
		collect_range = { type = "number", default = 6, min = 2, max = 20 },
	},
})
