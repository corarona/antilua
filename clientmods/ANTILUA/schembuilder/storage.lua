function get_server_id()
	local info = core.get_server_info()
	if info then
		return info.address .. ":" .. info.port
	end
	return "localhost:30000"
end

function build_index_key()
	return "idx_" .. get_server_id()
end

function build_data_key(id)
	return "build_" .. id
end

function get_build_index()
	if not storage then return {} end
	local data = storage:get_string(build_index_key())
	if data and data ~= "" then
		local ok, idx = pcall(core.parse_json, data)
		if ok and type(idx) == "table" then
			return idx
		end
	end
	return {}
end

function save_build_index(idx)
	if not storage then return end
	storage:set_string(build_index_key(), core.write_json(idx) or "[]")
end

function gen_build_id()
	return os.time() .. "_" .. math.random(10000, 99999)
end

function save_job()
	if not storage or not current_build_id then return end
	local data = core.write_json(place_nodes)
	storage:set_string(build_data_key(current_build_id), data or "[]")
	local idx = get_build_index()
	for _, entry in ipairs(idx) do
		if entry.id == current_build_id then
			entry.remaining = #place_nodes
			break
		end
	end
	save_build_index(idx)
end

function load_build(id)
	if not storage then return false end
	local data = storage:get_string(build_data_key(id))
	if data and data ~= "" then
		local ok, nodes = pcall(core.parse_json, data)
		if ok and type(nodes) == "table" and #nodes > 0 then
			for _, n in ipairs(nodes) do
				n.param2 = n.param2 or 0
			end
			current_build_id = id
			place_nodes = nodes
			return true
		end
	end
	return false
end

function load_job()
	if not storage then return false end
	local idx = get_build_index()
	if #idx == 0 then return false end
	return load_build(idx[1].id)
end

function delete_build(id)
	if not storage then return end
	storage:set_string(build_data_key(id), "")
	local idx = get_build_index()
	for i = #idx, 1, -1 do
		if idx[i].id == id then
			table.remove(idx, i)
			break
		end
	end
	save_build_index(idx)
	if current_build_id == id then
		current_build_id = nil
	end
end

function clear_job()
	if current_build_id then
		delete_build(current_build_id)
	end
end

function create_build(source, name)
	if not storage then return end
	local id = gen_build_id()
	local data = core.write_json(place_nodes)
	storage:set_string(build_data_key(id), data or "[]")
	local idx = get_build_index()
	table.insert(idx, {
		id = id,
		name = name,
		source = source,
		count = #place_nodes,
		remaining = #place_nodes,
	})
	save_build_index(idx)
	current_build_id = id
end

function get_build_name(param)
	local name = param:match("^file:(.+)") or param
	name = name:match("([^/\\]+)%.?[^.]*$") or name
	return name
end

function chest_key(pos)
	return math.floor(pos.x) .. "," .. math.floor(pos.y) .. "," .. math.floor(pos.z)
end

function clear_supply_chests()
	supply_chests = {}
end

function add_supply_chest(pos)
	supply_chests[chest_key(pos)] = {x = math.floor(pos.x), y = math.floor(pos.y), z = math.floor(pos.z)}
end

function deserialize_workaround(content)
	local nodes, err = core.deserialize(content, true)
	if err then
		core.log("warning", "schembuilder: deserialize: " .. err)
	end
	return nodes or {}
end
