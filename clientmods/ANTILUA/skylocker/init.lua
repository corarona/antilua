-- SkyLocker: lock sky/cloud parameters when server changes them

core.register_on_sky_changed(function()
	if not core.settings:get_bool("skylocker") then
		return
	end
	if core.settings:get_bool("skylocker.lock_sun") then
		core.sky:set_sun_visible(core.settings:get_bool("skylocker.sun_visible", true))
		core.sky:set_sun_scale(tonumber(core.settings:get("skylocker.sun_scale")) or 1.0)
	end
	if core.settings:get_bool("skylocker.lock_moon") then
		core.sky:set_moon_visible(core.settings:get_bool("skylocker.moon_visible", true))
		core.sky:set_moon_scale(tonumber(core.settings:get("skylocker.moon_scale")) or 1.0)
	end
	if core.settings:get_bool("skylocker.lock_stars") then
		core.sky:set_stars_visible(core.settings:get_bool("skylocker.stars_visible", true))
		core.sky:set_star_count(tonumber(core.settings:get("skylocker.star_count")) or 1000)
		core.sky:set_star_scale(tonumber(core.settings:get("skylocker.star_scale")) or 1.0)
	end
	if core.settings:get_bool("skylocker.lock_fog") then
		core.sky:set_fog_distance(tonumber(core.settings:get("skylocker.fog_distance")) or 100)
		core.sky:set_fog_color(core.settings:get("skylocker.fog_color") or "#808080")
	end
end)

core.register_on_clouds_changed(function()
	if not core.settings:get_bool("skylocker") then
		return
	end
	if core.settings:get_bool("skylocker.lock_clouds") then
		core.clouds:set_density(tonumber(core.settings:get("skylocker.cloud_density")) or 0.4)
		core.clouds:set_height(tonumber(core.settings:get("skylocker.cloud_height")) or 120)
		core.clouds:set_thickness(tonumber(core.settings:get("skylocker.cloud_thickness")) or 16)
	end
end)

core.register_cheat({ name = "SkyLocker", category = "Render",
	setting = "skylocker",
	description = "Lock sky and cloud parameters when server changes them",
	cheat_settings = {
		lock_sun = { type = "bool", default = false },
		lock_moon = { type = "bool", default = false },
		lock_stars = { type = "bool", default = false },
		lock_fog = { type = "bool", default = false },
		lock_clouds = { type = "bool", default = false },
		sun_visible = { type = "bool", default = true },
		sun_scale = { type = "number", default = 1.0, min = 0.1, max = 5 },
		moon_visible = { type = "bool", default = true },
		moon_scale = { type = "number", default = 1.0, min = 0.1, max = 5 },
		stars_visible = { type = "bool", default = true },
		star_count = { type = "number", default = 1000, min = 0, max = 5000 },
		star_scale = { type = "number", default = 1.0, min = 0.1, max = 5 },
		fog_distance = { type = "number", default = 100, min = 0, max = 500 },
		fog_color = { type = "string", default = "#808080" },
		cloud_density = { type = "number", default = 0.4, min = 0, max = 1 },
		cloud_height = { type = "number", default = 120, min = 0, max = 500 },
		cloud_thickness = { type = "number", default = 16, min = 0, max = 100 },
	},
})
