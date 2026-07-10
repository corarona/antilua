local function utf8char(cp)
	if cp < 128 then return string.char(cp)
	elseif cp < 2048 then
		return string.char(192 + math.floor(cp / 64), 128 + cp % 64)
	elseif cp < 65536 then
		return string.char(
			224 + math.floor(cp / 4096), 128 + math.floor(cp / 64 % 64), 128 + cp % 64)
	else
		return string.char(
			240 + math.floor(cp / 262144), 128 + math.floor(cp / 4096 % 64),
			128 + math.floor(cp / 64 % 64), 128 + cp % 64)
	end
end

local function decode_sign_text(meta)
	local raw = core.deserialize(meta:get_string("utext"), true) or {}
	local parts = {}
	for _, cp in ipairs(raw) do
		parts[#parts + 1] = utf8char(cp)
	end
	return table.concat(parts)
end

local hud_id = nil
local last_sign_pos = nil
local logged_positions = {}

local function get_log_path()
	local info = core.get_server_info()
	if not info or not info.address then return nil end
	local addr = info.address
	local port = info.port or "30000"
	return core.get_builtin_path() .. "/../logs/"
		.. addr .. ":" .. port .. "/sign_log.txt"
end

local function ensure_log_dir(path)
	local dir = path:match("^(.*/)")
	if dir then
		core.mkdir(dir)
	end
end

local function append_log(pos, text)
	local path = get_log_path()
	if not path then return end
	local key = core.pos_to_string(pos)
	if logged_positions[key] then return end
	logged_positions[key] = true
	ensure_log_dir(path)
	core.write_file(path, "[" .. key .. "] " .. text .. "\n", true)
end

local function remove_hud()
	if hud_id then
		core.localplayer:hud_remove(hud_id)
		hud_id = nil
		last_sign_pos = nil
	end
end

local function truncate_text(text, max_len)
	if #text <= max_len then return text end
	return text:sub(1, max_len - 3) .. "..."
end

ws.rg("SignReader", {
	category = "Info",
	setting = "sign_reader",
	description = "Read sign text when looking at a sign",
	delay = 0.15,

	on_step = function()
		if not core.localplayer then return end
		local range = ws.get_number("sign_reader", "range", 10)
		local pt = core.get_pointed_thing()
		if not pt or pt.type ~= "node" then
			remove_hud()
			return
		end

		local pos = pt.under
		local dist = vector.distance(core.localplayer:get_pos(), pos)
		if dist > range then
			remove_hud()
			return
		end

		local node = core.get_node_or_nil(pos)
		if not node then
			remove_hud()
			return
		end
		local def = core.get_node_def(node.name)
		if not def or not def.groups or not def.groups.sign then
			remove_hud()
			return
		end

		if last_sign_pos and vector.equals(last_sign_pos, pos) then
			return
		end

		local meta = core.get_meta(pos)
		local text = decode_sign_text(meta)
		if text == "" then
			remove_hud()
			return
		end

		last_sign_pos = pos
		remove_hud()

		local display = truncate_text(text, 64)
		hud_id = core.localplayer:hud_add({
			type = "waypoint",
			name = display,
			text = "",
			number = 0xFFFF00,
			world_pos = pos,
		})

		if ws.get_bool("sign_reader", "log", false) then
			append_log(pos, text)
		end
	end,

	on_stop = function()
		remove_hud()
	end,

	cheat_settings = {
		range = { type = "number", default = 10, min = 2, max = 50 },
		log = { type = "bool", default = false },
	},
})
