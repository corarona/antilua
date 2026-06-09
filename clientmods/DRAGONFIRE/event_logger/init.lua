-- Event logger: merged from entity_logger, world_observer, breath_alert, movement_display
-- Per-server persistent logging: block counts, entity sightings, stats

local storage = core.get_mod_storage("event_logger")
local prefix = ""

core.register_on_connect(function()
	local info = core.get_server_info()
	prefix = info.address .. ":" .. info.port .. ":"
	ws.notify("Session started", ws.NOTIFY_INFO, {toast = false})
end)

local function k(name)
	return prefix .. name
end

--
-- Entity logger
--

core.register_on_object_add(function(id)
	if not core.settings:get_bool("entity_logger") then
		return
	end
	ws.notify("Entity appeared, id=" .. id, ws.NOTIFY_INFO, {toast = false})
	storage:set_int(k("entity_appearances"), storage:get_int(k("entity_appearances")) + 1)
end)

core.register_on_object_hp_change(function(id, hp)
	if not core.settings:get_bool("entity_logger") then
		return
	end
	ws.notify("Entity " .. id .. " HP changed to " .. hp, ws.NOTIFY_INFO, {toast = false})
	storage:set_int(k("entity_hp_changes"), storage:get_int(k("entity_hp_changes")) + 1)
end)

core.register_cheat("EntityLogger", { category = "Render", setting = "entity_logger" })

--
-- World observer
--

core.register_on_node_add(function(pos, node)
	if not core.settings:get_bool("world_observer") then
		return
	end
	ws.notify("Node placed at " .. core.pos_to_string(pos), ws.NOTIFY_INFO, {toast = false})
end)

core.register_on_node_remove(function(pos)
	if not core.settings:get_bool("world_observer") then
		return
	end
	ws.notify("Node removed at " .. core.pos_to_string(pos), ws.NOTIFY_INFO, {toast = false})
end)

core.register_cheat("WorldObserver", { category = "Render", setting = "world_observer" })

--
-- Breath alert
--

core.register_on_breath_changed(function(breath)
	if not core.settings:get_bool("breath_alert") then
		return
	end
	if breath < 5 then
		ws.notify("Running out of breath! (" .. breath .. ")", ws.NOTIFY_WARNING)
	end
end)

core.register_cheat("BreathAlert", { category = "Player", setting = "breath_alert" })

--
-- Movement display
--

core.register_on_recieve_physics_override(function(movement)
	if not core.settings:get_bool("movement_display") then
		return
	end
	core.display_chat_message(string.format(
		"Movement: walk=%.1f jump=%.1f gravity=%.1f climb=%.1f",
		movement.speed_walk, movement.speed_jump,
		movement.gravity, movement.speed_climb))
end)

core.register_cheat("MovementDisplay", { category = "Render", setting = "movement_display" })

--
-- Block Logger (per-server persistent)
--

local ignore_nodes = {}
if nlist and nlist.get then
	ignore_nodes = nlist.get("block_logger_ignore")
end

core.register_on_dignode(function(pos, node)
	if not core.settings:get_bool("block_logger") then
		return false
	end
	if table.indexof(ignore_nodes, node.name) ~= -1 then
		return false
	end
	storage:set_int(k("blocks_dug:" .. node.name), storage:get_int(k("blocks_dug:" .. node.name)) + 1)
	return false
end)

core.register_on_node_add(function(pos, node)
	if not core.settings:get_bool("block_logger") then
		return
	end
	if table.indexof(ignore_nodes, node.name) ~= -1 then
		return
	end
	storage:set_int(k("blocks_placed:" .. node.name), storage:get_int(k("blocks_placed:" .. node.name)) + 1)
end)

core.register_cheat("BlockLogger", { category = "Info", setting = "block_logger",
	description = "Count blocks placed/dug per server" })

--
-- Stats display
--

local function sorted_pairs(t)
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	table.sort(keys)
	local i = 0
	return function()
		i = i + 1
		local k = keys[i]
		if k then return k, t[k] end
	end
end

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

core.registered_chatcommands["blockstats"] = {
	params = "",
	description = "Show per-server block and entity stats",
	func = function()
		if prefix == "" then
			core.display_chat_message("Not connected to any server yet.")
			return true
		end

		local placed = collect_stats(storage, "^" .. prefix .. "blocks_placed:(.+)$")
		local dug = collect_stats(storage, "^" .. prefix .. "blocks_dug:(.+)$")
		local entity_appearances = storage:get_int(k("entity_appearances"))
		local entity_hp_changes = storage:get_int(k("entity_hp_changes"))

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
		if entity_appearances > 0 then
			table.insert(lines, "Entities appeared: " .. entity_appearances)
		end
		if entity_hp_changes > 0 then
			table.insert(lines, "Entity HP changes: " .. entity_hp_changes)
		end

		if #lines == 0 then
			core.display_chat_message("No stats recorded for this server yet.")
		else
			for _, line in ipairs(lines) do
				core.display_chat_message(line)
			end
		end
		return true
	end,
}

core.register_cheat("BlockStats", { category = "Info", func = function()
	core.registered_chatcommands["blockstats"].func()
end })
