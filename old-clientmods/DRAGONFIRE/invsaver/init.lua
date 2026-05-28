local function invrestore()
	local hp = minetest.localplayer:get_hp()
	if hp > 0 then
		ws.ectoinv()
	else
		minetest.after(1, invrestore)
	end
end

minetest.register_on_damage_taken(function()
	if not minetest.settings:get_bool("invsaver") then return end
	local hp = minetest.localplayer:get_hp()
	if hp < 6 then
		ws.dcm("almost dead - saving shit to ec")
		ws.invtoec()
	end
end)

minetest.register_on_death(function()
	if not minetest.settings:get_bool("invsaver") then return end
	minetest.after(1, invrestore)
end)

if minetest.settings:get("invsaver") == nil then
	minetest.settings:set("invsaver", "false")
end
core.register_cheat("InvSaver", { category = "Player", setting = "invsaver" })
