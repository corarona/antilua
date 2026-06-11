nlist = {}
local storage = core.get_mod_storage("nlist")
local sl="default"
local mode=1 --1:add, 2:remove
local nled_hud
local nlist_last_content = "" -- cache for HUD update optimization
nlist.selected=sl

-- Migrate existing xray_nodes setting to nlist
local existing = core.settings:get("xray_nodes")
if existing and existing ~= "" and storage:get_string("xray") == "" then
	storage:set_string("xray", existing)
end

local function mode_name()
	return mode == 1 and "add" or "remove"
end

function nlist.add(list,node)
	if node == "" then return end
	local tb=nlist.get(list)
	if table.indexof(tb,node) ~= -1 then return end
	table.insert(tb,node)
	nlist.set(list,tb)
	ws.notify(node .. " added to " .. list, ws.NOTIFY_INFO, {toast=false})
end

function nlist.remove(list,node)
	if node == "" then return end
	local tb=nlist.get(list)
	local ix = table.indexof(tb,node)
	if ix == -1 then return end
	table.remove(tb,ix)
	nlist.set(list,tb)
	ws.notify(node .. " removed from " .. list, ws.NOTIFY_INFO, {toast=false})
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

function nlist.delete(list)
	storage:set_string(list, nil)
	return true
end

function nlist.select(list)
	sl = list
	nlist.selected = list
end

function nlist.get_lists()
	local ret={}
	for name, _ in pairs(storage:to_table().fields) do
		table.insert(ret, name)
	end
	table.sort(ret)
	return ret
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

function nlist.show_list(list, hlp)
	if not list then return end
	local txt = list .. " [" .. mode_name() .. "]" .. "\n --\n" .. table.concat(nlist.get(list),"\n")
	local htxt = "Nodelist edit mode\n.nla/.nlr to switch\npunch node to " .. mode_name() .. "\n.nlc to clear\n"
	if hlp then txt = htxt .. txt end
	if txt ~= nlist_last_content then
		nlist_last_content = txt
		local dtext = "List: " .. txt
		if nled_hud then
			core.localplayer:hud_change(nled_hud, 'text', dtext)
		else
			nlist.set_nled_hud(txt)
		end
	end
end

local function textlist_idx(val)
	if val == "INV" then return 0 end
	local colon = val:find(":")
	if colon then return tonumber(val:sub(colon + 1)) or 0 end
	return tonumber(val) or 0
end

function nlist.hide()
	if not core.localplayer then return end
	if nled_hud then core.localplayer:hud_remove(nled_hud) nled_hud=nil end
end

function nlist.set_nled_hud(ttext)
	if not core.localplayer then return end
	if type(ttext) ~= "string" then return end
	local dtext = "List: " .. ttext
	if nled_hud then
		core.localplayer:hud_change(nled_hud, 'text', dtext)
	else
		nled_hud = core.localplayer:hud_add({
			type = 'text',
			name = "Nodelist",
			text = dtext,
			number = 0x00ff00,
			direction = 0,
			position = {x = 0.8, y = 0.40},
			alignment = {x = 1, y = 1},
			offset = {x = 0, y = 0},
		})
	end
	return true
end

core.register_on_punchnode(function(p, n)
	if not core.settings:get_bool('nlist_edmode') then return end
	if mode == 1 then
		nlist.add(nlist.selected, n.name)
	elseif mode == 2 then
		nlist.remove(nlist.selected, n.name)
	end
end)

ws.rg('NlEdMode', { category = 'Misc', setting = 'nlist_edmode',
	on_step = function(self) nlist.show_list(sl, true) end,
	on_start = function(self) end,
	on_stop = function(self) nlist.hide() end,
	get_formspec = function(setting)
		local af = core.al_formspec
		local entries = nlist.get(sl)
		local lists = nlist.get_lists()
		if not table.indexof(lists, sl) then
			table.insert(lists, sl)
		end
		table.sort(lists)

		local sel_idx = 1
		for i, name in ipairs(lists) do
			if name == sl then sel_idx = i break end
		end

		local sb = af.cheat_form_begin("size[10,11]")
		sb:add(
			af.label(0.3, 0, "List: " .. sl .. " [" .. mode_name() .. "]"),
			af.textlist(0.3, 0.5, 9.4, 5.5, "entries", entries),
			af.dropdown(5.5, 0.5, 4.2, "list_select", lists, sel_idx),
			af.label(5.5, 1.7, "Select list"),
			af.button(5.5, 2.2, 2, 0.8, "btn_addlist", "+ New"),
			af.button(7.6, 2.2, 2, 0.8, "btn_rmlist", "- Delete"),
			af.button(5.5, 3.2, 4.2, 0.8, "btn_rename", "Rename"),
			af.field(0.3, 6.3, 7, 0.8, "rename_input", "", ""),
			af.label(0.3, 7.3, "Item (or select from list to remove)"),
			af.field(0.3, 7.8, 7, 0.8, "item_input", "", ""),
			af.button(7.4, 7.8, 1.2, 0.8, "btn_addentry", "Add"),
			af.button(8.7, 7.8, 1.2, 0.8, "btn_rmentry", "Rem"),
			af.button(0.3, 9, 2, 0.8, "btn_clear", "Clear all"),
			af.button_exit(8.5, 10, 1.3, 0.8, "btn_done", "Done")
		)
		return sb:get()
	end,
})

core.register_on_formspec_input(function(formname, fields)
	if formname ~= "cheat_settings:nlist_edmode:custom" then return end
	if fields.btn_done or fields.quit or not next(fields) then return end

	if fields.list_select and fields.list_select ~= "" then
		nlist.select(fields.list_select)
	end

	if fields.btn_addlist and fields.item_input and fields.item_input ~= "" then
		nlist.set(fields.item_input, {})
		nlist.select(fields.item_input)
	end
	if fields.btn_rmlist then
		local name = fields.list_select or sl
		nlist.delete(name)
		if sl == name then
			nlist.select("default")
		end
	end
	if fields.btn_rename and fields.rename_input and fields.rename_input ~= "" then
		nlist.rename(sl, fields.rename_input)
		nlist.select(fields.rename_input)
	end
	if fields.btn_addentry and fields.item_input and fields.item_input ~= "" then
		nlist.add(sl, fields.item_input)
	end
		if fields.btn_rmentry then
			if fields.item_input and fields.item_input ~= "" then
				nlist.remove(sl, fields.item_input)
			elseif fields.entries and fields.entries ~= "" then
				local entries = nlist.get(sl)
				local idx = textlist_idx(fields.entries)
				if idx > 0 and idx <= #entries then
					nlist.remove(sl, entries[idx])
				end
			end
		end
		if fields.btn_clear then
			nlist.clear(sl)
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
core.register_chatcommand('nlshow',{
	description = "Show a list without selecting",
	params = "<list>",
	func=function() nlist.show_list(sl) end
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
		if el == "" then mode=1; ws.notify("nlist mode: add", ws.NOTIFY_INFO, {toast=false}); return end
		nlist.add(sl,el)
	end
})
core.register_chatcommand('nlr',{
	description = "Remove an item from the selected list or switch to 'remove' mode if run without parameters",
	params = "[<item>]",
	func=function(el)
		if el == "" then mode=2; ws.notify("nlist mode: remove", ws.NOTIFY_INFO, {toast=false}); return end
		nlist.remove(sl,el)
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
		core.registered_chatcommands[k].params = "del <item> | add <item> | list | nls"
		core.registered_chatcommands[k].description = v.description..", nls to import currently selected nlist"
		core.registered_chatcommands[k].func = function(p)
			if p == "nls" then
				nlist.copy(nlist.selected,v.list_setting)
				return
			end
			return oldfunc(p)
		end
	end
end
