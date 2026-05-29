local function make_bar(value, max_val, width)
	value = math.max(0, math.min(value, max_val))
	local filled = math.floor(value / max_val * width)
	local s = {}
	for i = 1, width do
		s[i] = (i <= filled) and "#" or "-"
	end
	return table.concat(s)
end

local function set(id, stat, data)
	if id and minetest.localplayer then
		minetest.localplayer:hud_change(id, stat, data)
	end
end

-- Scale factor for all HUD image elements
local S = 2.5

ws.rg("FlightHUD", { category = "Render", setting = "flight_hud",
	on_start = function(self)
		if not minetest.localplayer then return true end

		-- Horizon background (128x128 image, fixed position)
		self._hud_bg = minetest.localplayer:hud_add({
			hud_elem_type = "image", position = {x = 1, y = 1},
			alignment = {x = 1, y = -1}, offset = {x = -170, y = -190},
			scale = {x = S, y = S}, text = "horizon.png"
		})

		-- Pitch indicator (small chevron that moves up/down)
		self._hud_indicator = minetest.localplayer:hud_add({
			hud_elem_type = "image", position = {x = 1, y = 1},
			alignment = {x = 1, y = 0}, offset = {x = -105, y = -95},
			scale = {x = S, y = S}, text = "horizon_indicator.png"
		})

		-- Pitch / Roll text
		self._hud_pitch = minetest.localplayer:hud_add({
			hud_elem_type = "text", position = {x = 1, y = 1},
			alignment = {x = 1, y = -1}, offset = {x = -120, y = -240},
			number = 0xFF66AAFF, text = ""
		})

		-- Altitude
		self._hud_alt = minetest.localplayer:hud_add({
			hud_elem_type = "text", position = {x = 1, y = 1},
			alignment = {x = 1, y = -1}, offset = {x = -120, y = -140},
			number = 0xFF88FF88, text = ""
		})
		self._hud_alt_bar = minetest.localplayer:hud_add({
			hud_elem_type = "text", position = {x = 1, y = 1},
			alignment = {x = 1, y = -1}, offset = {x = -120, y = -128},
			number = 0xFF88FF88, text = ""
		})

		-- Speed
		self._hud_speed = minetest.localplayer:hud_add({
			hud_elem_type = "text", position = {x = 1, y = 1},
			alignment = {x = 1, y = -1}, offset = {x = -120, y = -110},
			number = 0xFFFFCC66, text = ""
		})
		self._hud_speed_bar = minetest.localplayer:hud_add({
			hud_elem_type = "text", position = {x = 1, y = 1},
			alignment = {x = 1, y = -1}, offset = {x = -120, y = -98},
			number = 0xFFAAAAAA, text = ""
		})
	end,
	on_step = function(self, dtime)
		local lp = minetest.localplayer
		if not lp then return end

		local pitch = -lp:get_pitch()
		local roll = tonumber(minetest.settings:get("flight_hud_roll")) or 0

		-- Move indicator: pitch down (positive) → indicator moves UP
		-- 1 pixel of indicator movement per degree of pitch
		-- Base Y at circle center = -95
		local indicator_y = -95 - math.floor(pitch * 1.5)
		indicator_y = math.max(-180, math.min(0, indicator_y))
		set(self._hud_indicator, "offset", {x = -105, y = indicator_y})

		set(self._hud_pitch, "text", string.format("Pitch: %.0f  Roll: %.0f", pitch, roll))

		local pos = lp:get_pos()
		local alt_color = 0xFF88FF88
		if pos.y < -30000 then alt_color = 0xFFFF6666 end
		if pos.y > 30000 then alt_color = 0xFFFFFF66 end
		set(self._hud_alt, "number", alt_color)
		set(self._hud_alt, "text", string.format("Y: %.0f", pos.y))

		local y_norm = (pos.y + 32000) / 64000
		y_norm = math.max(0, math.min(1, y_norm))
		set(self._hud_alt_bar, "text", make_bar(y_norm * 12, 12, 12))

		local vel = lp:get_velocity()
		local speed = vel and vector.length(vel) / 10 or 0
		set(self._hud_speed, "text", string.format("%.1f n/s", speed))
		set(self._hud_speed_bar, "text", make_bar(math.min(speed / 5, 1) * 12, 12, 12))
		set(self._hud_speed_bar, "number", speed > 3 and 0xFFFF6666 or 0xFFAAAAAA)
	end,
	on_stop = function(self)
		if not minetest.localplayer then return end
		for _, id in ipairs{
			self._hud_bg, self._hud_indicator, self._hud_pitch,
			self._hud_alt, self._hud_alt_bar,
			self._hud_speed, self._hud_speed_bar,
		} do
			if id then minetest.localplayer:hud_remove(id) end
		end
	end,
})
