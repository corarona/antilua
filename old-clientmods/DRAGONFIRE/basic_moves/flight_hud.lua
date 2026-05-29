local bar_fill = "\u{2588}"
local bar_half = "\u{258C}"
local bar_empty = "\u{2591}"

local function make_bar(value, max_val, width)
	value = math.max(0, math.min(value, max_val))
	local filled = math.floor(value / max_val * width)
	local partial = (value / max_val * width) - filled
	local s = ""
	for i = 1, filled do s = s .. bar_fill end
	if partial > 0.3 then s = s .. bar_half end
	for i = #s + 1, width do s = s .. bar_empty end
	return s
end

local block = "\u{2588}"

ws.rg("FlightHUD", { category = "Render", setting = "flight_hud",
	on_start = function(self)
		if not minetest.localplayer then return true end
		self._hud_pitch = minetest.localplayer:hud_add({
			hud_elem_type = "text",
			position = {x = 1, y = 1},
			alignment = {x = 1, y = -1},
			offset = {x = -5, y = -100},
			number = 0xFFFFFFFF,
			text = ""
		})
		self._hud_pitch_bar = minetest.localplayer:hud_add({
			hud_elem_type = "text",
			position = {x = 1, y = 1},
			alignment = {x = 1, y = -1},
			offset = {x = -5, y = -86},
			number = 0xFFAAAAAA,
			text = ""
		})
		self._hud_alt = minetest.localplayer:hud_add({
			hud_elem_type = "text",
			position = {x = 1, y = 1},
			alignment = {x = 1, y = -1},
			offset = {x = -5, y = -70},
			number = 0xFF88FF88,
			text = ""
		})
		self._hud_alt_bar = minetest.localplayer:hud_add({
			hud_elem_type = "text",
			position = {x = 1, y = 1},
			alignment = {x = 1, y = -1},
			offset = {x = -5, y = -58},
			number = 0xFF88FF88,
			text = ""
		})
		self._hud_speed = minetest.localplayer:hud_add({
			hud_elem_type = "text",
			position = {x = 1, y = 1},
			alignment = {x = 1, y = -1},
			offset = {x = -5, y = -44},
			number = 0xFFFFFFAA,
			text = ""
		})
		self._hud_speed_bar = minetest.localplayer:hud_add({
			hud_elem_type = "text",
			position = {x = 1, y = 1},
			alignment = {x = 1, y = -1},
			offset = {x = -5, y = -32},
			number = 0xFFAAAAAA,
			text = ""
		})
	end,
	on_step = function(self, dtime)
		local lp = minetest.localplayer
		if not lp then return end

		local pitch = -lp:get_pitch()
		local ptxt = string.format("Pitch: %.0f", pitch)
		lp:hud_change(self._hud_pitch, "text", ptxt)
		lp:hud_change(self._hud_pitch, "number", 0xFF66AAFF)

		local bar_w = 20
		local center = 10
		local p_idx = center + math.floor(-pitch / 4)
		p_idx = math.max(1, math.min(p_idx, bar_w))
		local pbar = ""
		for i = 1, bar_w do
			if i == p_idx then
				pbar = pbar .. block
			elseif i == center then
				pbar = pbar .. "\u{2592}"
			else
				pbar = pbar .. bar_empty
			end
		end
		lp:hud_change(self._hud_pitch_bar, "text", pbar)
		lp:hud_change(self._hud_pitch_bar, "number", 0xFFAAAAAA)

		local pos = lp:get_pos()
		local alt_txt = string.format("Y: %.0f", pos.y)
		local alt_color = 0xFF88FF88
		if pos.y < -30000 then alt_color = 0xFFFF6666 end
		if pos.y > 30000 then alt_color = 0xFFFFFF66 end
		lp:hud_change(self._hud_alt, "text", alt_txt)
		lp:hud_change(self._hud_alt, "number", alt_color)

		local y_norm = (pos.y + 32000) / 64000
		y_norm = math.max(0, math.min(1, y_norm))
		lp:hud_change(self._hud_alt_bar, "text", make_bar(y_norm * 20, 20, 20))

		local vel = lp:get_velocity()
		local speed = vel and vector.length(vel) / 10 or 0
		local spd_txt = string.format("%.1f n/s", speed)
		lp:hud_change(self._hud_speed, "text", spd_txt)
		lp:hud_change(self._hud_speed, "number", 0xFFFFCC66)

		local spd_norm = math.min(speed / 5, 1)
		lp:hud_change(self._hud_speed_bar, "text", make_bar(spd_norm * 20, 20, 20))
		local spd_color = speed > 3 and 0xFFFF6666 or 0xFFAAAAAA
		lp:hud_change(self._hud_speed_bar, "number", spd_color)
	end,
	on_stop = function(self)
		if not minetest.localplayer then return end
		for _, id in ipairs{
			self._hud_pitch, self._hud_pitch_bar,
			self._hud_alt, self._hud_alt_bar,
			self._hud_speed, self._hud_speed_bar
		} do
			if id then minetest.localplayer:hud_remove(id) end
		end
		self._hud_pitch = nil
		self._hud_alt = nil
		self._hud_speed = nil
		self._hud_pitch_bar = nil
		self._hud_alt_bar = nil
		self._hud_speed_bar = nil
	end,
})
