local etime = 0

local function try_replenish()
	local inv = core.get_inventory("current_player")
	if not inv or not inv.offhand then return end

	local offhand = inv.offhand[1]
	if offhand and offhand:get_name() == "mcl_totems:totem" then
		return
	end

	local totem_slot = core.find_item("mcl_totems:totem")
	if not totem_slot then return end

	ws.move_stack("current_player", "main", totem_slot,
		"current_player", "offhand", 1)
end

core.register_on_hp_modification(function(newhp)
	if not core.settings:get_bool("autototem") then return end
	if newhp <= 0 then return end
	try_replenish()
end)

core.register_globalstep(function(dtime)
	if not core.localplayer then return end
	etime = etime + dtime
	if etime < 2.0 then return end
	etime = 0
	if not core.settings:get_bool("autototem") then return end
	if core.localplayer:get_hp() <= 0 then return end
	try_replenish()
end)

core.register_cheat("AutoTotem", {
	category = "Combat",
	setting = "autototem",
	description = "Auto-replenish totem in offhand slot after use"
})
