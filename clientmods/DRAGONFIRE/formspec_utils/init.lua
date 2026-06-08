-- Formspec utilities: merged from formspec_blocker + formspec_modifier

--
-- Formspec blocker
--

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

--
-- Trash button injector
--

local function inject_trash_button(formname, formspec)
	if formname ~= "" then
		return nil
	end
	local btn = "button[7.5,4.5;1,0.5;trash;Trash]"
	local close = "button[8.5,4.5;1,0.5;close;Close]"
	local idx = formspec:find("formspec_version")
	if not idx then
		return nil
	end
	local eol = formspec:find("\n", idx)
	if not eol then
		return nil
	end
	local modified = formspec:sub(1, eol) .. btn .. close .. formspec:sub(eol + 1)
	return modified
end

core.register_on_receiving_inventory_form(function(formname, formspec)
	return inject_trash_button(formname, formspec)
end)

core.register_on_receiving_formspec(function(formname, formspec)
	return inject_trash_button(formname, formspec)
end)
