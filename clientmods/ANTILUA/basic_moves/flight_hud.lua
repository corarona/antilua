local function set(id, stat, data)
	if id and core.localplayer then
		core.localplayer:hud_change(id, stat, data)
	end
end

local function clamp(v, min, max)
	return math.max(min, math.min(max, v))
end

local bar_full = "\u{2588}"
local bar_mid  = "\u{2584}"

local function alt_bar(value)
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

local HORIZON_SCALE = 2.5
local compass_labels = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"}

local function compass_string(yaw)
	local idx = math.floor((yaw + 22.5) / 45) % 8
	local parts = {}
	for i = -2, 2 do
		local di = (idx + i + 8) % 8
		local label = compass_labels[di + 1]
		table.insert(parts, (i == 0) and ("[" .. label .. "]") or label)
	end
	return table.concat(parts, " │ ")
end

local hud_defs = {
	{key = "bg",      type = "image", pos = {x=1,y=1}, align = {x=1,y=1}, offset={x=-262,y=-309}, scale={x=2,y=2},               text="df_horizon.png"},
	{key = "line",    type = "image", pos = {x=1,y=1}, align = {x=1,y=1}, offset={x=-247,y=-294}, scale={x=HORIZON_SCALE,y=HORIZON_SCALE}, text="horizon_indicator.png"},
	{key = "compass", type = "text",  pos = {x=1,y=1}, align = {x=0.5,y=0.5}, offset={x=-177,y=-177}, color=0xFFFFF0,             text=""},
	{key = "pitch",   type = "text",  pos = {x=1,y=1}, align = {x=0.5,y=1},   offset={x=-174,y=-340}, color=0xFF66AAFF,             text=""},
	{key = "target",  type = "text",  pos = {x=1,y=1}, align = {x=0.5,y=1},   offset={x=-174,y=-400}, color=0xFF88FF88,             text=""},
	{key = "alt_bar", type = "text",  pos = {x=1,y=1}, align = {x=0.5,y=1},   offset={x=-15,y=-290},  color=0xFF88FF88,             text=""},
	{key = "alt",     type = "text",  pos = {x=1,y=1}, align = {x=0.5,y=1},   offset={x=-30,y=-50},   color=0xFF88FF88,             text=""},
	{key = "speed",   type = "text",  pos = {x=1,y=1}, align = {x=1,y=1},     offset={x=-200,y=-50},  color=0xFFFFCC66,             text=""},
	{key = "speed_bar",type = "text", pos = {x=1,y=1}, align = {x=1,y=1},     offset={x=-200,y=-38},  color=0xFFAAAAAA,             text=""},
}

ws.rg("FlightHUD", { category = "Render", setting = "flight_hud",
	description = "Show flight status HUD",
	on_start = function(self)
		if not core.localplayer then return true end
		self._hud_ids = {}
		for _, def in ipairs(hud_defs) do
			local args = {
				type = def.type,
				position = def.pos,
				alignment = def.align,
				offset = def.offset,
				text = def.text,
			}
			if def.scale then args.scale = def.scale end
			if def.color then args.number = def.color end
			self._hud_ids[def.key] = core.localplayer:hud_add(args)
		end
		self._last_roll_tex = nil
	end,
	on_step = function(self, dtime)
		local lp = core.localplayer
		if not lp then return end
		local hid = self._hud_ids

		local pitch = -lp:get_pitch()
		local roll = math.deg(lp:get_roll() or 0)

		local ind_y = clamp(-294 + math.floor(pitch * 1.5), -399, -189)
		set(hid.line, "offset", {x = -247, y = ind_y})

		local ri = math.floor((roll + 5) / 10) * 10
		ri = clamp(ri, -90, 90)
		local tex
		if ri == 0 then
			tex = "horizon_indicator.png"
		else
			local sign = ri > 0 and "" or "-"
			tex = string.format("hl_%s%d.png", sign, math.abs(ri))
		end
		if tex ~= self._last_roll_tex then
			set(hid.line, "text", tex)
			self._last_roll_tex = tex
		end
		set(hid.pitch, "text", string.format("Pitch: %.0f  Roll: %.0f", pitch, roll))
		set(hid.compass, "text", compass_string(lp:get_yaw()))

		if poi.target and poi.eta then
			local ttext = ""
			if autofly.follow_name then
				ttext = autofly.follow_name
			elseif poi.last_name then
				ttext = poi.last_name
			end
			if ttext ~= "" then ttext = ttext .. "\n" end
			ttext = ttext .. ws.pos_to_string(poi.target)
			if poi.eta > 0 then
				ttext = ttext .. "\nETA: " .. poi.eta .. " min"
			end
			set(hid.target, "text", ttext)
		else
			set(hid.target, "text", "")
		end

		local pos = lp:get_pos()
		local alt_color = 0xFF88FF88
		if pos.y < 0 then alt_color = 0xF9F9F9 end
		if pos.y > 500 then alt_color = 0xFFFFFF end
		set(hid.alt, "number", alt_color)
		set(hid.alt, "text", string.format("ALT\n %.0f", pos.y))

		local y_norm = clamp((pos.y + 32000) / 64000, 0, 1)
		set(hid.alt_bar, "text", alt_bar(y_norm))
		set(hid.alt_bar, "number", alt_color)

		local vel = lp:get_velocity()
		local speed = vel and vector.length(vel) or 0
		set(hid.speed, "text", string.format("%.1f n/s", speed))
		set(hid.speed_bar, "text", speed_bar(clamp(speed / 5, 0, 1)))
		set(hid.speed_bar, "number", speed > 3 and 0xFFFF6666 or 0xFFAAAAAA)
	end,
	on_stop = function(self)
		if not core.localplayer then return end
		for _, id in pairs(self._hud_ids) do
			if id then core.localplayer:hud_remove(id) end
		end
		self._hud_ids = {}
	end,
})
