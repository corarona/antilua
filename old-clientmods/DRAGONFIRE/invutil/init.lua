local etime = 0

minetest.register_globalstep(function(dtime)
	local player = minetest.localplayer
	if not player then return end
	local item = player:get_wielded_item()
	local itemname = item:get_name()
	local itemdef = minetest.get_item_def(itemname)
	local wieldindex = player:get_wield_index()
	etime = etime + dtime
	if minetest.settings:get_bool("autorefill") and itemname ~= "" and itemdef and etime > 0.1 then
		etime = 0
		local space = item:get_free_space()
		local i = minetest.find_item(item:get_name(), wieldindex + 1)
		if i and space > 0 then
			local invact = InventoryAction("move")
			invact:to("current_player", "main", wieldindex)
			invact:from("current_player", "main", i)
			invact:set_count(space)
			invact:apply()
		end
	end
	if minetest.settings:get_bool("autoeject") then
		local invact = InventoryAction("drop")
		local list = (minetest.settings:get("eject_items") or ""):split(",")
		local inventory = minetest.get_inventory("current_player")
		for index, stack in pairs(inventory.main) do
			if table.indexof(list, stack:get_name()) ~= -1 then
				invact:from("current_player", "main", index)
				invact:apply()
			end
		end
	end
end)

minetest.register_list_command("eject", "Configure AutoEject", "eject_items")

core.register_cheat("AutoRefill", { category = "Inventory", setting = "autorefill" })
core.register_cheat("AutoEject", { category = "Inventory", setting = "autoeject" })

local blockable = {
	"default:diamond"
}

local blocks = {
	"default:diamondblock"
}

core.register_cheat("DumpFull", { category = "Inventory", func = function()
	local pt = core.get_pointed_thing().under
	local inv = core.get_inventory("nodemeta:"..pt.x..","..pt.y..","..pt.z)
	local plinv = core.get_inventory("current_player")
	for i, v in pairs(plinv.main) do
		local act = InventoryAction("move")
		act:from("current_player", "main", i)
		act:to("nodemeta:"..pt.x..","..pt.y..","..pt.z, "main", i)
		act:apply()
	end
end})

ws.rg("AutoBlock", "Inventory", "autoblock", function()
	local inv = core.get_inventory("current_player")
	local item
	local count = 0
	local items = {}

	for idx, it in pairs(inv.main) do
		for _, b in pairs(blockable) do
			if ((item and item == it:get_name()) or it:get_name() == b) and it:get_count() == it:get_stack_max() then
				items[idx] = it
				item = b
				count = count + 1
			end
		end
	end
	if item and count >= 9 then
		local cidx = 1
		for idx, it in pairs(items) do
			local mv =  InventoryAction("move")
			mv:from("current_player", "main", idx)
			mv:to("current_player", "craft", cidx)
			mv:set_count(it:get_count())
			mv:apply()
			cidx = cidx + 1
		end
	end

	local empty = ws.find_empty(inv.main)
			core.log(dump(inv.craftpreview[1]:get_name()))
			core.log(dump(inv.craft[1]:get_name()))
	if empty and inv.craftpreview[1]:get_name() == blocks[1]  then
		for _ = 1, inv.craft[1]:get_count() do
			local mv = InventoryAction("move")
			mv:from("current_player", "craftpreview", 1)
			mv:to("current_player", "main", empty)
			mv:apply()
		end
	end
end)
