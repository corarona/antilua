-- Event logger: merged from entity_logger, world_observer, breath_alert, movement_display
-- Per-server persistent logging: block counts, entity sightings, stats

local storage = core.get_mod_storage("event_logger")
local prefix = ""

ws.on_connect(function()
	local info = core.get_server_info()
	prefix = info.address .. ":" .. info.port .. ":"
end)

local function k(name)
	return prefix .. name
end


--
-- Movement display
--

local mov_display_debounce = 0

core.register_on_receive_physics_override(function(movement)
	if not core.settings:get_bool("movement_display") then
		return
	end
	local now = os.time()
	if now - mov_display_debounce < 2 then
		return
	end
	mov_display_debounce = now
	core.display_chat_message(string.format(
		"Movement: walk=%.1f jump=%.1f gravity=%.1f climb=%.1f",
		movement.speed_walk, movement.speed_jump,
		movement.gravity, movement.speed_climb))
end)

core.register_cheat("MovementDisplay", { category = "Render", setting = "movement_display",
	description = "Display movement info on screen" })

--
-- Block Logger (per-server persistent)
--

local ignore_nodes = {}
local ignore_set = {}
if nlist and nlist.get then
	ignore_nodes = nlist.get("block_logger_ignore")
	for _, v in ipairs(ignore_nodes) do ignore_set[v] = true end
end

core.register_on_dignode(function(pos, node)
	if not core.settings:get_bool("block_logger") then
		return false
	end
	if ignore_set[node.name] then
		return false
	end
	storage:set_int(k("blocks_dug:" .. node.name), storage:get_int(k("blocks_dug:" .. node.name)) + 1)
	return false
end)

core.register_on_node_add(function(pos, node)
	if not core.settings:get_bool("block_logger") then
		return
	end
	if ignore_set[node.name] then
		return
	end
	storage:set_int(k("blocks_placed:" .. node.name), storage:get_int(k("blocks_placed:" .. node.name)) + 1)
end)

core.register_cheat("BlockLogger", { category = "Info", setting = "block_logger",
	description = "Count blocks placed/dug per server" })

--
-- Stats display
--

local function collect_stats(storage, key_match)
	local items = {}
	for key, val in pairs(storage:to_table().fields) do
		if key:find(key_match) then
			local name = key:match(key_match)
			if name then
				items[name] = tonumber(val) or 0
			end
		end
	end
	return items
end

core.register_chatcommand("blockstats", {
	params = "",
	description = "Show per-server block and entity stats",
	func = function()
		if prefix == "" then
			core.display_chat_message("Not connected to any server yet.")
			return true
		end

		local placed = collect_stats(storage, "^" .. prefix .. "blocks_placed:(.+)$")
		local dug = collect_stats(storage, "^" .. prefix .. "blocks_dug:(.+)$")

		local lines = {}
		local pnames, dnames = {}, {}
		for name in pairs(placed) do table.insert(pnames, name) end
		for name in pairs(dug) do table.insert(dnames, name) end
		table.sort(pnames)
		table.sort(dnames)

		local function format_items(names, items, label)
			if #names == 0 then return end
			local parts = {}
			for _, n in ipairs(names) do
				table.insert(parts, n .. "=" .. items[n])
			end
			table.insert(lines, label .. table.concat(parts, " "))
		end

		format_items(pnames, placed, "Placed: ")
		format_items(dnames, dug, "Dug:    ")

		if #lines == 0 then
			core.display_chat_message("No stats recorded for this server yet.")
		else
			for _, line in ipairs(lines) do
				core.display_chat_message(line)
			end
		end
		return true
	end,
})
