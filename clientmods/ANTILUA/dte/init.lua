dte = {
	modstorage = core.get_mod_storage("dte"),
	modpath = core.get_modpath(core.get_current_modname())
}
if core.settings:get("dte_width") == nil then core.settings:set("dte_width", "15") end
if core.settings:get("dte_height") == nil then core.settings:set("dte_height", "10") end
local data = {  -- window size
	width = tonumber(core.settings:get("dte_width")) or 15,
	height = tonumber(core.settings:get("dte_height")) or 10,
}
local F = core.formspec_escape  -- shorten the function

local function create_tabs(selected)
	return "tabheader[0,0;_option_tabs_;" ..
	"  LUA EDITOR   , LUA CONSOLE  ,	 FILES	 ,	STARTUP	  ,	 MODS   ;"..selected..";;]"
end

local function copy_table(t)
	return table.copy(t)
end


----------
-- LOAD AND DEFINE STUFF  - global stuff is accessible from the UI
----------

local split = function (str, splitter)  -- a function to split a string into a list. "\" before the splitter makes it ignore it (usefull for minetests formspecs)
	local result = {""}
	for i=1, str:len() do
		local char = string.sub(str, i, i)
		if char == splitter and string.sub(str, i-1, i-1) ~= "\\" then
			table.insert(result, "")
		else
			result[#result] = result[#result]..char
		end
	end
	return result
end


dofile(dte.modpath .. "/syntax.lua")

local output = {}  -- the output for errors, prints, etc

local saved_file = dte.modstorage:get_string("_lua_saved")  -- remember what file is currently being edited
if saved_file == "" then
	saved_file = false  -- if the file had no save name (it was still saved)
end


local lua_startup = split(dte.modstorage:get_string("_lua_startup"), ",")  -- the list of scripts to run at startup

local lua_files = split(dte.modstorage:get_string("_lua_files_list"), ",")  -- the list of names of all saved files


local selected_file = 0

-- Mod browser state
local mod_list = {}           -- list of {name, path, files[{name, path}]}
local mod_selected = false    -- currently selected mod name
local mod_file_selected = false  -- currently selected mod file path for editing
local mod_file_content = ""   -- cached content of the file being edited

----------
-- FILE READING AND SAVING
----------

local function load_lua()  -- returns the contents of the file currently being edited
	if saved_file == false then
		return dte.modstorage:get_string("_lua_temp")  -- unsaved files are remembered  (get saved on UI reloads - when clicking on buttons)
	else
		return dte.modstorage:get_string("_lua_file_"..saved_file)
	end
end

local function save_lua(code)  -- save a file
	if saved_file == false then
		dte.modstorage:set_string("_lua_temp", code)
	else
		dte.modstorage:set_string("_lua_file_"..saved_file, code)
	end
end

----------
-- FUNCTIONS FOR UI
----------

local _builtin_print = print

function dte_print(...)  -- output into the UI (doesn't refresh until the script has ended)
	local params = {...}
	if #params == 1 then
		local str = params[1]
		if type(str) ~= "string" then
			str = dump(str)
		end
		table.insert(output, "")
		for i=1, str:len() do
			local char = string.sub(str, i, i)
			if char == "\n" then
				table.insert(output, "")  -- split multiple lines over multiple lines. without this, text with line breaks would not display properly
			else
				output[#output] = output[#output]..char
			end
		end
	else
		for i, v in pairs(params) do
			dte_print(v)
		end
	end
end

function safe(func)  -- run a function without crashing the game. All errors are displayed in the UI.
	local f = function(...)  -- This can be used for functions being registered with minetest, like "core.register_chat_command()"
		local status, out = pcall(func, ...)
		if status then
			return out
		else
			table.insert(output, "#ff0000Error:  "..out)
			core.debug("Error (func):  "..out)
			return nil
		end
	end
	return f
end


----------
-- CODE EXECUTION
----------

local function run(code, name)  -- run a script
	if name == nil then
		name = saved_file
	end
	print = dte_print  -- temporarily redirect print to DTE output
	local func, load_err = loadstring(code)
	if not func then
		-- Syntax error during loading
		if saved_file == false then
			table.insert(output, "#ff0000Syntax Error:  "..load_err)
			core.log("Error (unsaved):  "..load_err)
		else
			table.insert(output, "#ff0000"..name..": Syntax Error:  "..load_err)
			core.log("Error ("..name.."):  "..load_err)
		end
	else
		local status, err = pcall(func)
		if status then
			if saved_file == false then
				table.insert(output, "#00ff00finished")
			else
				table.insert(output, "#00ff00"..name..":  finished")
			end
		else
			if saved_file == false then
				table.insert(output, "#ff0000Error:  "..err)
				core.log("Error (unsaved):  "..err)
			else
				table.insert(output, "#ff0000"..name..": Error:  "..err)
				core.log("Error ("..name.."):  "..err)
			end
		end
	end
	print = _builtin_print  -- restore original print
end

local function on_startup()  -- ran on startup. Runs all scripts registered for startup
	for i, v in pairs(lua_startup) do
		if v ~= "" then
			run(dte.modstorage:get_string("_lua_file_"..v, v), v)  -- errors still get displayed in the UI
		end
	end
end

on_startup()

if core.register_cheat then
	core.register_cheat("Run DTE", { category = "DevTools",
		description = "Run Lua code via DTE",
		func = function() run(load_lua()) end })
end


----------
-- LUA CONSOLE (REPL)
----------

local console_output = {}
local console_history = {}
local console_history_idx = 0

local function console_form()
	local output_str = ""
	for i, v in ipairs(console_output) do
		if i ~= 1 then output_str = output_str .. "," end
		output_str = output_str .. F(v)
	end

	local form = ""..
	"size["..data.width..","..data.height.."]" ..
	"textlist[0,0;"..data.width-0.2 ..","..data.height-2.5 ..";console_out;"..output_str..";".. #console_output .."]" ..
	"field[0,"..data.height-2.2 ..";"..data.width-4 ..",1;console_expr;Lua expression;]" ..
	"field_close_on_enter[console_expr;true]" ..
	"button["..data.width-3.5 ..","..data.height-2.5 ..";2,0.8;console_run;RUN]" ..
	"button["..data.width-1.5 ..","..data.height-2.5 ..";1,0.8;console_clear;CLEAR]" ..
	"" .. create_tabs(2)
	return form
end

local function run_console(expr)
	if expr == "" then return end
	table.insert(console_history, expr)
	console_history_idx = #console_history + 1
	table.insert(console_output, "#888888> " .. expr)
	local func, load_err = loadstring("return " .. expr)
	if not func then
		-- Try as statement (not expression)
		func, load_err = loadstring(expr)
	end
	if not func then
		table.insert(console_output, "#ff4444" .. load_err)
	else
		local ok, result = pcall(func)
		if ok then
			if result ~= nil then
				table.insert(console_output, "#00cc00" .. dump(result))
			else
				table.insert(console_output, "#666666nil")
			end
		else
			table.insert(console_output, "#ff4444" .. result)
		end
	end
	core.show_formspec("lua:console", console_form())
end


----------
-- FORM DEFINITIONS
----------


local function startup_form()  -- the formspec for adding or removing files for startup
	local startup_str = ""
	for i, v in pairs(lua_startup) do
		if i ~= 1 then startup_str = startup_str.."," end
		startup_str = startup_str .. F(v)
	end
	local files_str = ""
	for i, v in pairs(lua_files) do
		if i ~= 1 then files_str = files_str.."," end
		files_str = files_str .. F(v)
	end

	local form = ""..
	"size["..data.width..","..data.height.."]" ..
	"label[0,0.1;Startup Items:]"..
	"label["..data.width/2 ..",0.1;File List:]"..
	"textlist[0,0.5;"..data.width/2-0.1 ..","..data.height-1 ..";starts;"..startup_str.."]"..
	"textlist["..data.width/2 ..",0.5;"..data.width/2-0.1 ..","..data.height-1 ..";chooser;"..files_str.."]"..
	"label[0," .. data.height-0.3 .. ";double click items to add or remove from startup]"..

	"" .. create_tabs(4)
	return form
end


local function lua_editor()  -- the main formspec for editing

	local output_str = ""  --  convert the output to a string
	for i, v in pairs(output) do
		if output_str:len() > 0 then output_str = output_str .. "," end
		output_str = output_str .. F(v)
	end

	local lua_files_item_str = table.concat(lua_files, ",")
	local idx = table.indexof(lua_files, saved_file)

	local code = F(load_lua())

	-- create the form
	local editor_widget
	if core.features.codeedit_formspec then
		editor_widget = "codeedit[0.3,0.1;"..data.width ..","..data.height-3
			..";editor;Lua editor;"..code.."]"
	else
		editor_widget = "textarea[0.3,0.1;"..data.width ..","..data.height-3
			..";editor;Lua editor;"..code.."]"
	end
	local form = ""..
	"size["..data.width..","..data.height.."]" ..
	"style[editor;bgcolor=#80000000]" ..
	editor_widget ..
	"button[0," .. data.height-3.5 .. ";1,0;run;RUN]"..
	"button[1," .. data.height-3.5 .. ";1,0;clear;CLEAR]"..
	"button[2," .. data.height-3.5 .. ";1,0;save;SAVE]"..
	"button[3.1," .. data.height-3.5 .. ";1,0;load_ext;LOAD]"..
	"dropdown[5.3,"..data.height-3.8 ..";3;lua_select;"..lua_files_item_str..";"..idx.."]" ..
	"textlist[0,"..data.height-3 ..";"..data.width-0.2 ..","..data.height-7 ..";output;"..output_str..";".. #output .."]"..
	"" .. create_tabs(1)
	return form
end


-- Mod reload: remove all registered callbacks from a given mod
local function cleanup_mod(modname)
	local cleaned = 0
	for k, v in pairs(core) do
		if type(v) == "table" and k:match("^registered_on_") then
			for i = #v, 1, -1 do
				local origin = core.callback_origins[v[i]]
				if origin and origin.mod == modname then
					core.callback_origins[v[i]] = nil
					table.remove(v, i)
					cleaned = cleaned + 1
				end
			end
		end
	end
	-- Remove cheat definitions from that mod
	if core.registered_cheats then
		for cat, cheats in pairs(core.registered_cheats) do
			if type(cheats) == "table" then
				for i = #cheats, 1, -1 do
					if cheats[i] and cheats[i].origin_mod == modname then
						table.remove(cheats, i)
					end
				end
			end
		end
	end
	return cleaned
end

-- Scan mod directories and build the mod list
local function scan_mods()
	mod_list = {}
	local seen = {}

	-- Derive share path from builtin path
	local builtin_path = core.get_builtin_path()
	local share_root = builtin_path:match("^(.*/)builtin/")
	local paths = {}
	if share_root then
		table.insert(paths, share_root .. "clientmods")
	end
	-- Derive user path from DTE mod's own location
	local dte_path = core.get_modpath_real("dte")
	if dte_path then
		local user_root = dte_path:match("^(.*/)ANTILUA/")
		if user_root then
			table.insert(paths, user_root:sub(1, -2)) -- remove trailing slash
		else
			-- Fallback: DTE might be in user mods directly
			local parent = dte_path:match("^(.*/)")
			if parent then
				table.insert(paths, parent:sub(1, -2))
			end
		end
	end

	for _, base in ipairs(paths) do
		local ok, entries = pcall(core.get_dir_list, base, true)
		if ok and entries then
			for _, modname in ipairs(entries) do
				if not seen[modname] then
					seen[modname] = true
					local modpath = base .. "/" .. modname
					local ok2, files = pcall(core.get_dir_list, modpath, false)
					if ok2 and files then
						local file_list = {}
						for _, f in ipairs(files) do
							if f:match("%.lua$") then
								table.insert(file_list, {
									name = f,
									path = modpath .. "/" .. f,
								})
							end
						end
						table.insert(mod_list, {
							name = modname,
							path = modpath,
							files = file_list,
						})
					end
				end
			end
		end
	end
	table.sort(mod_list, function(a, b) return a.name < b.name end)
end

-- Show the mod file editor formspec
local function mod_editor()
	local code = F(mod_file_content or "")
	local form = "" ..
		"size["..data.width..","..data.height.."]" ..
		"label[0,0;Editing: " .. F(mod_file_selected or "") .. "]" ..
		"codeedit[0.3,0.5;"..data.width..","..(data.height-2)
			..";mod_editor_edit;Mod file;"..code.."]" ..
		"button[0,"..(data.height-1.5)..";1.5,0.8;mod_editor_save;SAVE]" ..
		"button[1.6,"..(data.height-1.5)..";2,0.8;mod_editor_savereload;SAVE & RELOAD]" ..
		"button[3.7,"..(data.height-1.5)..";1.5,0.8;mod_editor_back;BACK]" ..
		"" .. create_tabs(5)
	return form
end

-- Show the mod browser formspec
local function mod_browser()
	scan_mods()
	local mod_str = ""
	for i, mod in ipairs(mod_list) do
		if i > 1 then mod_str = mod_str .. "," end
		mod_str = mod_str .. F(mod.name)
	end
	local file_str = ""
	local files = {}
	if mod_selected then
		for _, mod in ipairs(mod_list) do
			if mod.name == mod_selected then
				files = mod.files
				break
			end
		end
		for i, f in ipairs(files) do
			if i > 1 then file_str = file_str .. "," end
			file_str = file_str .. F(f.name)
		end
	end

	local form = "" ..
		"size["..data.width..","..data.height.."]" ..
		"label[0,0;MODS]" ..
		"textlist[0,0.4;"..(data.width/2-0.1)..","..(data.height-1.3)..";mod_list;"..mod_str.."]" ..
		"textlist["..(data.width/2)..",0.4;"..(data.width/2-0.1)..","..(data.height-1.3)..";mod_files;"..file_str.."]" ..
		"label[0,"..(data.height-0.9)..";Double-click a file to edit it]" ..
		"" .. create_tabs(5)
	return form
end

local function file_viewer()  -- created with the formspec editor!
	local lua_files_item_str = ""
	for i, item in pairs(lua_files) do
		if i ~= 1 then lua_files_item_str = lua_files_item_str.."," end
		lua_files_item_str = lua_files_item_str .. F(item)
	end

	local form = "" ..
	"size["..data.width..","..data.height.."]" ..
	"textlist[0,0.2;"..data.width-0.1 ..","..data.height- 1.8 ..";lua_select;"..lua_files_item_str.."]" ..
	"label[0,0;LUA FILES]" ..
	"field[0.1,"..data.height- 0.2 ..";3,1;new_lua;NEW;]" ..
	"field_close_on_enter[new_lua;false]" ..
	"button[2.6,"..data.height- 0.5 ..";0.5,1;add_lua;+]" ..
	"label[3.2,"..data.height- 0.8 ..";Double click a file to open it]" ..
	"button[3.1,"..data.height- 0.5 ..";1.1,1;del_lua;DELETE]" ..
	"" .. create_tabs(3)

	return form
end


----------
-- FUNCTIONALITY
----------

core.register_on_formspec_input(function(formname, fields)

	-- EDITING PAGE
	----------
	if formname == "lua:editor" then
		if fields.run then  --[RUN] button
			save_lua(fields.editor)
			run(fields.editor)

			core.show_formspec("lua:editor", lua_editor())

		elseif fields.save then  --[SAVE] button
			if saved_file == false then
				dte.modstorage:set_string("_lua_temp", fields.editor)
			else
				dte.modstorage:set_string("_lua_file_"..saved_file, fields.editor)
			end

		elseif fields.clear then  --[CLEAR] button
			output = {}
			save_lua(fields.editor)
			core.show_formspec("lua:editor", lua_editor())
		elseif fields.preview then  --[PREVIEW] button - syntax colorize
			save_lua(fields.editor)
			local code = load_lua()
			local colorized = colorize(code)
			output = {}
			for _, entry in ipairs(colorized) do
				table.insert(output, entry.color .. entry.line)
			end
			core.show_formspec("lua:editor", lua_editor())
		elseif fields.load_ext then  --[LOAD] button - load external file
			dte._pending_load = true
			core.show_formspec("lua:load_ext",
				"size[8,2]" ..
				"field[0.3,0.3;7.5,1;filepath;File path (relative to worldmods/ or clientmods/):;]" ..
				"button[0,1;3,1;load_ok;LOAD]" ..
				"button[3,1;3,1;load_cancel;CANCEL]")
		elseif fields.lua_select then
			if table.indexof(lua_files, fields.lua_select) ~= -1 then
				saved_file = fields.lua_select
				dte.modstorage:set_string("_lua_saved", fields.lua_select)
				core.show_formspec("lua:editor", lua_editor())
			end
		end

	-- LOAD EXTERNAL FILE
	----------
	elseif formname == "lua:load_ext" then
		if fields.load_ok and fields.filepath and fields.filepath ~= "" then
			local ok, content = pcall(core.read_file, fields.filepath)
			if ok and content then
				save_lua(fields.editor)
				saved_file = false
				dte.modstorage:set_string("_lua_saved", "")
				dte.modstorage:set_string("_lua_temp", content)
				table.insert(output, "#00ff00Loaded: " .. fields.filepath)
				core.show_formspec("lua:editor", lua_editor())
			else
				table.insert(output, "#ff0000Failed to load: " .. fields.filepath)
				core.show_formspec("lua:editor", lua_editor())
			end
		elseif fields.load_cancel then
			core.show_formspec("lua:editor", lua_editor())
		end

	-- LUA CONSOLE
	----------
	elseif formname == "lua:console" then
		if fields.console_run or fields.key_enter_field == "console_expr" then
			local expr = fields.console_expr or ""
			run_console(expr)
		elseif fields.console_clear then
			console_output = {}
			core.show_formspec("lua:console", console_form())
		end

	-- STARTUP EDITOR
	----------
	elseif formname == "lua:startup" then  -- double click a file to remove it from the list
		if fields.starts then
			local select = {["type"] = string.sub(fields.starts, 1, 3), ["row"] = tonumber(string.sub(fields.starts, 5, 5))}
			if select.type == "DCL" then
				table.remove(lua_startup, select.row)
				local startup_str = ""
				for i, v in pairs(lua_startup) do
					if v ~= "" then
						startup_str = startup_str..v..","
					end
				end
				dte.modstorage:set_string("_lua_startup", startup_str)
				core.show_formspec("lua:startup", startup_form())
			end

		elseif fields.chooser then  -- double click a file to add it to the list
			local select = {["type"] = string.sub(fields.chooser, 1, 3), ["row"] = tonumber(string.sub(fields.chooser, 5, 5))}
			if select.type == "DCL" then
				table.insert(lua_startup, lua_files[select.row])
				local startup_str = ""
				for i, v in pairs(lua_startup) do
					if v ~= "" then
						startup_str = startup_str..v..","
					end
				end
				dte.modstorage:set_string("_lua_startup", startup_str)
				core.show_formspec("lua:startup", startup_form())
			end
		end
	end
end)

----------
-- UI FUNCTIONALITY
----------

core.register_on_formspec_input(function(formname, fields)
		-- FILE VIEWER
	----------
	if formname == "files:viewer" then
		if fields.del_lua then
			local name = lua_files[selected_file]
			table.remove(lua_files, selected_file)
			local files_str = ""
			for i, v in pairs(lua_files) do
				if v ~= "" then
					files_str = files_str..v..","  -- remove the file from the list
				end
			end

			if name == saved_file then  -- clear the editing area if the file was loaded
				saved_file = false
				dte.modstorage:set_string("_lua_saved", "")
				save_lua("")
			end

			dte.modstorage:set_string("_lua_files_list", files_str)
			core.show_formspec("files:viewer", file_viewer())

		elseif fields.lua_select then  -- click on a file to select it, double click to open it
			local index = tonumber(string.sub(fields.lua_select, 5))
			if string.sub(fields.lua_select, 1, 3) == "DCL" then
				saved_file = lua_files[index]

				dte.modstorage:set_string("_lua_saved", saved_file)
				core.show_formspec("lua:editor", lua_editor())
			else
				selected_file = index
				core.show_formspec("files:viewer", file_viewer())
			end

		elseif fields.key_enter_field == "new_lua" or fields.add_lua then
			local exist = false
			for i, v in pairs(lua_files) do
				if v == fields.new_lua then
					exist = true
					selected_files[1] = i
				end
			end
			if not exist then
				table.insert(lua_files, fields.new_lua)
				selected_file = #lua_files

				files_str = ""
				for i, v in pairs(lua_files) do
					if v ~= "" then
						files_str = files_str..v..","
					end
				end
				dte.modstorage:set_string("_lua_files_list", files_str)
				saved_file = fields.new_lua
				core.show_formspec("lua:editor", lua_editor())
			end
		end
	end

	if fields._option_tabs_ then
		if fields._option_tabs_ == "1" then
			core.show_formspec("lua:editor", lua_editor())
		elseif fields._option_tabs_ == "2" then
			core.show_formspec("lua:console", console_form())
		elseif fields._option_tabs_ == "3" then
			core.show_formspec("files:viewer", file_viewer())
		elseif fields._option_tabs_ == "4" then
			core.show_formspec("lua:startup", startup_form())
		elseif fields._option_tabs_ == "5" then
			core.show_formspec("lua:mods", mod_browser())
		end

	end

	-- MOD BROWSER
	if formname == "lua:mods" then
		if fields.mod_list then
			local ev = core.explode_textlist_event(fields.mod_list)
			if ev.type == "DCL" then
				mod_selected = mod_list[ev.row] and mod_list[ev.row].name
				core.show_formspec("lua:mods", mod_browser())
			end
		elseif fields.mod_files then
			local ev = core.explode_textlist_event(fields.mod_files)
			if ev.type == "DCL" then
				local files = {}
				for _, mod in ipairs(mod_list) do
					if mod.name == mod_selected then
						files = mod.files
						break
					end
				end
				if files[ev.row] then
					mod_file_selected = files[ev.row].path
					local ok, content = pcall(core.read_file, mod_file_selected)
					mod_file_content = ok and content or ""
					core.show_formspec("lua:mod_editor", mod_editor())
				end
			end
		end
	end

	-- MOD EDITOR
	if formname == "lua:mod_editor" then
		if fields.mod_editor_back then
			core.show_formspec("lua:mods", mod_browser())
		elseif fields.mod_editor_save or fields.mod_editor_savereload then
			if mod_file_selected then
				local ok, err = pcall(core.write_file, mod_file_selected, fields.mod_editor_edit)
				if ok then
					mod_file_content = fields.mod_editor_edit
					table.insert(output, "#00ff00Saved: " .. mod_file_selected)
				else
					table.insert(output, "#ff0000Failed to save: " .. tostring(err))
				end
			end
			if fields.mod_editor_savereload and mod_selected then
				if core.features.codeedit_formspec and core.reload_mod then
					local n = cleanup_mod(mod_selected)
					table.insert(output, "#888888Cleaned " .. n .. " callbacks from " .. mod_selected)
					local ok, err = pcall(core.reload_mod, mod_selected)
					if ok then
						table.insert(output, "#00ff00Reloaded: " .. mod_selected)
					else
						table.insert(output, "#ff0000Reload failed: " .. tostring(err))
					end
				else
					table.insert(output, "#ff8800reload_mod not available on this client")
				end
				core.show_formspec("lua:mods", mod_browser())
			else
				core.show_formspec("lua:mod_editor", mod_editor())
			end
		end
	end

end)
----------
-- REGISTER COMMAND
----------
core.register_chatcommand("dte", {  -- register the chat command
	description = core.gettext("open a lua IDE"),
	func = function(parameter)
		core.show_formspec("lua:editor", lua_editor())
	end,
})

core.register_chatcommand("dte_load", {
	params = "<filepath>",
	description = "Load and execute an external Lua file",
	func = function(param)
		if not param or param == "" then
			return false, "Usage: .dte_load <filepath>"
		end
		local ok, content = pcall(core.read_file, param)
		if not ok or not content then
			return false, "Failed to read: " .. param
		end
		run(content, param)
		return true, "Executed: " .. param
	end,
})
