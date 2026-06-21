-- InvLogger + InvSnapshot

local prev_snapshot = nil

local function get_inv_snapshot()
	local inv = core.get_inventory("current_player")
	if not inv then
		return nil
	end
	local snap = {}
	for listname, list in pairs(inv) do
		snap[listname] = {}
		for _, stack in ipairs(list) do
			local name = stack:get_name()
			if name ~= "" then
				snap[listname][name] = (snap[listname][name] or 0) + stack:get_count()
			end
		end
	end
	return snap
end

local function diff_snapshots(old, new)
	local added = {}
	local removed = {}
	for listname, items in pairs(new) do
		for name, count in pairs(items) do
			local prev_count = (old[listname] or {})[name] or 0
			local diff = count - prev_count
			if diff > 0 then
				added[#added + 1] = name .. " x" .. diff
			elseif diff < 0 then
				removed[#removed + 1] = name .. " x" .. (-diff)
			end
		end
	end
	for listname, items in pairs(old or {}) do
		for name, count in pairs(items) do
			if not (new[listname] or {})[name] then
				removed[#removed + 1] = name .. " x" .. count
			end
		end
	end
	return added, removed
end

core.register_on_inventory_action(function()
	if not core.settings:get_bool("invlogger") then
		return
	end
	local notify = core.settings:get("invlogger.notify") or "toast"
	if notify == "off" then
		return
	end
	local msg = "Inventory action"
	if notify == "toast" or notify == "both" then
		ws.notify(msg, ws.NOTIFY_INFO)
	end
	if notify == "chat" or notify == "both" then
		core.display_chat_message(msg)
	end
end)

core.register_on_inventory_update(function()
	if not core.settings:get_bool("invsnapshot") then
		return
	end
	local snap = get_inv_snapshot()
	if not snap then
		return
	end
	if prev_snapshot then
		local added, removed = diff_snapshots(prev_snapshot, snap)
		local msgs = {}
		if core.settings:get_bool("invsnapshot.notify_added", true) then
			for _, item in ipairs(added) do
				msgs[#msgs + 1] = "+" .. item
			end
		end
		if core.settings:get_bool("invsnapshot.notify_removed", true) then
			for _, item in ipairs(removed) do
				msgs[#msgs + 1] = "-" .. item
			end
		end
		if #msgs > 0 then
			ws.notify(table.concat(msgs, ", "), ws.NOTIFY_INFO)
		end
	end
	prev_snapshot = snap
end)

core.register_cheat({ name = "InvLogger", category = "Info",
	setting = "invlogger",
	description = "Notify on inventory actions",
	cheat_settings = {
		notify = { type = "enum", values = {"toast", "both", "off"}, default = "toast" },
	},
})

core.register_cheat({ name = "InvSnapshot", category = "Info",
	setting = "invsnapshot",
	description = "Notify on inventory content changes",
	cheat_settings = {
		notify_added = { type = "bool", default = true },
		notify_removed = { type = "bool", default = true },
	},
})
