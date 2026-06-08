local hud_id = nil
local range = 200
local max_players = 8

local function direction_arrow(look_dir, to_dir)
	local angle = math.atan2(to_dir.z, to_dir.x) - math.atan2(look_dir.z, look_dir.x)
	while angle > math.pi do angle = angle - 2 * math.pi end
	while angle < -math.pi do angle = angle + 2 * math.pi end
	local deg = math.deg(angle)
	if deg > -22.5 and deg <= 22.5 then return "→"
	elseif deg > 22.5 and deg <= 67.5 then return "↘"
	elseif deg > 67.5 and deg <= 112.5 then return "↓"
	elseif deg > 112.5 and deg <= 157.5 then return "↙"
	elseif deg > 157.5 or deg <= -157.5 then return "←"
	elseif deg > -157.5 and deg <= -112.5 then return "↖"
	elseif deg > -112.5 and deg <= -67.5 then return "↑"
	elseif deg > -67.5 and deg <= -22.5 then return "↗"
	end
	return "?"
end

local function distance_color(dist)
	if dist < 50 then return "#00ff00"
	elseif dist < 100 then return "#ffff00"
	else return "#ff4444"
	end
end

local function update_radar()
	if not core.settings:get_bool("player_radar") then
		if hud_id then
			minetest.localplayer:hud_remove(hud_id)
			hud_id = nil
		end
		return
	end

	local lp = minetest.localplayer
	if not lp then return end

	local pos = lp:get_pos()
	if not pos then return end

	local yaw = lp:get_yaw()
	local pitch = lp:get_pitch()
	if not yaw then return end
	pitch = pitch or 0
	local yaw_rad = math.rad(yaw)
	local pitch_rad = math.rad(pitch)
	local look_dir = {
		x = -math.sin(yaw_rad) * math.cos(pitch_rad),
		y = math.sin(pitch_rad),
		z = -math.cos(yaw_rad) * math.cos(pitch_rad),
	}

	local objects = minetest.get_objects_inside_radius(pos, range)
	local entries = {}

	for _, obj in ipairs(objects) do
		local player_name = obj:get_player_name()
		if player_name and player_name ~= "" and player_name ~= core.get_player_name() then
			local opos = obj:get_pos()
			if opos then
				local dist = vector.distance(pos, opos)
				local to_dir = vector.normalize(vector.subtract(opos, pos))
				local arrow = direction_arrow(look_dir, to_dir)
				local color = distance_color(dist)
				table.insert(entries, {
					name = player_name,
					dist = dist,
					arrow = arrow,
					color = color,
				})
			end
		end
	end

	table.sort(entries, function(a, b) return a.dist < b.dist end)

	local parts = {}
	for i = 1, math.min(#entries, max_players) do
		local e = entries[i]
		table.insert(parts, e.color .. e.arrow .. " " .. e.name .. "(" .. math.floor(e.dist) .. ")")
	end

	local text = table.concat(parts, "  ")
	if text == "" then
		if hud_id then
			minetest.localplayer:hud_remove(hud_id)
			hud_id = nil
		end
		return
	end

	if hud_id then
		minetest.localplayer:hud_change(hud_id, "text", text)
	else
		hud_id = minetest.localplayer:hud_add({
			hud_elem_type = "text",
			position = {x = 0.5, y = 0.05},
			alignment = {x = 1, y = 0},
			offset = {x = 0, y = 0},
			text = text,
			number = 0xffffff,
			scale = {x = 2, y = 2},
		})
	end
end

minetest.register_globalstep(update_radar)

core.register_cheat("PlayerRadar", {
	category = "Render",
	setting = "player_radar",
	description = "Compass-style HUD bar showing nearby player directions and distances",
})

--
-- Light Overlay
--

local light_hud_id = nil
local light_etime = 0
local light_range = 8

local function update_light_overlay()
	if not core.settings:get_bool("light_overlay") then
		if light_hud_id then
			minetest.localplayer:hud_remove(light_hud_id)
			light_hud_id = nil
		end
		return
	end

	local lp = minetest.localplayer
	if not lp then return end

	local pos = lp:get_pos()
	if not pos then return end

	local low, medium, high = 0, 0, 0
	local px, pz = math.floor(pos.x + 0.5), math.floor(pos.z + 0.5)
	local py = math.floor(pos.y + 0.5)

	for dx = -light_range, light_range do
		for dz = -light_range, light_range do
			local light = core.get_node_light({ x = px + dx, y = py, z = pz + dz })
			if light then
				if light < 7 then low = low + 1
				elseif light < 11 then medium = medium + 1
				else high = high + 1 end
			end
		end
	end

	local total = low + medium + high
	if total == 0 then return end

	local pct_low = math.floor(low / total * 20)
	local pct_med = math.floor(medium / total * 20)
	local pct_high = 20 - pct_low - pct_med

	local bars = string.rep("#", pct_high) .. string.rep("=", pct_med) .. string.rep(".", pct_low)
	if #bars < 20 then
		bars = bars .. string.rep(" ", 20 - #bars)
	end

	local text = string.format("Light: #00ff00%s#ffff00%s#ff4444%s  #00ff00%d#ffff00 %d#ff4444 %d",
		string.rep("|", pct_high), string.rep("|", pct_med), string.rep("|", pct_low),
		high, medium, low)

	if light_hud_id then
		minetest.localplayer:hud_change(light_hud_id, "text", text)
	else
		light_hud_id = minetest.localplayer:hud_add({
			hud_elem_type = "text",
			position = {x = 0.5, y = 0.09},
			alignment = {x = 1, y = 0},
			offset = {x = 0, y = 0},
			text = text,
			number = 0xffffff,
			scale = {x = 1.5, y = 1.5},
		})
	end
end

minetest.register_globalstep(function(dtime)
	if not core.settings:get_bool("light_overlay") then
		if light_hud_id then
			minetest.localplayer:hud_remove(light_hud_id)
			light_hud_id = nil
		end
		return
	end
	light_etime = light_etime + dtime
	if light_etime < 0.5 then return end
	light_etime = 0
	update_light_overlay()
end)

core.register_cheat("LightOverlay", {
	category = "Render",
	setting = "light_overlay",
	description = "Show nearby light level distribution",
})
