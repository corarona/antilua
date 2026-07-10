local function invrestore()
	if not core.localplayer then core.after(1, invrestore) return end
	local hp = core.localplayer:get_hp()
	if hp > 0 then
		ws.ectoinv()
	else
		core.after(1, invrestore)
	end
end

core.register_on_damage_taken(function()
	if not core.settings:get_bool("invsaver") then return end
	local hp = core.localplayer:get_hp()
	if hp < 6 then
		ws.notify("Almost dead - saving to ender chest", ws.NOTIFY_WARNING)
		ws.invtoec()
	end
end)

core.register_on_death(function()
	if not core.settings:get_bool("invsaver") then return end
	core.after(1, invrestore)
end)

if core.settings:get("invsaver") == nil then
	core.settings:set("invsaver", "false")
end
core.register_cheat("InvSaver", { category = "Player", setting = "invsaver",
	description = "Save inventory on disconnect" })
