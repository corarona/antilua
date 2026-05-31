ws.rg("FindVoidAir","DevTools","fvair",function()
	local pos = minetest.localplayer:get_pos()
	local p1 = vector.offset(pos, -30, 0, -30)
	local p2 = vector.offset(pos, 30, 0, 30)
	p1.y = -180
	p2.y = -128
	local nds = minetest.find_nodes_in_area(p1, p2, {"air"})
	if nds and #nds > 0 then
		ws.dcm("Airpocket found at "..minetest.pos_to_string(nds[1]))
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

local startpos = vector.zero()
local function do_tp_up()
	local pos = minetest.localplayer:get_pos()
	if vector.distance(pos,startpos) > 256 then
		minetest.localplayer:set_pos(startpos)
	else
		minetest.localplayer:set_pos(vector.offset(pos,0,20,0))
		minetest.after(1.4,do_tp_up)
	end
end



local cpos = vector.new(-2099,11,2098)
local basew = 128

local material = "mcl_core:redsandstonesmooth2"

local function is_part(pos)
	--local wh = math.floor(basew - (basew - (pos.y - cpos.y)) / 2)
	local lvl = cpos.y - pos.y + 1
	local wh = basew / 2 + lvl
	if pos.x >= cpos.x - wh and pos.x <= cpos.x  + wh and pos.z >= cpos.x - wh and pos.z <= cpos.z + wh and pos.y >= cpos.y and pos.y <= cpos.y + basew then
		return true
	end
end

ws.rg("Pyramid", "Scaffold", "pyramid", function()
	for _, pos in pairs(ws.get_reachable_positions()) do
		if is_part(pos) then
			ws.place(pos, material)
		end
	end
end)

ws.rg("NoWaterStop", "Bots", "nowaterstop", function()
	if minetest.settings:get_bool("continuous_forward") then
		if not minetest.find_node_near(minetest.localplayer:get_pos(), 50, "mcl_core:water_source") then
			minetest.settings:get_bool("continuous_forward", false)
			minetest.settings:get_bool("nowaterstop", false)
		end
	end
end)

sbots.register_bot("mtgwaterblocker",{
	find_pos = function(self,pos)
		local nds = minetest.find_nodes_near(pos,60,{"default:water_source"})
		if not nds or #nds == 0 then return end
		table.sort(nds,function(a, b) return vector.distance(pos,a) < vector.distance(pos,b) end)
		return nds[1]
	end,
	do_pos = function(self,pos)
		local nn=minetest.find_nodes_near(pos,1,{"default:water_source"},true)
		if not nn or #nn == 0 then return true end
		for _,v in pairs(nn) do ws.place(v, "default:leaves") end
	end,
})
--[[
ws.rg("EntInvDupe", "Exploits", "einvdupe", function()
	for _, v in pairs(minetest.get_objects_inside_radius(minetest.localplayer:get_pos(), 4) do
		if v.get_properties().textures:find("chest_boat") then
			v:rightclick()

		end
	end
end)
--]]

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
						local move_act = InventoryAction("move")
						move_act:from("detached:"..formname, "main", sidx)
						move_act:to("current_player", "main", empty)
						move_act:set_count(space)
						move_act:apply()
					end
				end
			end
			return true
		end
	end)

end


