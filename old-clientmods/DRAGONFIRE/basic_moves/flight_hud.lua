local function set(id, stat, data)
	if id and minetest.localplayer then
		minetest.localplayer:hud_change(id, stat, data)
	end
end

-- Vertical bar using block characters: 16 steps
local bar_up   = "\u{2581}" -- ▁
local bar_down = "\u{2587}" -- ▇
local bar_full = "\u{2588}" -- █
local bar_mid  = "\u{2584}" -- ▄

local function alt_bar(value)
	-- value: 0 (bottom) to 1 (top)
	local h = 12
	local filled = math.floor(value * h)
	local s = {}
	for i = 1, h do
		if i > h - filled then
			s[i] = bar_full
		elseif i == h - filled and value * h - filled > 0.3 then
			s[i] = bar_mid
		else
			s[i] = " "
		end
	end
	return table.concat(s, "\n")
end

local function speed_bar(value)
	local w = 16
	local filled = math.floor(value * w)
	local s = {}
	for i = 1, w do
		s[i] = (i <= filled) and "#" or "."
	end
	return table.concat(s)
end

local S = 2.5

ws.rg("FlightHUD", { category = "Render", setting = "flight_hud",
	on_start = function(self)
		if not minetest.localplayer then return true end

		-- Horizon background
		self._hud_bg = minetest.localplayer:hud_add({
			hud_elem_type = "image", position = {x = 1, y = 1},
			alignment = {x = 1, y = 1},
			offset = {x = -262, y = -309},
			scale = {x = 2, y = 2},
			text = "df_horizon.png"
		})

		-- Indicator line centered on the horizon image
		self._hud_line = minetest.localplayer:hud_add({
			hud_elem_type = "image", position = {x = 1, y = 1},
			alignment = {x = 1, y = 1},
			offset = {x = -247, y = -294},
			scale = {x = S, y = S},
			text = "horizon_indicator.png"
		})
		self._last_roll_tex = nil

		-- Pitch/Roll numeric text (centered above horizon image)
		self._hud_pitch = minetest.localplayer:hud_add({
			hud_elem_type = "text", position = {x = 1, y = 1},
			alignment = {x = 0.5, y = 1},
			offset = {x = -174, y = -340},
			number = 0xFF66AAFF, text = ""
		})

		-- Altitude bar (left side)
		self._hud_alt_bar = minetest.localplayer:hud_add({
			hud_elem_type = "text", position = {x = 0, y = 1},
			alignment = {x = 0, y = 1},
			offset = {x = 25, y = -250},
			number = 0xFF88FF88, text = ""
		})
		-- Y: value right under the bar
		self._hud_alt = minetest.localplayer:hud_add({
			hud_elem_type = "text", position = {x = 0, y = 1},
			alignment = {x = 0, y = 1},
			offset = {x = 25, y = -25},
			number = 0xFF88FF88, text = ""
		})

		-- Speed bar (below altitude, same x)
		self._hud_speed = minetest.localplayer:hud_add({
			hud_elem_type = "text", position = {x = 1, y = 1},
			alignment = {x = 1, y = 1},
			offset = {x = -200, y = -50},
			number = 0xFFFFCC66, text = ""
		})
		self._hud_speed_bar = minetest.localplayer:hud_add({
			hud_elem_type = "text", position = {x = 1, y = 1},
			alignment = {x = 1, y = 1},
			offset = {x = -200, y = -38},
			number = 0xFFAAAAAA, text = ""
		})
	end,
	on_step = function(self, dtime)
		local lp = minetest.localplayer
		if not lp then return end

		local pitch = -lp:get_pitch()  -- negative = looking up
		local roll = tonumber(minetest.settings:get("flight_hud_roll")) or 0

		-- Indicator line: pitch down (positive) → moves UP
		-- Indicator: move up/down with pitch, centered on horizon
		local ind_y = -294 + math.floor(pitch * 1.5)
		ind_y = math.max(-399, math.min(-189, ind_y))
		set(self._hud_line, "offset", {x = -247, y = ind_y})

		-- Swap indicator texture based on roll (round to nearest 10°)
		local ri = math.floor((roll + 5) / 10) * 10
		ri = math.max(-90, math.min(90, ri))
		local tex
		if ri == 0 then
			tex = "horizon_indicator.png"
		else
			local sign = ri > 0 and "" or "-"
			tex = string.format("hl_%s%d.png", sign, math.abs(ri))
		end
		if tex ~= self._last_roll_tex then
			set(self._hud_line, "text", tex)
			self._last_roll_tex = tex
		end
		set(self._hud_pitch, "text", string.format("Pitch: %.0f  Roll: %.0f", pitch, roll))

		-- Altitude: Y position with vertical bar to the right
		local pos = lp:get_pos()
		local alt_color = 0xFF88FF88
		if pos.y < -30000 then alt_color = 0xFFFF6666 end
		if pos.y > 30000 then alt_color = 0xFFFFFF66 end
		set(self._hud_alt, "number", alt_color)
		set(self._hud_alt, "text", string.format("Y: %.0f", pos.y))

		local y_norm = (pos.y + 32000) / 64000
		y_norm = math.max(0, math.min(1, y_norm))
		set(self._hud_alt_bar, "text", alt_bar(y_norm))
		set(self._hud_alt_bar, "number", alt_color)

		-- Speed: numeric + horizontal bar below altitude
		local vel = lp:get_velocity()
		local speed = vel and vector.length(vel) or 0
		set(self._hud_speed, "text", string.format("%.1f n/s", speed))
		set(self._hud_speed_bar, "text", speed_bar(math.min(speed / 5, 1)))
		set(self._hud_speed_bar, "number", speed > 3 and 0xFFFF6666 or 0xFFAAAAAA)
	end,
	on_stop = function(self)
		if not minetest.localplayer then return end
		for _, id in ipairs{
			self._hud_bg, self._hud_line, self._hud_pitch,
			self._hud_alt, self._hud_alt_bar,
			self._hud_speed, self._hud_speed_bar,
		} do
			if id then minetest.localplayer:hud_remove(id) end
		end
	end,
})
