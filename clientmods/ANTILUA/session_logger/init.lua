

-- Chat logger (persistent per-server file) handles the file sink — see chat_logger mod.
-- session_logger handles ChatAlerts, NameColorizer, join/leave toasts, and session stats.

--
-- Session stats (from cchat + session_stats)
--

local start_time = 0
local deaths = 0
local damage_taken = 0

core.register_on_connect(function()
	start_time = core.get_us_time() / 1000000
	deaths = 0
	damage_taken = 0
	ws.notify("Session started", ws.NOTIFY_INFO, {toast = false})
end)

core.register_on_death(function()
	deaths = deaths + 1
end)

core.register_on_damage_taken(function(amount)
	damage_taken = damage_taken + amount
end)

core.registered_chatcommands["stats"] = {
	params = "",
	description = "Show session stats (play time, deaths, damage)",
	func = function()
		local elapsed = core.get_us_time() / 1000000 - start_time
		local hours = math.floor(elapsed / 3600)
		local minutes = math.floor((elapsed % 3600) / 60)
		local seconds = math.floor(elapsed % 60)
		local time_str = string.format("%dh %dm %ds", hours, minutes, seconds)
		core.display_chat_message(string.format(
			"Session: %s | Deaths: %d | Damage taken: %d",
			time_str, deaths, damage_taken))
		return true
	end,
}

local alert_keywords = {}
if nlist and nlist.get then
	alert_keywords = nlist.get("chat_alert_keywords")
end

local name_colors = {}
if nlist and nlist.get then
	name_colors = nlist.get("name_colors")
end

core.register_cheat("ChatAlerts", {
	category = "Social",
	setting = "chat_alerts",
	description = "Highlight and notify on chat keywords",
})

core.register_cheat("NameColorizer", {
	category = "Social",
	setting = "name_colorizer",
	description = "Colorize player names in chat",
})

core.register_on_receiving_chat_message(function(message)
	local stripped = core.strip_colors(message)

	-- Join/leave toast
	if stripped:find("^%*%*%* .+ joined the game%.?$") then
		local name = stripped:match("^%*%*%* (.+) joined")
		if name then
			core.show_toast(name .. " joined", "info")
			return true
		end
	end
	if stripped:find("^%*%*%* .+ left the game") then
		local name = stripped:match("^%*%*%* (.+) left")
		if name then
			core.show_toast(name .. " left", "info")
			return true
		end
	end

	-- Chat alerts
	if core.settings:get_bool("chat_alerts") then
		for _, kw in ipairs(alert_keywords) do
			if stripped:lower():find(kw:lower()) then
				ws.notify("Chat alert: " .. kw, ws.NOTIFY_WARNING)
				return core.colorize("#ffff00", stripped)
			end
		end
	end

	-- Name colorizer
	if core.settings:get_bool("name_colorizer") then
		local result = message
		for _, entry in ipairs(name_colors) do
			local name, color = entry:match("^(.+)=#(%x+)$")
			if name and color then
				result = result:gsub("<" .. name .. ">", "<" .. core.colorize("#" .. color, name) .. ">")
				result = result:gsub("(" .. name .. ")", "(" .. core.colorize("#" .. color, name) .. ")")
			end
		end
		if result ~= message then
			return result
		end
	end

	return nil
end)
