nlist = {}
local storage = core.get_mod_storage("nlist")
local INTERNAL_PREFIX = "__"
local MODE_NAMES = { [1] = "add", [2] = "remove", [3] = "toggle" }

local sl = storage:get_string(INTERNAL_PREFIX .. "selected")
if sl == "" then sl = "default" end
local mode = tonumber(storage:get_string(INTERNAL_PREFIX .. "mode")) or 1 -- 1:add, 2:remove, 3:toggle
local nled_hud
local nled_hud_y = 0
local nlist_last_content = "" -- cache for HUD update optimization
nlist.selected = sl

-- Migrate existing xray_nodes setting to nlist
local existing = core.settings:get("xray_nodes")
if existing and existing ~= "" and storage:get_string("xray") == "" then
	storage:set_string("xray", existing)
end

local function persist_mode()
	storage:set_string(INTERNAL_PREFIX .. "mode", tostring(mode))
end

local function persist_selected()
	storage:set_string(INTERNAL_PREFIX .. "selected", sl)
end

local function mode_name()
	return MODE_NAMES[mode] or "add"
end

local function trim(node)
	if type(node) ~= "string" then return "" end
	return node:gsub("^%s+", ""):gsub("%s+$", "")
end

function nlist.set_mode(newmode)
	if MODE_NAMES[newmode] then
		mode = newmode
		persist_mode()
	end
	return mode
end

function nlist.add(list, node, silent)
	node = trim(node)
	if node == "" then return false end
	local tb = nlist.get(list)
	if table.indexof(tb, node) ~= -1 then return false end
	table.insert(tb, node)
	nlist.set(list, tb)
	if not silent then
		ws.notify(node .. " added to " .. list, ws.NOTIFY_INFO, {toast = false})
	end
	return true
end

function nlist.remove(list, node, silent)
	node = trim(node)
	if node == "" then return false end
	local tb = nlist.get(list)
	local ix = table.indexof(tb, node)
	if ix == -1 then return false end
	table.remove(tb, ix)
	nlist.set(list, tb)
	if not silent then
		ws.notify(node .. " removed from " .. list, ws.NOTIFY_INFO, {toast = false})
	end
	return true
end

function nlist.toggle(list, node, silent)
	node = trim(node)
	if node == "" then return false end
	local tb = nlist.get(list)
	if table.indexof(tb, node) ~= -1 then
		return nlist.remove(list, node, silent)
	end
	return nlist.add(list, node, silent)
end

function nlist.set(list,tb)
	local str=table.concat(tb,",")
	storage:set_string(list,str)
	if list == "xray" then
		core.settings:set("xray_nodes", str)
	end
	return true
end

function nlist.get(list)
	local str=storage:get_string(list)
	return str ~= "" and str:split(',') or {}
end

function nlist.clear(list)
	storage:set_string(list,"")
	return true
end

--- Alias kept for legacy callers (delete and clear were byte-identical).
nlist.delete = nlist.clear

function nlist.select(list)
	sl = list
	nlist.selected = list
	persist_selected()
end

function nlist.get_lists()
	local ret = {}
	for name, _ in pairs(storage:to_table().fields) do
		if name:sub(1, #INTERNAL_PREFIX) ~= INTERNAL_PREFIX then
			table.insert(ret, name)
		end
	end
	table.sort(ret)
	return ret
end

function nlist.count(list)
	return #nlist.get(list)
end

--- Union of `src` into `dst`; never clobbers existing entries.
-- @return number of new entries added
function nlist.merge(dst, src)
	dst, src = tostring(dst), tostring(src)
	if dst == src then return 0 end
	local src_list = nlist.get(src)
	local dst_list = nlist.get(dst)
	local added = 0
	for _, node in ipairs(src_list) do
		if table.indexof(dst_list, node) == -1 then
			table.insert(dst_list, node)
			added = added + 1
		end
	end
	if added > 0 then
		nlist.set(dst, dst_list)
	end
	return added
end

--- Friendly display name for an entry: item description when known, raw name otherwise.
function nlist.display(name)
	local def = core.get_item_def(name)
	if def and def.description and def.description ~= "" then
		return def.description
	end
	return name
end

function nlist.rename(oldname, newname)
	oldname, newname = tostring(oldname), tostring(newname)
	local list = nlist.get(oldname)
	if not list or #list == 0 then return false end
	nlist.set(newname, list)
	nlist.clear(oldname)
	return true
end

function nlist.copy(oldname, newname)
	oldname, newname = tostring(oldname), tostring(newname)
	local list = nlist.get(oldname)
	local newlist = nlist.get(newname)
	if #newlist > 0 then
		nlist.rename(newname,newname.."_backup")
	end
	if #list < 1 or not nlist.set(newname,list) then return false end
	return true
end

function nlist.random(list)
	local tb = nlist.get(list)
	if #tb == 0 then return end
	return tb[math.random(#tb)]
end

local HUD_MODE_COLORS = { [1] = 0x00ff00, [2] = 0xff4444, [3] = 0xffaa00 } -- add:green, remove:red, toggle:orange
local HUD_MAX_ENTRIES = 15

local function format_list_text(list, hlp)
	local entries = nlist.get(list)
	local shown = {}
	local n = #entries
	for i = 1, math.min(n, HUD_MAX_ENTRIES) do
		table.insert(shown, entries[i])
	end
	local txt = list .. " [" .. mode_name() .. "] (" .. n .. ")"
		.. "\n --\n" .. table.concat(shown, "\n")
	if n > HUD_MAX_ENTRIES then
		txt = txt .. "\n… " .. (n - HUD_MAX_ENTRIES) .. " more"
	end
	if hlp then
		txt = "Nodelist edit mode\n.nla/.nlr/.nlt to switch\npunch node to " .. mode_name() .. "\n.nlc to clear\n\n" .. txt
	end
	return txt
end

function nlist.show_list(list, hlp)
	if not list then return end
	local txt = format_list_text(list, hlp)
	if txt ~= nlist_last_content then
		nlist_last_content = txt
		if nled_hud then
			core.localplayer:hud_change(nled_hud, 'text', "List: " .. txt)
			core.localplayer:hud_change(nled_hud, 'number', HUD_MODE_COLORS[mode] or 0x00ff00)
		else
			nlist.set_nled_hud(txt)
		end
	end
	-- Keep the shared top-right slot in sync with entry count / neighbours
	if nled_hud then
		local lines = select(2, ("List: " .. txt):gsub("\n", "")) + 1
		local slot = ws.hud_layout.reserve("nlist", "top_right", lines)
		if slot.y ~= nled_hud_y then
			nled_hud_y = slot.y
			core.localplayer:hud_change(nled_hud, 'offset', {x = 0, y = slot.y})
		end
	end
end

function nlist.hide()
	if not core.localplayer then return end
	if nled_hud then core.localplayer:hud_remove(nled_hud) nled_hud=nil end
	ws.hud_layout.release("nlist")
end

function nlist.set_nled_hud(ttext)
	if not core.localplayer then return end
	if type(ttext) ~= "string" then return end
	local dtext = "List: " .. ttext
	local lines = select(2, dtext:gsub("\n", "")) + 1
	local slot = ws.hud_layout.reserve("nlist", "top_right", lines)
	if nled_hud then
		core.localplayer:hud_change(nled_hud, 'text', dtext)
		core.localplayer:hud_change(nled_hud, 'number', HUD_MODE_COLORS[mode] or 0x00ff00)
		if slot.y ~= nled_hud_y then
			nled_hud_y = slot.y
			core.localplayer:hud_change(nled_hud, 'offset', {x = 0, y = slot.y})
		end
	else
		nled_hud_y = slot.y
		nled_hud = core.localplayer:hud_add({
			type = 'text',
			name = "Nodelist",
			text = dtext,
			number = HUD_MODE_COLORS[mode] or 0x00ff00,
			direction = 0,
			position = {x = 0.8, y = 0},
			alignment = {x = 1, y = 1},
			offset = {x = 0, y = slot.y},
		})
	end
	return true
end

core.register_on_punchnode(function(p, n)
	if not core.settings:get_bool('nlist_edmode') then return end
	if mode == 1 then
		if not nlist.add(nlist.selected, n.name) then
			ws.notify(n.name .. " already in " .. nlist.selected, ws.NOTIFY_INFO, {chat = false})
		end
	elseif mode == 2 then
		if not nlist.remove(nlist.selected, n.name) then
			ws.notify(n.name .. " not in " .. nlist.selected, ws.NOTIFY_INFO, {chat = false})
		end
	elseif mode == 3 then
		nlist.toggle(nlist.selected, n.name)
	end
end)

-- ---------------------------------------------------------------
-- Editor formspec. State is kept in module vars so reopens preserve
-- the filter, selection, typed fields and confirm flow.
-- ---------------------------------------------------------------
local fs_filter = ""
local fs_panel = "list" -- "list" | "pick"
local fs_confirm = nil -- nil | "delete" | "clear"
local fs_sel = nil -- highlighted entry index
local fs_item_input = ""
local fs_rename_input = ""

local FORM_W = 12.5
local FORM_H = 11.5
local ROW_H = 1.05
local MAX_ROWS = 300
local PICK_FILTER_HINT = 400

local function mode_next()
	return (mode % 3) + 1
end

local function matches_filter(name, filter)
	if filter == "" then return true end
	return ws.fuzzy_match(name, filter) or ws.fuzzy_match(nlist.display(name), filter)
end

local function list_entries()
	local all = nlist.get(sl)
	if fs_filter == "" then return all end
	local out = {}
	for _, name in ipairs(all) do
		if matches_filter(name, fs_filter) then
			table.insert(out, name)
		end
	end
	return out
end

local function pick_entries()
	local names = core.get_item_names and core.get_item_names() or {}
	if fs_filter == "" then return names end
	local out = {}
	for _, name in ipairs(names) do
		if matches_filter(name, fs_filter) then
			table.insert(out, name)
		end
	end
	return out
end

local function capped(items)
	if #items <= MAX_ROWS then return items, 0 end
	local out = {}
	for i = 1, MAX_ROWS do
		out[i] = items[i]
	end
	return out, #items - MAX_ROWS
end

local function scroll_bottom_note(scroll_top, scroll_h)
	return scroll_top + scroll_h + 0.15
end

local function entry_row(x, y, id, name, opts)
	local af = core.al_formspec
	opts = opts or {}
	local known = core.get_item_def(name) ~= nil
	local label = known and (nlist.display(name) .. " (" .. name .. ")") or name
	if opts.prefix then label = opts.prefix .. label end
	local bg = opts.highlight and af.box(x, y, 11.3, ROW_H - 0.05, "#333333") or ""
	local img = known
		and af.item_image(x + 0.1, y + 0.05, 0.85, 0.85, name)
		or af.label(x + 0.4, y + 0.28, "·")
	local btn = af.button(x + 1.15, y, 10.15, ROW_H - 0.05, id, label)
	return { bg, img, btn, af.tooltip(id, opts.tooltip or name) }
end

ws.rg('NlEdMode', { category = 'Misc', setting = 'nlist_edmode',
	description = "Edit node list",
	on_step = function(self) nlist.show_list(sl, true) end,
	on_start = function(self) end,
	on_stop = function(self) nlist.hide() end,
	get_formspec = function(setting)
		local af = core.al_formspec
		local lists = nlist.get_lists()
		if not table.indexof(lists, sl) then
			table.insert(lists, sl)
		end
		table.sort(lists)

		local sel_idx = 1
		for i, name in ipairs(lists) do
			if name == sl then sel_idx = i; break end
		end

		local sb = af.cheat_form_begin("size[" .. FORM_W .. "," .. FORM_H .. "]")
		sb:add(af.label(0.3, 0, af.color(af.ACCENT,
			"List: " .. sl .. " [" .. mode_name() .. "] (" .. nlist.count(sl) .. " entries)")))

		-- List management
		sb:add(
			af.dropdown(0.3, 0.7, 4.8, "list_select", lists, sel_idx),
			af.field(5.3, 0.7, 2.8, 0.8, "rename_input", "Name", fs_rename_input),
			af.button(8.3, 0.7, 1.5, 0.8, "btn_newlist", "+ New"),
			af.button(9.9, 0.7, 1.5, 0.8, "btn_rename", "Rename")
		)

		-- Actions
		sb:add(
			af.button(0.3, 1.7, 2.6, 0.8, "btn_mode", "Mode: " .. mode_name()),
			af.button(3.1, 1.7, 2.0, 0.8, "btn_wielded", "Wielded"),
			af.button(5.3, 1.7, 2.0, 0.8, "btn_pointed", "Pointed"),
			af.button(7.5, 1.7, 2.2, 0.8, "btn_rmlist", "Delete list"),
			af.button(9.9, 1.7, 1.9, 0.8, "btn_clear", "Clear")
		)

		local search_y = 2.7
		local list_top = 3.6
		if fs_confirm then
			local msg = fs_confirm == "delete"
				and ("Delete list \"" .. sl .. "\"? This cannot be undone.")
				or ("Clear list \"" .. sl .. "\"? This cannot be undone.")
			sb:add(
				af.label(0.3, 2.7, msg),
				af.button(0.3, 3.4, 2, 0.8, "btn_confirm_yes", "Yes"),
				af.button(2.5, 3.4, 2, 0.8, "btn_confirm_no", "No")
			)
			search_y = 4.3
			list_top = 5.2
		end

		-- Search + panel switch
		sb:add(
			af.searchbar(0.3, search_y, 8.0, "fs_search",
				{ default = fs_filter, placeholder = "Filter:", button_width = 1.4 }),
			af.button(8.8, search_y, 1.5, 0.8, "btn_panel_list", "List"),
			af.button(10.4, search_y, 1.5, 0.8, "btn_panel_pick", "Pick")
		)

		local scroll_top = list_top + 0.4
		local scroll_h = (FORM_H - 1.7) - scroll_top
		local sbname = "nlist_scroll"
		local emit_scroll = true

		if fs_panel == "list" then
			local entries = list_entries()
			local shown, hidden = capped(entries)
			sb:add(af.label(0.3, list_top, "Entries (" .. #entries .. "):"))
			sb:add(af.scroll_container(0.3, scroll_top, 11.3, scroll_h, sbname, "vertical",
				{ factor = 0.1, padding = 0 }))
			for i, name in ipairs(shown) do
				sb:add(entry_row(0.3, (i - 1) * ROW_H, "row_" .. i, name, {
					highlight = fs_sel == i,
					tooltip = "Click to " .. mode_name() .. " — " .. name,
				}))
			end
			sb:add(af.scroll_container_end())
			if hidden > 0 then
				sb:add(af.label(0.3, scroll_bottom_note(scroll_top, scroll_h),
					"Showing first " .. MAX_ROWS .. " of " .. #entries .. " — refine the filter"))
			end
		else
			local items = pick_entries()
			if fs_filter == "" and #items > PICK_FILTER_HINT then
				emit_scroll = false
				sb:add(af.label(0.3, list_top, #items .. " registered items — type in the filter to browse"))
			else
				local shown, hidden = capped(items)
				local in_list = {}
				for _, name in ipairs(nlist.get(sl)) do in_list[name] = true end
				sb:add(af.label(0.3, list_top, "Registered items (" .. #items .. "):"))
				sb:add(af.scroll_container(0.3, scroll_top, 11.3, scroll_h, sbname, "vertical",
					{ factor = 0.1, padding = 0 }))
				for i, name in ipairs(shown) do
					sb:add(entry_row(0.3, (i - 1) * ROW_H, "pick_" .. i, name, {
						prefix = in_list[name] and "[✓] " or "",
						tooltip = (in_list[name] and "In list — click to remove — " or "Click to add — ") .. name,
					}))
				end
				sb:add(af.scroll_container_end())
				if hidden > 0 then
					sb:add(af.label(0.3, scroll_bottom_note(scroll_top, scroll_h),
						"Showing first " .. MAX_ROWS .. " of " .. #items .. " — refine the filter"))
				end
			end
		end

		if emit_scroll then
			sb:add(af.scrollbar(11.7, scroll_top, 0.2, scroll_h, "vertical", sbname, 0))
		end

		-- Bottom bar: manual item entry
		sb:add(
			af.field(0.3, FORM_H - 1.2, 6.8, 0.8, "item_input", "Item", fs_item_input),
			af.button(7.3, FORM_H - 1.2, 1.7, 0.8, "btn_addentry", "Add"),
			af.button(9.2, FORM_H - 1.2, 1.7, 0.8, "btn_removeentry", "Remove"),
			af.button_exit(11.1, FORM_H - 1.2, 1.3, 0.8, "btn_done", "Done")
		)
		return sb:get()
	end,
})

core.register_on_formspec_input(function(formname, fields)
	if formname ~= "cheat_settings:nlist_edmode:custom" then return end
	if fields.btn_done or fields.quit or not next(fields) then return end

	if fields.item_input ~= nil then fs_item_input = fields.item_input end
	if fields.rename_input ~= nil then fs_rename_input = fields.rename_input end

	-- Mode cycle
	if fields.btn_mode then
		nlist.set_mode(mode_next())
	end

	-- List selection
	if fields.list_select and fields.list_select ~= "" and fields.list_select ~= sl then
		nlist.select(fields.list_select)
		fs_filter = ""
		fs_sel = nil
		fs_confirm = nil
	end

	-- New / rename list (button or Enter in the name field)
	local newname = fields.rename_input
		and (fields.rename_input:gsub("^%s+", ""):gsub("%s+$", "")) or ""
	if newname ~= "" and (fields.btn_newlist or fields.btn_rename or fields.key_enter_field == "rename_input") then
		if fields.btn_newlist then
			if table.indexof(nlist.get_lists(), newname) ~= -1 then
				ws.notify("List '" .. newname .. "' already exists", ws.NOTIFY_WARNING, {toast = false})
			else
				nlist.set(newname, {})
				nlist.select(newname)
				fs_filter = ""
				fs_sel = nil
				fs_rename_input = ""
			end
		elseif newname ~= sl then
			if table.indexof(nlist.get_lists(), newname) ~= -1 then
				ws.notify("List '" .. newname .. "' already exists", ws.NOTIFY_WARNING, {toast = false})
			else
				if nlist.count(sl) == 0 then
					nlist.set(newname, {})
					nlist.clear(sl)
				else
					nlist.rename(sl, newname)
				end
				nlist.select(newname)
				fs_rename_input = ""
			end
		end
	end

	-- Delete / clear confirm flow
	if fields.btn_rmlist then
		fs_confirm = "delete"
	elseif fields.btn_clear then
		fs_confirm = "clear"
	elseif fields.btn_confirm_yes then
		if fs_confirm == "delete" then
			nlist.delete(sl)
			nlist.select("default")
		elseif fs_confirm == "clear" then
			nlist.clear(sl)
		end
		fs_confirm = nil
		fs_sel = nil
	elseif fields.btn_confirm_no then
		fs_confirm = nil
	end

	-- Panel switch
	if fields.btn_panel_list then fs_panel = "list" end
	if fields.btn_panel_pick then fs_panel = "pick" end

	-- Filter
	if fields.__fs_search_search or fields.key_enter_field == "fs_search" then
		fs_filter = fields.fs_search or ""
		fs_sel = nil
	end

	-- List row click: apply current mode
	local row_idx
	for k, _ in pairs(fields) do
		if type(k) == "string" then
			local m = k:match("^row_(%d+)$")
			if m then row_idx = tonumber(m); break end
		end
	end
	if row_idx then
		local entries = list_entries()
		local name = entries[row_idx]
		if name then
			if mode == 1 then nlist.add(sl, name, true)
			elseif mode == 2 then nlist.remove(sl, name, true)
			elseif mode == 3 then nlist.toggle(sl, name, true) end
			fs_sel = row_idx
		end
	end

	-- Picker row click: toggle membership
	local pick_idx
	for k, _ in pairs(fields) do
		if type(k) == "string" then
			local m = k:match("^pick_(%d+)$")
			if m then pick_idx = tonumber(m); break end
		end
	end
	if pick_idx then
		local items = pick_entries()
		local name = items[pick_idx]
		if name then nlist.toggle(sl, name, true) end
	end

	-- Wielded / pointed quick-add
	if fields.btn_wielded and core.localplayer then
		nlist.add(sl, core.localplayer:get_wielded_item():get_name())
	end
	if fields.btn_pointed then
		local ptd = core.get_pointed_thing()
		if ptd then
			local nd = core.get_node_or_nil(ptd.under)
			if nd then nlist.add(sl, nd.name) end
		end
	end

	-- Manual add / remove
	if fields.item_input ~= nil and fields.item_input ~= "" then
		if fields.btn_addentry or fields.key_enter_field == "item_input" then
			nlist.add(sl, fields.item_input)
			fs_item_input = ""
		elseif fields.btn_removeentry then
			nlist.remove(sl, fields.item_input)
			fs_item_input = ""
		end
	end

	core.show_cheat_settings_form("nlist_edmode")
end)

core.register_chatcommand('nls',{
	description = "Select a list",
	params = "<list>",
	func=function(list)
		nlist.select(list)
	end
})
core.register_chatcommand('nl',{
	description = "Nodelist manager. Subcommands: select <list> | add <item> | rem <item> | toggle <item> | show [list] | new <list> | delete <list> | export [list] | import <list> <csv>",
	params = "<subcommand> [args]",
	func=function(param)
		local sub, rest = param:match("^(%S+)%s*(.-)$")
		if not sub or sub == "" then return end
		rest = rest or ""
		if sub == "select" or sub == "s" then
			if rest == "" then core.display_chat_message("Usage: /nl select <list>"); return end
			nlist.select(rest)
			core.display_chat_message("Selected list: " .. rest)
		elseif sub == "add" or sub == "a" then
			if rest == "" then core.display_chat_message("Usage: /nl add <item>"); return end
			nlist.add(sl, rest)
		elseif sub == "rem" or sub == "remove" or sub == "r" then
			if rest == "" then core.display_chat_message("Usage: /nl rem <item>"); return end
			nlist.remove(sl, rest)
		elseif sub == "toggle" or sub == "t" then
			if rest == "" then core.display_chat_message("Usage: /nl toggle <item>"); return end
			nlist.toggle(sl, rest)
		elseif sub == "show" then
			nlist.show_list(rest ~= "" and rest or sl)
		elseif sub == "new" then
			if rest == "" then core.display_chat_message("Usage: /nl new <list>"); return end
			nlist.set(rest, {})
			nlist.select(rest)
			core.display_chat_message("Created and selected list: " .. rest)
		elseif sub == "delete" or sub == "del" then
			if rest == "" then core.display_chat_message("Usage: /nl delete <list>"); return end
			nlist.delete(rest)
			if nlist.selected == rest then nlist.select("default") end
			core.display_chat_message("Deleted list: " .. rest)
		elseif sub == "export" or sub == "e" then
			local name = rest ~= "" and rest or sl
			local entries = nlist.get(name)
			core.display_chat_message("[" .. name .. "] "
				.. (#entries > 0 and table.concat(entries, ", ") or "(empty)"))
		elseif sub == "import" or sub == "i" then
			local dst, csv = rest:match("^(%S+)%s+(.-)$")
			if not dst or csv == "" then
				core.display_chat_message("Usage: /nl import <list> <csv>"); return
			end
			local count = 0
			for item in csv:gmatch("[^,]+") do
				if nlist.add(dst, item, true) then count = count + 1 end
			end
			core.display_chat_message("Imported " .. count .. " items into " .. dst)
		else
			core.display_chat_message("Unknown subcommand: " .. sub .. ". See /help nl")
		end
	end
})
core.register_chatcommand('nlshow',{
	description = "Show a list as HUD without selecting it (defaults to the selected list)",
	params = "[<list>]",
	func=function(list)
		if list == "" then list = sl end
		nlist.show_list(list)
	end
})
core.register_chatcommand('nlhide',{
	description = "Hide the currently shown list",
	params = "",
	func=function() nlist.hide() end
})
core.register_chatcommand('nla',{
	description = "Add an item to the selected list or switch to 'add' mode if run without parameters",
	params = "[<item>]",
	func=function(el)
		if el == "" then nlist.set_mode(1); ws.notify("nlist mode: add", ws.NOTIFY_INFO, {toast=false}); return end
		nlist.add(sl,el)
	end
})
core.register_chatcommand('nlr',{
	description = "Remove an item from the selected list or switch to 'remove' mode if run without parameters",
	params = "[<item>]",
	func=function(el)
		if el == "" then nlist.set_mode(2); ws.notify("nlist mode: remove", ws.NOTIFY_INFO, {toast=false}); return end
		nlist.remove(sl,el)
	end
})
core.register_chatcommand('nlt',{
	description = "Toggle an item in the selected list or switch to 'toggle' mode if run without parameters",
	params = "[<item>]",
	func=function(el)
		if el == "" then nlist.set_mode(3); ws.notify("nlist mode: toggle", ws.NOTIFY_INFO, {toast=false}); return end
		nlist.toggle(sl,el)
	end
})
core.register_chatcommand('nlc',{
	description = "Clear the selected list",
	params = "",
	func=function(el) nlist.clear(sl) end
})

core.register_chatcommand('nlawi',{
	description = "Add wielded itemstring to the selected list",
	params = "",
	func=function() if not core.localplayer then return end nlist.add(sl,core.localplayer:get_wielded_item():get_name())  end
})

core.register_chatcommand('nlrwi',{
	description = "Remove wielded itemstring from the selected list",
	params = "",
	func=function() if not core.localplayer then return end nlist.remove(sl,core.localplayer:get_wielded_item():get_name())  end
})

core.register_chatcommand('nlapn',{
	description = "Add pointed node's itemstring to the selected list",
	params = "",
	func=function()
		if not core.localplayer then return end
		local ptd = core.get_pointed_thing()
		if ptd then
			local nd=core.get_node_or_nil(ptd.under)
			if nd then nlist.add(sl,nd.name) end
		end
end})
core.register_chatcommand('nlrpn',{
	description = "Remove pointed node's itemstring from the selected list",
	params = "",
	func=function()
		if not core.localplayer then return end
		local ptd = core.get_pointed_thing()
		if ptd then
			local nd=core.get_node_or_nil(ptd.under)
			if nd then nlist.remove(sl,nd.name) end
		end
end})


for k,v in pairs(core.registered_chatcommands) do
	if v.list_setting then
		local oldfunc = v.func
		core.registered_chatcommands[k].description = v.description..", nls to import currently selected nlist"
		core.registered_chatcommands[k].func = function(p)
			if p == "nls" then
				nlist.merge(v.list_setting, nlist.selected)
				return
			end
			return oldfunc(p)
		end
	end
end
