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

ws.rg("FlightHUD", { category = "Render", setting = "flight_hud",
	on_start = function(self)
		if not minetest.localplayer then return true end
		self._hud_pitch = minetest.localplayer:hud_add({
			hud_elem_type = "text", position = {x = 1, y = 1},
			alignment = {x = 1, y = -1}, offset = {x = -120, y = -100},
			number = 0xFFFFFFFF, text = ""
		})
		self._hud_pitch_bar = minetest.localplayer:hud_add({
			hud_elem_type = "text", position = {x = 1, y = 1},
			alignment = {x = 1, y = -1}, offset = {x = -120, y = -86},
			number = 0xFFAAAAAA, text = ""
		})
		self._hud_alt = minetest.localplayer:hud_add({
			hud_elem_type = "text", position = {x = 1, y = 1},
			alignment = {x = 1, y = -1}, offset = {x = -120, y = -70},
			number = 0xFF88FF88, text = ""
		})
		self._hud_alt_bar = minetest.localplayer:hud_add({
			hud_elem_type = "text", position = {x = 1, y = 1},
			alignment = {x = 1, y = -1}, offset = {x = -120, y = -58},
			number = 0xFF88FF88, text = ""
		})
		self._hud_speed = minetest.localplayer:hud_add({
			hud_elem_type = "text", position = {x = 1, y = 1},
			alignment = {x = 1, y = -1}, offset = {x = -120, y = -44},
			number = 0xFFFFCC66, text = ""
		})
		self._hud_speed_bar = minetest.localplayer:hud_add({
			hud_elem_type = "text", position = {x = 1, y = 1},
			alignment = {x = 1, y = -1}, offset = {x = -120, y = -32},
			number = 0xFFAAAAAA, text = ""
		})
	end,
	on_step = function(self, dtime)
		local lp = minetest.localplayer
		if not lp then return end

		local pitch = -lp:get_pitch()
		set(self._hud_pitch, "number", 0xFF66AAFF)
		set(self._hud_pitch, "text", string.format("Pitch: %.0f", pitch))

		local bar_w = 12
		local center = 6
		local p_idx = center + math.floor(-pitch / 5)
		p_idx = math.max(1, math.min(p_idx, bar_w))
		local pbar = {}
		for i = 1, bar_w do
			pbar[i] = (i == p_idx) and "|" or (i == center and "+" or "-")
		end
		set(self._hud_pitch_bar, "text", "[" .. table.concat(pbar) .. "]")

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

		local spd_norm = math.min(speed / 5, 1)
		set(self._hud_speed_bar, "text", make_bar(spd_norm * 12, 12, 12))
		local spd_color = speed > 3 and 0xFFFF6666 or 0xFFAAAAAA
		set(self._hud_speed_bar, "number", spd_color)
	end,
	on_stop = function(self)
		if not minetest.localplayer then return end
		for _, id in ipairs{
			self._hud_pitch, self._hud_pitch_bar,
			self._hud_alt, self._hud_alt_bar,
			self._hud_speed, self._hud_speed_bar,
		} do
			if id then minetest.localplayer:hud_remove(id) end
		end
	end,
})
