autokey = {}

function autokey.register_keypress_cheat(setting, desc, category, keyname, condition)
	local was_active = false
	minetest.register_globalstep(function()
		if not core.localplayer then return end
		local is_active = minetest.settings:get_bool(setting) and (not condition or condition())
		if is_active then
			minetest.set_keypress(keyname, true)
		elseif was_active then
			minetest.set_keypress(keyname, false)
		end
		was_active = is_active
	end)
	core.register_cheat(desc, { category = category, setting = setting })
end

autokey.register_keypress_cheat("autosneak", "AutoSneak", "Movement", "sneak", function()
	return core.localplayer:is_touching_ground()
end)

autokey.register_keypress_cheat("autosprint", "AutoSprint", "Movement", "aux1")
