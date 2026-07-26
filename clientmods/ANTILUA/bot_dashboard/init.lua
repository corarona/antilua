-- bot_dashboard: HUD overlay showing active bot status + activity log viewer

bot_dashboard = {}

local hud_id_text = nil
local hud_id_bg = nil
local update_timer = 0

-- Activity log ring buffer
local activity_log = {}
local MAX_LOG = 100

--- Add an entry to the bot activity log.
-- @param source  Bot name or source identifier (string)
-- @param text    Log message
-- @param ntype   Type: "info", "success", "warning", "error" (default "info")
function bot_dashboard.log(source, text, ntype)
	ntype = ntype or "info"
	table.insert(activity_log, {
		time = os.time(),
		source = source,
		text = text,
		ntype = ntype,
	})
	if #activity_log > MAX_LOG then
		table.remove(activity_log, 1)
	end
end

--- Get recent log entries.
function bot_dashboard.get_log(n)
	n = n or 50
	local count = math.min(n, #activity_log)
	local result = {}
	for i = #activity_log - count + 1, #activity_log do
		table.insert(result, activity_log[i])
	end
	return result
end

-- Format log entry for display
local function format_log_entry(entry)
	local time_str = os.date("%H:%M:%S", entry.time)
	local icons = { info = "*", success = "+", warning = "?", error = "!" }
	local icon = icons[entry.ntype] or "*"
	return string.format("[%s] %s %s: %s", time_str, icon, entry.source, entry.text)
end

-- Build HUD status text from active bots
local function build_status_text()
	local bots = sbots.get_active_bots()
	if #bots == 0 then return nil end
	local lines = {}
	for _, bot in ipairs(bots) do
		table.insert(lines, "● " .. bot.name .. ": " .. bot.status)
	end
	return table.concat(lines, "\n")
end

-- Create or update HUD elements
local function update_hud()
	local text = build_status_text()
	if not text then
		if hud_id_text then
			core.localplayer:hud_remove(hud_id_text)
			hud_id_text = nil
		end
		if hud_id_bg then
			core.localplayer:hud_remove(hud_id_bg)
			hud_id_bg = nil
		end
		return
	end

	if not hud_id_bg then
		hud_id_bg = core.localplayer:hud_add({
			hud_elem_type = "image",
			position = { x = 1, y = 0 },
			offset = { x = -210, y = 8 },
			text = "blank.png",
			scale = { x = 2, y = 2 },
			alignment = { x = 0, y = 0 },
			z_index = 100,
		})
	end

	if not hud_id_text then
		hud_id_text = core.localplayer:hud_add({
			hud_elem_type = "text",
			position = { x = 1, y = 0 },
			offset = { x = -205, y = 12 },
			number = 0x00ff00,
			alignment = { x = 0, y = 0 },
			z_index = 200,
		})
	end

	core.localplayer:hud_change(hud_id_text, "text", text)

	local line_count = select(2, text:gsub("\n", "")) + 1
	local bg_h = 12 + line_count * 14
	core.localplayer:hud_change(hud_id_bg, "offset", { x = -210, y = 8 })
end

-- Show activity log formspec
local function show_log()
	local entries = bot_dashboard.get_log(MAX_LOG)
	if #entries == 0 then
		ws.notify("Bot activity log is empty", ws.NOTIFY_INFO)
		return
	end
	local af = core.al_formspec
	local lines = {}
	for _, entry in ipairs(entries) do
		table.insert(lines, format_log_entry(entry))
	end
	local h = math.min(#lines, 16)
	local sb = af.cheat_form_begin("size[12," .. (1 + h) .. ",true]")
	sb:add(
		af.label(0, 0, "Bot Activity Log (" .. #lines .. " entries)"),
		af.textlist(0, 0.6, 11.5, h, "log_entries", lines, 0)
	)
	core.show_formspec("bot_dashboard:log", sb:get())
end

core.register_on_formspec_input(function(formname, fields)
	if formname == "bot_dashboard:log" then
		-- Close is handled automatically by cheat settings panel
	end
end)

-- Register cheat entries
core.register_cheat("BotLog", {
	category = "Bots",
	description = "View bot activity log",
	func = show_log,
})

-- Globalstep: update HUD every 0.5s
core.register_globalstep(function(dtime)
	update_timer = update_timer + dtime
	if update_timer < 0.5 then return end
	update_timer = 0
	update_hud()
end)

-- Clean up HUD on disconnect
core.register_on_disconnect(function()
	if hud_id_text then
		pcall(core.localplayer.hud_remove, core.localplayer, hud_id_text)
		hud_id_text = nil
	end
	if hud_id_bg then
		pcall(core.localplayer.hud_remove, core.localplayer, hud_id_bg)
		hud_id_bg = nil
	end
end)
