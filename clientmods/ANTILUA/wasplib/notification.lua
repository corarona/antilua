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
	})
	if not toast_timer then
		show_next_toast()
	end
end

-- Notification history ring buffer
local notify_history = {}
local MAX_HISTORY = 80

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

--- Return recent notification history (table of {time, text, ntype, opts}).
function ws.get_notification_log(n)
	n = n or 20
	local count = math.min(n, #notify_history)
	local result = {}
	for i = #notify_history - count + 1, #notify_history do
		table.insert(result, notify_history[i])
	end
	return result
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
