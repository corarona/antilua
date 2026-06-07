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
