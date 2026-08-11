-- Per-server cheat profile auto-save/load
-- Uses the existing cheat profile system keyed by server address

-- Auto save/load toggles (default on)
if core.settings:get("profile_auto_save") == nil then
	core.settings:set("profile_auto_save", "true")
end
if core.settings:get("profile_auto_load") == nil then
	core.settings:set("profile_auto_load", "true")
end

local function server_key()
	local info = core.get_server_info()
	if not info then return nil end
	local addr = info.address
	if addr == "" then return "singleplayer" end
	return "server_" .. addr:gsub("[^%w_]", "_")
end

local function save_profile()
	local key = server_key()
	if not key then return end
	core.save_cheat_profile(key)
	core.log("info", "[qol] Saved cheat profile for " .. key)
end

local function load_profile()
	local key = server_key()
	if not key then return end
	local profiles = core.list_cheat_profiles()
	for _, name in ipairs(profiles) do
		if name == key then
			core.load_cheat_profile(key)
			core.log("info", "[qol] Loaded cheat profile for " .. key)
			break
		end
	end
end

ws.on_connect(function()
	if not core.settings:get_bool("profile_auto_load") then return end
	core.after(1.0, load_profile)
end)

core.register_on_disconnect(function()
	if core.settings:get_bool("profile_auto_save") then
		save_profile()
	end
end)

-- Per-server profile management (renamed from "profile" to avoid clobbering
-- the builtin .profile command in builtin/client/cheats.lua).
core.register_chatcommand("al_profile", {
	params = "save|load|delete <name>",
	description = "Manage per-server cheat profiles. Default name is the current server.",
	func = function(param)
		local parts = param:split(" ")
		local cmd = parts[1]
		local name = parts[2] or server_key()
		if not name then
			return false, "Not connected to a server"
		end
		if cmd == "save" then
			core.save_cheat_profile(name)
			return true, "Saved cheat profile: " .. name
		elseif cmd == "load" then
			core.load_cheat_profile(name)
			return true, "Loaded cheat profile: " .. name
		elseif cmd == "delete" then
			core.delete_cheat_profile(name)
			return true, "Deleted cheat profile: " .. name
		elseif cmd == "list" then
			local list = core.list_cheat_profiles()
			return true, "Profiles: " .. table.concat(list, ", ")
		else
			return false, "Usage: .al_profile save|load|delete|list [name]"
		end
	end,
})
