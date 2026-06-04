autokey = {}

function autokey.register_keypress_cheat(setting, desc, category, keyname, condition)
	ws.register_keypress_cheat(setting, desc, category, keyname, condition)
end

autokey.register_keypress_cheat("autosneak", "AutoSneak", "Movement", "sneak", function()
	return core.localplayer:is_touching_ground()
end)

autokey.register_keypress_cheat("autosprint", "AutoSprint", "Movement", "aux1")
