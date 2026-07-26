-- Detect coordinates in chat messages and create waypoints
local function parse_coords(msg)
	if not msg then return nil end
	local x, y, z
	-- Match patterns like (123, 45, -678), 123 45 -678, X:123 Y:45 Z:-678
	x, y, z = msg:match("%((%-?%d+)[,;%s]+(%-?%d+)[,;%s]+(%-?%d+)%)")
	if not x then
		x, y, z = msg:match("X[:=]%s*(%-?%d+).-Y[:=]%s*(%-?%d+).-Z[:=]%s*(%-?%d+)")
	end
	if not x then
		x, y, z = msg:match("(%-?%d+)[,;%s]+(%-?%d+)[,;%s]+(%-?%d+)")
	end
	if x and y and z then
		return {x = tonumber(x), y = tonumber(y), z = tonumber(z)}
	end
	return nil
end

local function show_coord_waypoint(pos, source)
	if not pos then return end
	local key = "coord:" .. pos.x .. "," .. pos.y .. "," .. pos.z
	local label = string.format("Chat coord: %.0f, %.0f, %.0f", pos.x, pos.y, pos.z)
	ws.hud_waypoint(key, pos, 0x00FF00, label)
	core.after(60, function()
		ws.hud_remove_waypoint(key)
	end)
	ws.notify(label .. " — use .teleport to go there", ws.NOTIFY_INFO, {chat = false})
end

core.register_on_receiving_chat_message(function(msg)
	local pos = parse_coords(msg)
	if pos then
		show_coord_waypoint(pos, msg)
	end
	return nil
end)
