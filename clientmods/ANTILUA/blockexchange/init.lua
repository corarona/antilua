-- BlockExchange client mod
-- Downloads schematics from blockexchange servers and makes them
-- available to schembuilder as .mts files via mod storage.

blockexchange = {}

local URL = core.settings:get("blockexchange.url") or "https://blockexchange.minetest.ch"
local storage = core.get_mod_storage("blockexchange")
local http
local http_available = false

core.register_on_mods_loaded(function()
	-- Try at on_mods_loaded time when we know the function exists.
	-- This requires direct call from callback scope — pcall inside
	-- req_http_api itself doesn't affect the Lua stack frames here
	-- since we call it directly (not through pcall).
	local fn = core.request_http_api
	if fn then
		local result = fn()
		if result then
			http = result
			http_available = true
			core.log("action", "[blockexchange] HTTP API ready")
		end
	end
	if not http_available then
		core.log("warning", "[blockexchange] HTTP API not available")
	end
end)

---------------------------------------------------------------------------
-- Utilities
---------------------------------------------------------------------------

local function api_url(path)
	return URL .. "/api" .. path
end

local function json_decode(s)
	if not s or s == "" then return nil end
	local ok, val = pcall(core.parse_json, s)
	return ok and val or nil
end

local function json_encode(t)
	return core.write_json(t) or "{}"
end

---------------------------------------------------------------------------
-- Auth (token stored in mod storage)
---------------------------------------------------------------------------

function blockexchange.login(user, access_token, callback)
	if not http then callback(false, "HTTP not available"); return end
	http.fetch({
		url = api_url("/token"),
		method = "POST",
		data = json_encode({ name = user, access_token = access_token }),
		extra_headers = { "Content-Type: application/json" },
		timeout = 15,
	}, function(res)
		if not res.succeeded then
			callback(false, "Connection failed: " .. (res.reason or "unknown"))
			return
		end
		local data = json_decode(res.data)
		if not data or not data.token then
			local err = data and data.error or "Invalid response"
			callback(false, err)
			return
		end
		storage:set_string("token", data.token)
		storage:set_string("username", user)
		blockexchange.token = data.token
		blockexchange.username = user
		blockexchange.logged_in = true
		core.log("action", "[blockexchange] Logged in as " .. user)
		callback(true)
	end)
end

function blockexchange.logout()
	storage:set_string("token", "")
	storage:set_string("username", "")
	blockexchange.token = nil
	blockexchange.username = nil
	blockexchange.logged_in = false
end

-- Restore saved token on load
local saved_token = storage:get_string("token")
local saved_user = storage:get_string("username")
if saved_token and saved_token ~= "" and saved_user and saved_user ~= "" then
	blockexchange.token = saved_token
	blockexchange.username = saved_user
	blockexchange.logged_in = true
end

---------------------------------------------------------------------------
-- HTTP helpers with auth header
---------------------------------------------------------------------------

local function auth_headers()
	if not blockexchange.token then return {} end
	return { "Content-Type: application/json", "Authorization: " .. blockexchange.token }
end

local function get_json(url, cb)
	http.fetch({
		url = url,
		method = "GET",
		extra_headers = auth_headers(),
		timeout = 30,
	}, function(res)
		if not res.succeeded then
			cb(nil, "HTTP error: " .. tostring(res.reason))
			return
		end
		cb(json_decode(res.data))
	end)
end

local function post_json(url, data, cb)
	http.fetch({
		url = url,
		method = "POST",
		data = json_encode(data),
		extra_headers = auth_headers(),
		timeout = 30,
	}, function(res)
		if not res.succeeded then
			cb(nil, "HTTP error: " .. tostring(res.reason))
			return
		end
		cb(json_decode(res.data))
	end)
end

---------------------------------------------------------------------------
-- Search
---------------------------------------------------------------------------

function blockexchange.search(username, schemaname, callback)
	post_json(api_url("/search/schema"), {
		username = username,
		name = schemaname,
	}, function(data, err)
		if err then callback({}, err); return end
		if not data or not data.results then
			callback({})
			return
		end
		blockexchange.search_results = data.results
		callback(data.results)
	end)
end

---------------------------------------------------------------------------
-- Schemapart → MTS conversion
---------------------------------------------------------------------------

local function base64url_decode(s)
	if not s then return "" end
	local padded = s:gsub("-", "+"):gsub("_", "/")
	local pad_len = 4 - (#padded % 4)
	if pad_len < 4 then padded = padded .. string.rep("=", pad_len) end
	local ok, raw = pcall(core.decode_base64, padded)
	return ok and raw or ""
end

local function decompress(data)
	if not data or data == "" then return "" end
	local ok, raw = pcall(core.decompress, data, "deflate")
	return ok and raw or ""
end

local function parse_schemapart(data_b64, meta_b64)
	local raw = decompress(base64url_decode(data_b64))
	local meta_raw = decompress(base64url_decode(meta_b64))
	if raw == "" or meta_raw == "" then return nil end
	local meta = json_decode(meta_raw)
	if not meta or not meta.node_mapping then return nil end

	local node_mapping = {}
	for id_str, name in pairs(meta.node_mapping) do
		node_mapping[tonumber(id_str)] = name
	end

	local entries = {}
	local pos = 1
	local bytes_per_node = 4 -- 2 bytes node_id + 1 param1 + 1 param2
	for i = 1, 4096 do
		local offset = (i - 1) * bytes_per_node + 1
		if offset + 1 > #raw then break end
		local hi = string.byte(raw, offset)
		local lo = string.byte(raw, offset + 1)
		local node_id = (hi * 256) + lo
		local param2 = string.byte(raw, offset + 3) or 0
		local name = node_mapping[node_id] or "air"
		entries[i] = { name = name, prob = 254, param2 = param2 }
	end
	return entries
end

---------------------------------------------------------------------------
-- Download: iterate schemaparts and build full MTS buffer
---------------------------------------------------------------------------

local function create_mts_table(size_x, size_y, size_z, parts)
	local total = size_x * size_y * size_z
	local data = {}
	for i = 1, total do
		data[i] = { name = "air", prob = 254, param2 = 0 }
	end

	for _, part in ipairs(parts) do
		local ox, oy, oz = part.ox, part.oy, part.oz
		local entries = part.entries
		if entries then
			for iz = 0, 15 do
				for iy = 0, 15 do
					for ix = 0, 15 do
						local sx, sy, sz = ox + ix, oy + iy, oz + iz
						if sx < size_x and sy < size_y and sz < size_z then
							local idx = iz * size_y * size_x + iy * size_x + ix + 1
							local e = entries[idx]
							if e and e.name ~= "air" then
								local di = sz * size_y * size_x + sy * size_x + sx + 1
								data[di] = e
							end
						end
					end
				end
			end
		end
	end

	local schem = { size = { x = size_x, y = size_y, z = size_z }, data = data }
	local ok, mts = pcall(core.serialize_schematic, schem, "mts")
	return ok and mts or nil
end

---------------------------------------------------------------------------
-- Download with progress callback
---------------------------------------------------------------------------

function blockexchange.download(uid, name, size_x, size_y, size_z, progress_cb, done_cb)
	local parts = {}
	local parts_xy = math.ceil(size_x / 16)
	local parts_yz = math.ceil(size_y / 16)
	local parts_zz = math.ceil(size_z / 16)
	local total_parts = parts_xy * parts_yz * parts_zz
	local downloaded = 0
	local failed = false

	local function try_next()
		if failed then return end

		-- Find the next position to download
		local px, py, pz
		for z = 0, parts_zz - 1 do
			for y = 0, parts_yz - 1 do
				for x = 0, parts_xy - 1 do
					local found = false
					for _, p in ipairs(parts) do
						if p.ox == x * 16 and p.oy == y * 16 and p.oz == z * 16 then
							found = true; break
						end
					end
					if not found then px, py, pz = x * 16, y * 16, z * 16; break end
				end
				if px then break end
			end
			if px then break end
		end

		if not px then
			-- All parts downloaded, build MTS
			if progress_cb then
				progress_cb(total_parts, total_parts, "Converting to MTS...")
			end
			local mts = create_mts_table(size_x, size_y, size_z, parts)
			if mts then
				store_download(uid, name, mts, size_x, size_y, size_z)
				if done_cb then done_cb(true, name .. ".mts") end
			else
				if done_cb then done_cb(false, "Failed to create MTS") end
			end
			return
		end

		get_json(api_url("/schemapart/" .. uid .. "/" .. px .. "/" .. py .. "/" .. pz),
			function(data, err)
				if failed then return end
				if err then
					failed = true
					if done_cb then done_cb(false, err) end
					return
				end
				if not data or not data.data then
					-- Empty part, just skip
					downloaded = downloaded + 1
					if progress_cb then
						progress_cb(downloaded, total_parts, nil)
					end
					core.after(0, try_next)
					return
				end

				local entries = parse_schemapart(data.data, data.metadata)
				table.insert(parts, { ox = px, oy = py, oz = pz, entries = entries })

				downloaded = downloaded + 1
				if progress_cb then
					progress_cb(downloaded, total_parts, nil)
				end
				core.after(0, try_next)
			end
		)
	end

	try_next()
end

---------------------------------------------------------------------------
-- Storage for downloaded schematics
---------------------------------------------------------------------------

local function store_download(uid, name, mts_data, sx, sy, sz)
	local idx = json_decode(storage:get_string("download_idx")) or {}
	-- Check if already exists, update if so
	local found
	for i, entry in ipairs(idx) do
		if entry.uid == uid then
			found = i
			entry.name = name
			entry.size_x = sx
			entry.size_y = sy
			entry.size_z = sz
			break
		end
	end
	if not found then
		table.insert(idx, { uid = uid, name = name, size_x = sx, size_y = sy, size_z = sz })
	end
	storage:set_string("download_idx", json_encode(idx))
	storage:set_string("mts_" .. uid, core.encode_base64(mts_data))
end

function blockexchange.get_downloaded_list()
	local idx = json_decode(storage:get_string("download_idx")) or {}
	return idx
end

function blockexchange.get_mts_data(uid)
	local b64 = storage:get_string("mts_" .. uid)
	if b64 == "" then return nil end
	local ok, raw = pcall(core.decode_base64, b64)
	return ok and raw or nil
end

function blockexchange.delete_download(uid)
	storage:set_string("mts_" .. uid, "")
	local idx = json_decode(storage:get_string("download_idx")) or {}
	local new_idx = {}
	for _, entry in ipairs(idx) do
		if entry.uid ~= uid then
			table.insert(new_idx, entry)
		end
	end
	storage:set_string("download_idx", json_encode(new_idx))
end

---------------------------------------------------------------------------
-- Chat commands
---------------------------------------------------------------------------

core.register_chatcommand("bx_login", {
	params = "<username> <token>",
	description = "Log in to BlockExchange",
	func = function(param)
		local user, token = param:match("^(%S+)%s+(.+)$")
		if not user or not token then
			return false, "Usage: .bx_login <username> <token>"
		end
		if not http_available then
			return false, "HTTP not available — add blockexchange to secure.http_mods"
		end
		blockexchange.login(user, token, function(ok, err)
			if ok then
				ws.notify("Logged in to BlockExchange as " .. user, ws.NOTIFY_SUCCESS)
			else
				ws.notify("Login failed: " .. (err or "unknown"), ws.NOTIFY_ERROR)
			end
		end)
		return true, "Logging in..."
	end,
})

core.register_chatcommand("bx_logout", {
	description = "Log out from BlockExchange",
	func = function()
		blockexchange.logout()
		return true, "Logged out."
	end,
})
