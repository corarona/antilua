ws.rg("FindVoidAir","DevTools","fvair",function()
	local pos = minetest.localplayer:get_pos()
	local p1 = vector.offset(pos, -30, 0, -30)
	local p2 = vector.offset(pos, 30, 0, 30)
	p1.y = -180
	p2.y = -128
	local nds = minetest.find_nodes_in_area(p1, p2, {"air"})
	if nds and #nds > 0 then
		ws.notify("Airpocket found at " .. minetest.pos_to_string(nds[1]), ws.NOTIFY_INFO, {toast=false})
		ws.display_wp(nds[1], "airpocket")
	end
end)

local function dump_to_chat(arg)
	minetest.display_chat_message(dump(arg))
	core.log(dump(arg))
end

local function dumpmetaat(pos)
	local meta = minetest.get_meta(pos)
	dump_to_chat(meta:to_table())
	core.log(dump(arg))
end

local function dumpdefat(pos)
	local node = minetest.get_node_or_nil(pos)
	if node then
		local def = minetest.get_node_def(node.name)
		dump_to_chat(def)
		core.log(dump(def))
	end
end

ws.on_connect(function()
	if minetest.localplayer:get_name() == "singleplayer" then
		minetest.send_chat_message("/time 6:00")
	end
end)

core.register_cheat("ItemMeta", { category = "DevTools", func = function()
	local it = minetest.localplayer:get_wielded_item()
	local meta = it:get_meta()
	dump_to_chat(it:get_name())
	dump_to_chat(meta:to_table())
end})

core.register_cheat("PointedMeta", { category = "DevTools", func = function() dumpmetaat(minetest.get_pointed_thing().under) end})
core.register_cheat("PosMeta", { category = "DevTools", func = function() dumpmetaat(minetest.localplayer:get_pos()) end})
core.register_cheat("PointedDef", { category = "DevTools", func = function() dumpdefat(minetest.get_pointed_thing().under) end})

if minetest.register_on_receive_particlespawner then
	minetest.register_on_receive_particlespawner(function(params)
		if not vector.equals(vector.round(params.minpos),vector.zero()) and vector.distance(ws.dircoord(0,0,0),params.minpos) > 256 then
			if minetest.global_exists("poi") and not poi.has_wp_near(params.minpos) then
				poi.set_waypoint(vector.round(params.minpos), "Leaked Particle coord from "..os.date("%Y-%m-%d %H:%M:%S").." ("..params.texture..")")
				ws.dcm("Received new far particle spawner at minpos: "..minetest.pos_to_string(vector.round(params.minpos)).." ("..params.texture..")")
			end
		end
	end)
end

minetest.register_on_play_sound(function(p)
	if p.pos then
		if not vector.equals(vector.round(p.pos),vector.zero()) and vector.distance(ws.dircoord(0,0,0),p.pos) > 256 then
			if minetest.global_exists("poi") and not poi.has_wp_near(p.pos) then
				poi.set_waypoint(vector.round(p.pos), "Leaked Particle coord from "..os.date("%Y-%m-%d %H:%M:%S").." ("..p.name..")")
				ws.dcm("Received new far sound at pos: "..minetest.pos_to_string(vector.round(p.pos)).." ("..p.name..")")
			end
		end
	end
end)

local function find_slot(invlist, istack)
	local slot, space
	for idx, stack in pairs(invlist) do
		if stack:is_empty() then
			slot, space = idx, istack:get_count()
		elseif stack:get_name() == istack:get_name() and stack:get_count() < stack:get_stack_max() then
			return idx, stack:get_stack_max() - stack:get_count()
		end
	end
	return slot, space
end
if minetest.register_on_receiving_inventory_form then
	minetest.register_on_receiving_inventory_form(function(formname, formspec)
		if minetest.settings:get_bool("einv_taker", false) and formname:find("entity_inv_") then
			local pinv = core.get_inventory("current_player")
			local einv = core.get_inventory("detached:"..formname)
			for sidx, stack in pairs(einv and einv.main or {}) do
				if not stack:is_empty() then
					local empty, space = find_slot(pinv.main, stack)
					if empty then
						ws.move_stack("detached:"..formname, "main", sidx, "current_player", "main", empty, space)
					end
				end
			end
			return true
		end
	end)

end


