if core.settings:get("formspec_blocker") == nil then
	core.settings:set("formspec_blocker", "false")
end

local blocked_patterns = {}

core.register_on_receiving_formspec(function(formname, formspec)
	if not core.settings:get_bool("formspec_blocker") then
		return nil
	end
	for _, pattern in ipairs(blocked_patterns) do
		if formname:find(pattern) then
			return ""
		end
	end
	return nil
end)

core.register_cheat("FormspecBlocker", { category = "Interact", setting = "formspec_blocker" })
