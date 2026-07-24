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
