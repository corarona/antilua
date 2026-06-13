-- help: centralized help system for Antilua client mods
-- Reads README.md files, populates cheat descriptions, shows full READMEs in formspec.

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

-- Mod index formspec
local function show_index()
	local mods = md_parser.list_mods()
	if #mods == 0 then
		core.display_chat_message("No README files found.")
		return
	end

	local h = math.min(#mods, 18)
	local fs = "formspec_version[4]size[9," .. (2 + h) .. ",true]"
	fs = fs .. "label[0,0;Help — Select a mod]"
	local y = 0.6
	for i, modname in ipairs(mods) do
		if i > 18 then
			fs = fs .. "label[0," .. y .. ";... (+" .. (#mods - 18) .. " more)]"
			break
		end
		fs = fs .. "button[0," .. y .. ";3,0.7;mod|" .. modname .. ";" .. modname .. "]"
		y = y + 0.7
	end
	fs = fs .. "button[3.5," .. (y + 0.3) .. ";2,0.8;__close;Close]"
	core.show_formspec("help:index", fs)
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
	-- Truncate if too long for formspec
	if #text > 32000 then
		text = text:sub(1, 32000) .. "\n\n[... truncated ...]"
	end
	local fs = "formspec_version[4]size[10,11,true]"
	fs = fs .. "button[0,0;2,0.7;__back;< Back]"
	fs = fs .. "label[2.5,0.15;" .. core.formspec_escape(modname) .. " README]"
	fs = fs .. "textarea[0,0.8;10,9.5;;;" .. core.formspec_escape(text) .. "]"
	core.show_formspec("help:readme|" .. modname, fs)
end

-- Formspec input handler
core.register_on_formspec_input(function(formname, fields)
	if formname == "help:index" then
		if fields.__close then
			return
		end
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
end)

-- Register Help in cheat menu
if core.register_cheat then
	core.register_cheat("Help", {
		category = "Misc",
		func = show_index,
		description = "Open the cheat help index",
	})
	-- Also register a search command
	core.register_chatcommand("help", {
		description = "Open help system",
		func = show_index,
	})
end

-- Populate descriptions after all mods load
core.register_on_mods_loaded(populate_descriptions)

-- Keybind reference
local keybind_list = {
	{"Toggle Cheat Menu",   "keymap_toggle_cheat_menu", "TAB"},
	{"Toggle Killaura",     "keymap_toggle_killaura",  "X"},
	{"Toggle Freecam",      "keymap_toggle_freecam",   "G"},
	{"Toggle Scaffold",     "keymap_toggle_scaffold",  "Y"},
	{"Ender Chest",         "keymap_enderchest",       "H"},
	{"Cheat Menu Up",       "keymap_select_up",        "Up Arrow"},
	{"Cheat Menu Down",     "keymap_select_down",      "Down Arrow"},
	{"Cheat Menu Left",     "keymap_select_left",      "Left Arrow"},
	{"Cheat Menu Right",    "keymap_select_right",     "Right Arrow"},
	{"Cheat Menu Confirm",  "keymap_select_confirm",   "Return"},
}

local function show_keybinds()
	local fs = "formspec_version[4]size[10,10,true]"
	fs = fs .. "label[0,0;Key Bindings]"
	fs = fs .. "label[0,0.8;Action]"
	fs = fs .. "label[5,0.8;Current Key]"
	fs = fs .. "box[0,1;10,0.05;#ffffff30]"
	local y = 1.2
	for _, entry in ipairs(keybind_list) do
		local label, setting, default = table.unpack(entry)
		local current = core.settings:get(setting) or default
		local formatted = current:gsub("^KEY_", ""):gsub("^SYSTEM_SCANCODE_", "SCANCODE_"):gsub("_", " ")
		fs = fs .. "label[0," .. y .. ";" .. core.formspec_escape(label) .. "]"
		fs = fs .. "label[5," .. y .. ";" .. core.formspec_escape(formatted) .. "]"
		y = y + 0.7
	end
	fs = fs .. "button[3.5," .. (y + 0.3) .. ";3,0.8;__close;Close]"
	core.show_formspec("help:keybinds", fs)
end

if core.register_cheat then
	core.register_cheat("Keybinds", {
		category = "Misc",
		func = show_keybinds,
		description = "Show keybindings reference",
	})
end

core.register_on_formspec_input(function(formname, fields)
	if formname == "help:keybinds" and fields.__close then
		return
	end
end)
