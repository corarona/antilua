function format_per_item(count)
	local sh_size = 27 * 64
	local shulkers = math.floor(count / sh_size)
	local after_sh = count % sh_size
	local stacks = math.floor(after_sh / 64)
	local items = after_sh % 64

	local parts = {}
	if shulkers > 0 then
		table.insert(parts, shulkers .. "sh")
	end
	if stacks > 0 then
		table.insert(parts, stacks .. "s")
	end
	if items > 0 or #parts == 0 then
		table.insert(parts, items .. "i")
	end
	return table.concat(parts, ", ")
end

local hud_id = nil

function update_hud()
	if not core.localplayer then return end
	if #place_nodes == 0 then
		clear_job()
		if hud_id then
			core.localplayer:hud_remove(hud_id)
			hud_id = nil
		end
		return
	end
	-- Count nodes by name
	local counts = {}
	for _, entry in ipairs(place_nodes) do
		local n = entry.name
		if n ~= "air" then
			counts[n] = (counts[n] or 0) + 1
		end
	end
	-- Build sorted list
	local sorted = {}
	for name, count in pairs(counts) do
		table.insert(sorted, {name = name, count = count})
	end
	table.sort(sorted, function(a, b) return a.count > b.count end)
	-- Truncate to top 45
	local lines = {"Missing:"}
	local total = 0
	for i = 1, math.min(#sorted, 45) do
		local s = sorted[i]
		table.insert(lines, format_per_item(s.count) .. " X " .. s.name)
		total = total + s.count
	end
	if #sorted > 45 then
		table.insert(lines, "... +" .. (#sorted - 45) .. " more")
	end
	table.insert(lines, "Total: " .. total)

	local text = table.concat(lines, "\n")

	if hud_id then
		core.localplayer:hud_change(hud_id, "text", text)
	else
		hud_id = core.localplayer:hud_add({
			type = "text",
			direction = 0,
			position = {x = 0.85, y = 0.05},
			alignment = {x = 1, y = 1},
			offset = {x = 0, y = 0},
			number = 0x00FF00,
			text = text,
		})
	end
end
