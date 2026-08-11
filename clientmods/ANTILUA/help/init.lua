-- help: centralized help system for Antilua client mods

local al_formspec = core.al_formspec
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

local function show_keybinds()
	local all = core.settings:get_names()
	local cats = {}
	for _, name in ipairs(all) do
		-- Skip hotbar slot keys (keymap_slot1..32) — noise for a cheat reference
		if name:find("^keymap_") and not name:find("^keymap_slot%d+$") then
			local cat = keybind_category(name)
			cats[cat] = cats[cat] or {}
			table.insert(cats[cat], name)
		end
	end

	-- Quick slot assignments (cheat_slot_1..9 → cheat name)
	local slots = {}
	for i = 1, 9 do
		local setting = core.settings:get("cheat_slot_" .. i)
		if setting and setting ~= "" then
			local def = core.cheat_defs and core.cheat_defs[setting]
			table.insert(slots, { slot = i, label = (def and def.name) or setting })
		end
	end

	local sb = al_formspec.begin("size[13,12,true]")
	sb:add(
		al_formspec.label(0, 0, "Key Bindings"),
		"scroll_container[0,0.6;12.4,10.5;kscroll;vertical]"
	)
	local y = 0
	local order = {"Cheat Menu", "Cheat Toggles", "Movement", "Interaction", "Camera", "UI", "Other"}
	for _, cat in ipairs(order) do
		if cats[cat] then
			table.sort(cats[cat])
			sb:add(al_formspec.label(0, y, "\226\150\160 " .. cat))
			y = y + 0.55
			for _, name in ipairs(cats[cat]) do
				local val = core.settings:get(name) or ""
				local action = name:gsub("^keymap_", "")
				sb:add(al_formspec.label(0.5, y, action))
				sb:add(al_formspec.label(7, y, format_key(val)))
				y = y + 0.45
			end
			y = y + 0.25
		end
	end

	-- Quick slot hotkeys (1-9)
	sb:add(al_formspec.label(0, y, "\226\150\160 Quick Slots (1-9 hotkeys)"))
	y = y + 0.55
	if #slots == 0 then
		sb:add(al_formspec.label(0.5, y, "None assigned \226\128\148 right-click a cheat and pick Slot."))
		y = y + 0.45
	else
		for _, s in ipairs(slots) do
			sb:add(al_formspec.label(0.5, y, "Slot " .. s.slot))
			sb:add(al_formspec.label(7, y, s.label))
			y = y + 0.45
		end
	end
	y = y + 0.25

	-- Quick palette reference
	local palette_keys = {
		{"~", "Open quick palette"},
		{"\226\134\145 \226\134\147", "Navigate"},
		{"Enter", "Run selected"},
		{"TAB", "Options submenu"},
		{"\226\134\146 / \226\134\144", "Enter / leave submenu"},
		{"1-9", "Toggle quick-slot cheat"},
		{"/", "Send as server command"},
		{".", "Browse client commands"},
		{"ESC", "Close / clear"},
	}
	sb:add(al_formspec.label(0, y, "\226\150\160 Quick Palette"))
	y = y + 0.55
	for _, row in ipairs(palette_keys) do
		sb:add(al_formspec.label(0.5, y, row[1]))
		sb:add(al_formspec.label(7, y, row[2]))
		y = y + 0.45
	end

	sb:add("scroll_container_end[]")
	sb:add(al_formspec.scrollbar(12.5, 0.6, 0.2, 10.5, "vertical", "kscroll", 0))
	sb:add(al_formspec.button_exit(5, 11.3, 3, 0.8, "", "Close"))
	core.show_formspec("help:keybinds", sb:get())
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

	local sb = al_formspec.begin("size[9,12,true]")
	sb:add(
		al_formspec.searchbar(0, 0, 8.2, "filter", { default = filter }),
		al_formspec.button(0, 0.9, 2.2, 0.6, "__commands", "Commands"),
		al_formspec.label(2.5, 0.95, "Help \226\128\148 Select a mod"),
		"scroll_container[0,1.5;8.7,9.5;mscroll;vertical]"
	)
	local sy = 0
	for i, entry in ipairs(results) do
		local label = entry.name
		if entry.note then
			label = label .. " (\226\128\164" .. entry.note .. ")"
		end
		sb:add(al_formspec.button(0, sy, 9, 0.6, "mod|" .. entry.name, label))
		sy = sy + 0.6
	end
	sb:add("scroll_container_end[]")
	sb:add(al_formspec.scrollbar(8.8, 1.5, 0.2, 9.5, "vertical", "mscroll", 0))
	sb:add(al_formspec.button_exit(3.5, 11.2, 2, 0.8, "", "Close"))
	core.show_formspec("help:index|" .. filter, sb:get())
end

-- Show searchable list of all registered client chat commands, grouped by
-- their originating mod. `filter` matches command name, description or params.
local function show_commands(filter)
	filter = (filter or "")
	local by_mod = {}
	local total = 0
	local q = filter:lower()
	for name, def in pairs(core.registered_chatcommands) do
		if type(def) == "table" then
			local origin = def.mod_origin or "??"
			if origin == "??" then origin = "Other" end
			local matches = filter == ""
				or name:lower():find(q, 1, true)
				or (def.description and def.description:lower():find(q, 1, true))
				or (def.params and def.params:lower():find(q, 1, true))
			if matches then
				by_mod[origin] = by_mod[origin] or {}
				table.insert(by_mod[origin], { name = name, def = def })
				total = total + 1
			end
		end
	end
	local mods = {}
	for m in pairs(by_mod) do table.insert(mods, m) end
	table.sort(mods)

	local sb = al_formspec.begin("size[9,12,true]")
	sb:add(
		al_formspec.searchbar(0, 0, 8.2, "filter", { default = filter }),
		al_formspec.button(0, 0.9, 2.2, 0.6, "__index", "Index"),
		al_formspec.label(2.5, 0.95, "Client Commands (" .. total .. ")"),
		"scroll_container[0,1.5;8.7,9.5;mscroll;vertical]"
	)
	local sy = 0
	for _, m in ipairs(mods) do
		sb:add(al_formspec.label(0, sy, "\194\187 " .. m))
		sy = sy + 0.55
		table.sort(by_mod[m], function(a, b) return a.name < b.name end)
		for _, entry in ipairs(by_mod[m]) do
			local label = "." .. entry.name
			if entry.def.params and entry.def.params ~= "" then
				label = label .. " " .. entry.def.params
			end
			sb:add(al_formspec.label(0.3, sy, label))
			local desc = entry.def.description or ""
			if #desc > 26 then
				desc = desc:sub(1, 26) .. "\226\128\166"
			end
			if desc ~= "" then
				sb:add(al_formspec.label(4.0, sy, desc))
			end
			sy = sy + 0.45
		end
		sy = sy + 0.25
	end
	sb:add("scroll_container_end[]")
	sb:add(al_formspec.scrollbar(8.8, 1.5, 0.2, 9.5, "vertical", "mscroll", 0))
	sb:add(al_formspec.button_exit(3.5, 11.2, 2, 0.8, "", "Close"))
	core.show_formspec("help:commands|" .. filter, sb:get())
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
	local sb = al_formspec.begin("size[10,11,true]")
	sb:add(
		al_formspec.button(0, 0, 2, 0.7, "__back", "< Back"),
		al_formspec.label(2.5, 0.15, modname .. " README"),
		"textarea[0,0.8;10,9.5;;;" .. core.formspec_escape(text) .. "]"
	)
	core.show_formspec("help:readme|" .. modname, sb:get())
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

		-- Commands button
		if fields.__commands then
			show_commands()
			return
		end

		-- Mod button clicks
		for raw in pairs(fields) do
			if raw:find("^mod|") then
				show_readme(raw:sub(5))
				return
			end
		end

		-- Filter: Go button or Enter in filter field
		if fields.__filter_search or (fields.filter and fields.filter ~= filter) then
			show_index(fields.filter or filter)
			return
		end

		return
	end
	if formname:find("^help:commands") then
		local filter = formname:match("^help:commands%|(.+)$") or ""

		-- Index button
		if fields.__index then
			show_index()
			return
		end

		-- Filter: Go button or Enter in filter field
		if fields.__filter_search or (fields.filter and fields.filter ~= filter) then
			show_commands(fields.filter or filter)
			return
		end

		return
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
	core.register_cheat("Commands", {
		category = "Misc",
		func = function() show_commands() end,
		description = "Browse all client chat commands",
	})
	core.register_chatcommand("help", {
		description = "Open help system. Use .help commands [filter] for the command reference",
		func = function(param)
			param = param or ""
			local sub, rest = param:match("^(%S+)%s*(.-)$")
			if sub == "commands" then
				show_commands(rest or "")
			else
				show_index(param)
			end
		end,
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
	core.register_cheat("Getting Started", {
		category = "Misc",
		func = function() show_index() end,
		description = "Open the help index: mods, cheats, commands and keybinds",
	})
end
