core.register_chatcommand("schemclear", {
	description = "Clear the current schematic build and saved job data",
	func = function(param)
		place_nodes = {}
		clear_supply_chests()
		clear_job()
		if hud_id then
			core.localplayer:hud_remove(hud_id)
			hud_id = nil
		end
		if type(schemclear_cancel_wireframe) == "function" then
			schemclear_cancel_wireframe()
		end
		if type(core.clear_all_particles) == "function" then
			core.clear_all_particles()
		end
		ws.notify("Schematic build cleared", ws.NOTIFY_INFO)
		return true
	end,
})

-- Restore saved job on init and reconnect
function restore_job()
	if load_job() and #place_nodes > 0 then
		for _, n in ipairs(place_nodes) do
			add_preview_if_needed(n, n.name)
		end
		core.after(0.1, update_hud)
	end
end

restore_job()

ws.on_connect(function()
	restore_job()
end)

-- Undo support
local undo_stack = {}
local undo_max = 20

function push_undo(entries)
	if #entries == 0 then return end
	table.insert(undo_stack, core.write_json(entries))
	if #undo_stack > undo_max then
		table.remove(undo_stack, 1)
	end
end

function restore_undo_snapshot()
	if #undo_stack == 0 then return false, 0 end
	local data = table.remove(undo_stack)
	local ok, entries = pcall(core.parse_json, data)
	if not ok or type(entries) ~= "table" then return false, 0 end
	if #entries == 0 then return false, 0 end
	for _, n in ipairs(entries) do
		table.insert(place_nodes, n)
	end
	if hud_id then
		core.localplayer:hud_remove(hud_id)
		hud_id = nil
	end
	for _, n in ipairs(entries) do
		add_preview_if_needed(n, n.name)
	end
	core.after(0.1, update_hud)
	return true, #entries
end

core.register_chatcommand("schemundo", {
	description = "Undo the last placement batch",
	func = function()
		local ok, count = restore_undo_snapshot()
		if ok then
			ws.notify("Undo: restored " .. count .. " nodes", ws.NOTIFY_INFO)
			return true
		end
		return false, "Nothing to undo"
	end,
})

-- Exposed for other mods (e.g., mapart)
schembuilder_api = {
	load_mts = function(filepath, label, use_pos)
		if type(do_schembuild) ~= "function" then
			return false, "schembuilder not initialized"
		end
		local ok, err, sparam = do_schembuild("file:" .. filepath, use_pos)
		if ok then
			create_build(sparam or ("file:" .. filepath), label or "schematic")
		end
		return ok, err
	end,
}

-- Mapart integration API (called by mapart/gui.lua when available)
schembuilder._mapart_tab_fn = nil
schembuilder._mapart_event_fn = nil
function schembuilder.register_mapart_tab(fn)
	schembuilder._mapart_tab_fn = fn
end
function schembuilder.register_mapart_handler(fn)
	schembuilder._mapart_event_fn = fn
end
