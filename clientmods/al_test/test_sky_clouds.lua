-- Tests for Sky and Clouds API
-- All deferred until core.sky and core.clouds are available

function test_sky_api(T)
	T.defer("core.sky exists", function()
		T.assert(core.sky ~= nil, "core.sky should exist")
	end)

	T.defer("core.sky:set_sun_visible toggle", function()
		core.sky:set_sun_visible(false)
		core.sky:set_sun_visible(true)
	end)

	T.defer("core.sky:set_moon_visible toggle", function()
		core.sky:set_moon_visible(false)
		core.sky:set_moon_visible(true)
	end)

	T.defer("core.sky:set_stars_visible toggle", function()
		core.sky:set_stars_visible(false)
		core.sky:set_stars_visible(true)
	end)

	T.defer("core.sky:set_star_count", function()
		core.sky:set_star_count(500)
		core.sky:set_star_count(1000)
	end)

	T.defer("core.sky:set_star_color", function()
		core.sky:set_star_color("#FFFFFF")
	end)

	T.defer("core.sky:set_star_scale", function()
		core.sky:set_star_scale(1.0)
	end)

	T.defer("core.sky:set_sun_scale", function()
		core.sky:set_sun_scale(1.0)
	end)

	T.defer("core.sky:set_moon_scale", function()
		core.sky:set_moon_scale(1.0)
	end)

	T.defer("core.sky:set_body_orbit_tilt", function()
		core.sky:set_body_orbit_tilt(0)
		core.sky:set_body_orbit_tilt(23.5)
	end)

	T.defer("core.sky:set_clouds_enabled toggle", function()
		core.sky:set_clouds_enabled(true)
	end)

	T.defer("core.sky:set_fog_distance", function()
		core.sky:set_fog_distance(100)
	end)

	T.defer("core.sky:set_fog_start", function()
		core.sky:set_fog_start(0.5)
	end)

	T.defer("core.sky:set_fog_color", function()
		core.sky:set_fog_color("#FFFFFF")
	end)

	T.defer("core.sky:get_brightness returns number", function()
		local b = core.sky:get_brightness()
		T.assert(type(b) == "number", "brightness should be a number")
	end)

	T.defer("core.sky:get_sun_direction returns vector", function()
		local d = core.sky:get_sun_direction()
		T.assert(type(d) == "table", "direction should be a table")
		T.assert(type(d.x) == "number", "x should be a number")
	end)

	T.defer("core.sky:get_moon_direction returns vector", function()
		local d = core.sky:get_moon_direction()
		T.assert(type(d) == "table", "direction should be a table")
		T.assert(type(d.x) == "number", "x should be a number")
	end)

	T.defer("core.sky:get_cloud_color returns table", function()
		local c = core.sky:get_cloud_color()
		T.assert(type(c) == "table", "cloud color should be a table")
	end)
end

function test_clouds_api(T)
	T.defer("core.clouds exists", function()
		T.assert(core.clouds ~= nil, "core.clouds should exist")
	end)

	T.defer("core.clouds:set_density", function()
		core.clouds:set_density(0.5)
		core.clouds:set_density(0.4)
	end)

	T.defer("core.clouds:set_height", function()
		core.clouds:set_height(120)
	end)

	T.defer("core.clouds:set_thickness", function()
		core.clouds:set_thickness(16)
	end)

	T.defer("core.clouds:set_speed", function()
		core.clouds:set_speed({ x = 0, y = -2 })
	end)

	T.defer("core.clouds:set_color_bright", function()
		core.clouds:set_color_bright("#FFFFFF")
	end)

	T.defer("core.clouds:set_color_ambient", function()
		core.clouds:set_color_ambient("#000000")
	end)

	T.defer("core.clouds:set_color_shadow", function()
		core.clouds:set_color_shadow("#CCCCCC")
	end)

	T.defer("core.clouds:get_color returns table", function()
		local c = core.clouds:get_color()
		T.assert(type(c) == "table", "color should be a table")
		T.assert(type(c.r) == "number", "r should be a number")
	end)

	T.defer("core.clouds:is_camera_inside returns boolean", function()
		local inside = core.clouds:is_camera_inside()
		T.assert(type(inside) == "boolean", "should return boolean")
	end)
end
