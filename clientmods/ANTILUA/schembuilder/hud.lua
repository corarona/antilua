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

hud_id = nil
local place_nodes_initial = 0

-- Remove the build HUD without touching the saved job (update_hud would
-- call clear_job() when place_nodes is empty, deleting the saved build).
function schembuilder_clear_hud()
	place_nodes_initial = 0
	if hud_id then
		if core.localplayer then
			core.localplayer:hud_remove(hud_id)
		end
		hud_id = nil
	end
end

function update_hud()
	if not core.localplayer then return end
	if #place_nodes == 0 then
		place_nodes_initial = 0
		clear_job()
		if hud_id then
			core.localplayer:hud_remove(hud_id)
			hud_id = nil
		end
		return
	end
	if #place_nodes > place_nodes_initial then
		place_nodes_initial = #place_nodes
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
	local placed = place_nodes_initial - #place_nodes
	local pct = place_nodes_initial > 0 and math.floor(placed * 100 / place_nodes_initial) or 0
	-- Truncate to top 44 (save one line for progress)
	local lines = {"Missing:"}
	local total = 0
	for i = 1, math.min(#sorted, 44) do
		local s = sorted[i]
		table.insert(lines, format_per_item(s.count) .. " X " .. s.name)
		total = total + s.count
	end
	if #sorted > 44 then
		table.insert(lines, "... +" .. (#sorted - 44) .. " more")
	end
	table.insert(lines, "Total: " .. total)
	if place_nodes_initial > 0 then
		table.insert(lines, "Progress: " .. pct .. "% (" .. placed .. "/" .. place_nodes_initial .. ")")
	end

	local text = table.concat(lines, "\n")

	if hud_id then
		core.localplayer:hud_change(hud_id, "text", text)
	else
		hud_id = core.localplayer:hud_add({
			type = "text",
			direction = 0,
			position = {x = 0.85, y = 0.25},
			alignment = {x = 1, y = 1},
			offset = {x = 0, y = 0},
			number = 0x00FF00,
			text = text,
		})
	end
end
