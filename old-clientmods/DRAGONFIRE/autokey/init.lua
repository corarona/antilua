autokey = {}

function autokey.register_keypress_cheat(setting, desc, category, keyname, condition)
	local was_active = false
	minetest.register_globalstep(function()
		local is_active = minetest.settings:get_bool(setting) and (not condition or condition())
		if is_active then
			minetest.set_keypress(keyname, true)
		elseif was_active then
			minetest.set_keypress(keyname, false)
		end
		was_active = is_active
	end)
	minetest.register_cheat(desc, category, setting)
end

autokey.register_keypress_cheat("autosneak", "AutoSneak", "Movement", "sneak", function()
	return core.localplayer:is_touching_ground()
end)

autokey.register_keypress_cheat("autosprint", "AutoSprint", "Movement", "aux1")
