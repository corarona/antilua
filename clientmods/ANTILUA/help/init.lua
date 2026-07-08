-- help: centralized help system for Antilua client mods

local md_parser = dofile(core.get_modpath(core.get_current_modname()) .. "/md_parser.lua")

-- Scan all READMEs and populate cheat descriptions
local function populate_descriptions()
	local mods = md_parser.list_mods()
	for _, modname in ipairs(mods) do
		local md = md_parser.read_readme(modname)
		if md then
			local cheats = md_parser.parse_cheats_table(md)
			for _, entry in ipairs(cheats) do
				if entry.setting then
					local def = core.cheat_defs[entry.setting]
					if def then
						def.description = entry.description
					end
				end
			end
		end
	end
end

-- Format a raw key value for human display
local function format_key(val)
	local s = val:gsub("^KEY_", ""):gsub("^SYSTEM_SCANCODE_", ""):gsub("_", " ")
	local special = {
		["43"] = "TAB",
		["53"] = "` ~",
		["40"] = "Return",
		["41"] = "Escape",
		["57"] = "Space",
		["58"] = "F1",
		["59"] = "F2",
		["60"] = "F3",
		["61"] = "F4",
		["62"] = "F5",
	}
	return special[s] or s
end

-- Categorize a keymap_ setting by its action
local function keybind_category(name)
	if name:find("cheat") or name:find("select") or name:find("quick") or name:find("help") then
		return "Cheat Menu"
	elseif name:find("toggle_") or name:find("enderchest") then
		return "Cheat Toggles"
	elseif name:find("camera") or name:find("roll") then
		return "Camera"
	elseif name:find("^keymap_forward$") or name:find("^keymap_backward$")
			or name:find("^keymap_left$") or name:find("^keymap_right$")
			or name:find("jump") or name:find("sneak") or name:find("aux") then
		return "Movement"
	elseif name:find("dig") or name:find("place") or name:find("drop") then
		return "Interaction"
	elseif name:find("chat") or name:find("console") or name:find("inventory")
			or name:find("rangeselect") or name:find("zoom") then
		return "UI"
	end
	return "Other"
end

-- Show auto-generated keybind reference
local function show_keybinds()
	local all = core.settings:get_names()
	local cats = {}
	for _, name in ipairs(all) do
		if name:find("^keymap_") then
			local cat = keybind_category(name)
			cats[cat] = cats[cat] or {}
			table.insert(cats[cat], name)
		end
	end

	local fs = "formspec_version[4]size[13,12,true]"
	fs = fs .. "label[0,0;Key Bindings]"
	local y = 0.6
	local order = {"Cheat Menu", "Cheat Toggles", "Movement", "Interaction", "Camera", "UI", "Other"}
	for _, cat in ipairs(order) do
		if not cats[cat] then goto skip end
		table.sort(cats[cat])
		fs = fs .. "label[0," .. y .. ";■ " .. cat .. "]"
		y = y + 0.55
		for _, name in ipairs(cats[cat]) do
			if y > 11 then break end
			local val = core.settings:get(name) or ""
			local action = name:gsub("^keymap_", "")
			fs = fs .. "label[0.5," .. y .. ";" .. core.formspec_escape(action) .. "]"
			fs = fs .. "label[7," .. y .. ";" .. core.formspec_escape(format_key(val)) .. "]"
			y = y + 0.45
		end
		y = y + 0.25
		::skip::
	end
	fs = fs .. "button[5," .. math.min(y + 0.3, 11.5) .. ";3,0.8;__close;Close]"
	core.show_formspec("help:keybinds", fs)
end

-- Show searchable help index (mods + cheats)
local function show_index(filter)
	filter = (filter or "")
	local mods = md_parser.list_mods()

	-- Collect mods matching filter
	local results = {}
	for _, modname in ipairs(mods) do
		if filter == "" or modname:lower():find(filter:lower(), 1, true) then
			table.insert(results, {type = "mod", name = modname})
		end
	end

	if filter ~= "" then
		for _, modname in ipairs(mods) do
			local md = md_parser.read_readme(modname)
			if md then
				local cheats = md_parser.parse_cheats_table(md)
				for _, entry in ipairs(cheats) do
					if entry.setting and (entry.cheat:lower():find(filter:lower(), 1, true) or
					   (entry.description and entry.description:lower():find(filter:lower(), 1, true))) then
						local already = false
						for _, r in ipairs(results) do
							if r.type == "mod" and r.name == modname then already = true; break end
						end
						if not already then
							table.insert(results, {type = "mod", name = modname, note = entry.cheat})
						end
					end
				end
			end
		end
	end

	local h = math.min(#results, 18)
	local fs = "formspec_version[4]size[9," .. (2 + h) .. ",true]"
	fs = fs .. "field[0,0;6.5,0.8;filter;Filter:;" .. core.formspec_escape(filter) .. "]"
	fs = fs .. "button[7,0;1.7,0.8;__search;Go]"
	fs = fs .. "label[0,0.9;Help — Select a mod]"
	local y = 1.5
	for i, entry in ipairs(results) do
		if i > 18 then
			fs = fs .. "label[0," .. y .. ";... (+" .. (#results - 18) .. " more)]"
			break
		end
		local label = entry.name
		if entry.note then
			label = label .. " (\226\128\164" .. entry.note .. ")"
		end
		fs = fs .. "button[0," .. y .. ";9,0.6;mod|" .. entry.name .. ";"
			.. core.formspec_escape(label) .. "]"
		y = y + 0.6
	end
	fs = fs .. "button[3.5," .. (y + 0.3) .. ";2,0.8;__close;Close]"
	core.show_formspec("help:index|" .. filter, fs)
end

-- Show a mod's README in a formspec textarea
local function show_readme(modname)
	local md = md_parser.read_readme(modname)
	if not md then
		core.display_chat_message("No README found for: " .. modname)
		show_index()
		return
	end
	local text = md_parser.to_plaintext(md)
	if #text > 32000 then
		text = text:sub(1, 32000) .. "\n\n[... truncated ...]"
	end
	local fs = "formspec_version[4]size[10,11,true]"
	fs = fs .. "button[0,0;2,0.7;__back;< Back]"
	fs = fs .. "label[2.5,0.15;" .. core.formspec_escape(modname) .. " README]"
	fs = fs .. "textarea[0,0.8;10,9.5;;;" .. core.formspec_escape(text) .. "]"
	core.show_formspec("help:readme|" .. modname, fs)
end

-- Show help for a specific cheat setting (opens its mod's README)
local function show_cheat_help(setting)
	local info = md_parser.find_cheat(setting)
	if info then
		show_readme(info.mod)
	else
		core.display_chat_message("No help found for: " .. setting)
	end
end

-- Expose so other mods (e.g. cheat settings formspec) can call it
core.show_cheat_help = show_cheat_help

-- Formspec input handler
core.register_on_formspec_input(function(formname, fields)
	if formname:find("^help:index") then
		local filter = formname:match("^help:index%|(.+)$") or ""
		if fields.__search or fields.filter then
			show_index(fields.filter or filter)
			return
		end
		if fields.__close then return end
		for raw in pairs(fields) do
			if raw:find("^mod|") then
				show_readme(raw:sub(5))
				return
			end
		end
	end
	local modname = formname:match("^help:readme%|(.+)$")
	if modname then
		if fields.__back then
			show_index()
			return
		end
	end
	if formname:find("^help:keybinds") and fields.__close then return end
end)

-- Register Help cheat and /help command
if core.register_cheat then
	core.register_cheat("Help", {
		category = "Misc",
		func = function() show_index() end,
		description = "Open the cheat help index with search",
	})
	core.register_chatcommand("help", {
		description = "Open help system",
		func = function() show_index() end,
	})
end

-- Populate descriptions after all mods load
core.register_on_mods_loaded(populate_descriptions)

-- Register Keybinds cheat
if core.register_cheat then
	core.register_cheat("Keybinds", {
		category = "Misc",
		func = show_keybinds,
		description = "Show auto-generated keybindings reference",
	})
end
