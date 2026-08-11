-- wasplib notification API
-- Centralized notification system for cheat feedback and user messages

ws.NOTIFY_INFO = "info"
ws.NOTIFY_SUCCESS = "success"
ws.NOTIFY_WARNING = "warning"
ws.NOTIFY_ERROR = "error"

local notify_chat_prefixes = {
	[ws.NOTIFY_INFO] = "[*] ",
	[ws.NOTIFY_SUCCESS] = "[+] ",
	[ws.NOTIFY_WARNING] = "[?] ",
	[ws.NOTIFY_ERROR] = "[!] ",
}

local notify_toast_types = {
	[ws.NOTIFY_INFO] = "info",
	[ws.NOTIFY_SUCCESS] = "success",
	[ws.NOTIFY_WARNING] = "warning",
	[ws.NOTIFY_ERROR] = "error",
}

-- Toast queue: stack multiple toasts, auto-dismiss oldest after delay
local toast_queue = {}
local toast_timer = nil

local function show_next_toast()
	if #toast_queue == 0 then
		toast_timer = nil
		return
	end
	local entry = table.remove(toast_queue, 1)
	if core.show_toast then
		core.show_toast(entry.text, entry.ntype)
	end
	toast_timer = core.after(entry.duration or 3, show_next_toast)
end

local function queue_toast(text, ntype, opts)
	local duration = opts.duration or 3
	table.insert(toast_queue, {
		text = text,
		ntype = notify_toast_types[ntype] or "info",
		duration = duration,
		id = opts._id,
	})
	if not toast_timer then
		show_next_toast()
	end
end

-- Notification history ring buffer (persisted so it survives reconnects)
local MAX_HISTORY = 80
local history_storage = core.get_mod_storage("wasplib")
local notify_history = (function()
	local data = history_storage:get_string("notify_history")
	if data and data ~= "" then
		local ok, arr = pcall(core.parse_json, data)
		if ok and type(arr) == "table" then
			if #arr > MAX_HISTORY then
				local cut = {}
				for i = #arr - MAX_HISTORY + 1, #arr do
					table.insert(cut, arr[i])
				end
				return cut
			end
			return arr
		end
	end
	return {}
end)()

local function save_history()
	history_storage:set_string("notify_history", core.write_json(notify_history) or "[]")
end

local function record_history(text, ntype, opts)
	table.insert(notify_history, {
		time = os.time(),
		text = text,
		ntype = ntype,
		opts = opts,
	})
	if #notify_history > MAX_HISTORY then
		table.remove(notify_history, 1)
	end
	save_history()
end

local default_handler

default_handler = function(text, ntype, opts)
	ntype = ntype or ws.NOTIFY_INFO
	opts = opts or {}

	record_history(text, ntype, opts)

	-- Send to chat (default on, set opts.chat = false to suppress)
	if opts.chat ~= false then
		core.display_chat_message((notify_chat_prefixes[ntype] or "[*] ") .. text)
	end

	-- Send to toast via queue (default on, set opts.toast = false to suppress)
	if opts.toast ~= false and core.show_toast then
		queue_toast(text, ntype, opts)
	end
end

local current_handler = default_handler

--- Send a notification to chat and optionally as a toast.
-- @param text   The notification text
-- @param ntype  Type: "info" (default), "success", "warning", "error"
-- @param opts   Optional table: { toast, chat, duration }
function ws.notify(text, ntype, opts)
	current_handler(text, ntype, opts)
end

--- Convenience notification for cheat toggle events (toast-only, no chat).
function ws.notify_cheat(cheat_name, enabled)
	if enabled then
		ws.notify(cheat_name .. " enabled", ws.NOTIFY_SUCCESS, {chat = false})
	else
		ws.notify(cheat_name .. " disabled", ws.NOTIFY_INFO, {chat = false})
	end
end

--- Progress notification. Appends a bar to the text and sends as toast.
-- Successive calls with the same id replace the most recent matching toast
-- (by removing it from the queue if not yet shown).
function ws.notify_progress(id, text, pct, ntype)
	ntype = ntype or ws.NOTIFY_INFO
	local bar = ""
	if core.al_formspec then
		bar = " " .. core.al_formspec.bar(pct, 100, 8)
	else
		bar = " " .. math.floor(pct) .. "%"
	end
	-- Remove any queued toast matching this id
	for i = #toast_queue, 1, -1 do
		if toast_queue[i].id == id then
			table.remove(toast_queue, i)
		end
	end
	ws.notify(text .. bar, ntype, {chat = false, duration = 2, _id = id})
end


--- Override the notification handler (for testing or customization).
-- Pass nil to restore the default handler.
function ws.set_notify_handler(handler)
	if handler then
		current_handler = handler
	else
		current_handler = default_handler
	end
end

--
-- Notification history accessors + viewer
--

--- Return recent notification history, most-recent-first.
-- @param n Number of entries to return (default: all, capped at MAX_HISTORY)
function ws.get_notify_history(n)
	n = n or MAX_HISTORY
	local count = math.min(n, #notify_history)
	local result = {}
	for i = #notify_history - count + 1, #notify_history do
		table.insert(result, notify_history[i])
	end
	return result
end

--- Clear the notification history (persisted).
function ws.clear_notify_history()
	notify_history = {}
	save_history()
end

local NOTIFY_ICONS = {
	info = "*", success = "+", warning = "?", error = "!",
}

-- Show the notification history viewer formspec
function ws.show_notify_history()
	local af = core.al_formspec
	if not af then
		core.display_chat_message("al_formspec not available for the notification viewer")
		return
	end
	local entries = ws.get_notify_history(MAX_HISTORY)
	if #entries == 0 then
		ws.notify("No notifications recorded yet", ws.NOTIFY_INFO, {chat = false})
		return
	end
	local lines = {}
	for _, e in ipairs(entries) do
		local icon = NOTIFY_ICONS[e.ntype] or "*"
		local ts = os.date("%H:%M:%S", e.time)
		table.insert(lines, "[" .. ts .. "] " .. icon .. " " .. e.text)
	end
	local h = math.min(#lines, 16)
	local sb = af.cheat_form_begin("size[12," .. (2 + h) .. ",true]")
	sb:add(
		af.label(0, 0, "Notification History (" .. #lines .. " entries)"),
		af.textlist(0, 0.6, 11.5, h, "notify_entries", lines, 0),
		af.button(0, 0.6 + h + 0.3, 2.5, 0.8, "notify_clear", "Clear"),
		af.button_exit(3, 0.6 + h + 0.3, 2.5, 0.8, "notify_close", "Close")
	)
	core.show_formspec("wasplib:notify_history", sb:get())
end

core.register_on_formspec_input(function(formname, fields)
	if formname ~= "wasplib:notify_history" then return end
	if fields.notify_clear then
		ws.clear_notify_history()
		ws.show_notify_history()
		return true
	end
	if fields.quit or fields.notify_close then
		return true
	end
end)

core.register_cheat("Notifications", {
	category = "Misc",
	func = ws.show_notify_history,
	description = "View recent notifications (toasts and chat alerts)",
})
