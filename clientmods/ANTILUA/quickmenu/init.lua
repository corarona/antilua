function core.toggle_favorite(setting)
	local favs = core.get_favorites()
	local idx = {}
	for i, v in ipairs(favs) do idx[v] = true end
	if idx[setting] then
		local new_favs = {}
		for _, v in ipairs(favs) do
			if v ~= setting then table.insert(new_favs, v) end
		end
		core.settings:set("cheat_menu_favorites", table.concat(new_favs, ","))
	else
		table.insert(favs, setting)
		core.settings:set("cheat_menu_favorites", table.concat(favs, ","))
	end
end

function core.is_favorite(setting)
	local favs = core.get_favorites()
	for _, v in ipairs(favs) do
		if v == setting then return true end
	end
	return false
end

function core.get_favorites()
	local str = core.settings:get("cheat_menu_favorites") or ""
	if str == "" then return {} end
	local t = {}
	for v in str:gmatch("[^,]+") do
		table.insert(t, v)
	end
	return t
end

function core.clear_favorites()
	core.settings:set("cheat_menu_favorites", "")
end
