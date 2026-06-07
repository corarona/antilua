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

local default_handler

default_handler = function(text, ntype, opts)
	ntype = ntype or ws.NOTIFY_INFO
	opts = opts or {}

	-- Send to chat (default on, set opts.chat = false to suppress)
	if opts.chat ~= false then
		core.display_chat_message((notify_chat_prefixes[ntype] or "[*] ") .. text)
	end

	-- Send to toast if available and not suppressed
	if opts.toast ~= false and core.show_toast then
		core.show_toast(text, notify_toast_types[ntype] or "info")
	end
end

local current_handler = default_handler

--- Send a notification to chat and optionally as a toast.
-- @param text   The notification text
-- @param ntype  Type: "info" (default), "success", "warning", "error"
-- @param opts   Optional table: { toast = true } (set toast=false for chat-only)
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

--- Override the notification handler (for testing or customization).
-- Pass nil to restore the default handler.
function ws.set_notify_handler(handler)
	if handler then
		current_handler = handler
	else
		current_handler = default_handler
	end
end
