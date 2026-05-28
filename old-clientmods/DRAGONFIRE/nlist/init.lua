nlist = {}
local storage = minetest.get_mod_storage("nlist")
local sl="default"
local mode=1 --1:add, 2:remove
local nled_hud
local edmode_wason=false
nlist.selected=sl

local function get_dflist(list)
	local l
	for k,v in pairs(minetest.registered_chatcommands) do
		if v.list_setting and ( k == list or v.list_setting == list ) then
			l = v.list_setting
		end
		if l then return l end
	end
	return false
end

function nlist.add(list,node)
	if node == "" then mode=1 return end
	local tb=nlist.get(list)
	if table.indexof(tb,node) ~= -1 then return end
	table.insert(tb,node)
	nlist.set(list,tb)
	ws.dcm(node..' added to '..list)
end

function nlist.remove(list,node)
	if node == "" then mode=2 return end
	local tb=nlist.get(list)
	local ix = table.indexof(tb,node)
	if ix == -1 then return end
	table.remove(tb,ix)
	nlist.set(list,tb)
	ws.dcm(node..' removed from '..list)
end

function nlist.set(list,tb)
	local str=table.concat(tb,",")
	local df = get_dflist(list)
	if df then
		minetest.settings:set(df,str)
	else
		storage:set_string(list,str)
	end
end

function nlist.get(list)
	local str
	local df = get_dflist(list)
	if df then
		str=minetest.settings:get(df)
	else
		str=storage:get_string(list)
	end
	return str and str:split(',') or {}
end

function nlist.clear(list)
	local df = get_dflist(list)
	if df then
		minetest.settings:set(df,"")
	else
		storage:set_string(list,"")
	end
end

function nlist.delete(list)
	local df = get_dflist(list)
	if df then
		minetest.settings:set(df, "")
	else
		storage:set_string(list, "")
	end
end

function nlist.select(list)
	sl = list
	nlist.selected = list
	local df = get_dflist(list)
	if df then
		sl = df
		nlist.selected = df
	end
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
	if not list or not nlist.set(newname,list) then return end
	if oldname ~= newname then
		 nlist.clear(oldname)
	end
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
	local str=storage:get(list)
	local tb=str:split(',')
	local kk = {}
	for k in pairs(tb) do
		table.insert(kk, k)
	end
	return tb[kk[math.random(#kk)]]
end

function nlist.show_list(list,hlp)
	if not list then return end
	local act="add"
	if mode == 2 then act="remove" end
	local txt=list .. "\n --\n" .. table.concat(nlist.get(list),"\n")
	local htxt="Nodelist edit mode\n .nla/.nlr to switch\n punch node to ".. act .. "\n.nlc to clear\n"
	if hlp then txt=htxt .. txt end
	nlist.set_nled_hud(txt)
end

function nlist.hide()
	if nled_hud then minetest.localplayer:hud_remove(nled_hud) nled_hud=nil end
end

function nlist.set_nled_hud(ttext)
	if not minetest.localplayer then return end
	if type(ttext) ~= "string" then return end

	local dtext ="List: ".. ttext

	if nled_hud then
		minetest.localplayer:hud_change(nled_hud,'text',dtext)
	else
		nled_hud = minetest.localplayer:hud_add({
			hud_elem_type = 'text',
			name		  = "Nodelist",
			text		  = dtext,
			number		= 0x00ff00,
			direction   = 0,
			position = {x=0.8,y=0.40},
			alignment ={x=1,y=1},
			offset = {x=0, y=0}
		})
	end
	return true
end

minetest.register_on_punchnode(function(p, n)
	if not minetest.settings:get_bool('nlist_edmode') then return end
	if mode == 1 then
		nlist.add(nlist.selected,n.name)
	elseif mode ==2 then
		nlist.remove(nlist.selected,n.name)
	end
end)

ws.rg('NlEdMode', { category = 'nList', setting = 'nlist_edmode',
	on_step = function(self) nlist.show_list(sl, true) end,
	on_start = function(self) end,
	on_stop = function(self) nlist.hide() end,
	get_formspec = function(setting)
		local entries = nlist.get(sl)
		local lists = nlist.get_lists()
		if not table.indexof(lists, sl) then
			table.insert(lists, sl)
		end
		table.sort(lists)

		local function textlist_idx(val)
		if val == "INV" then return 0 end
		local colon = val:find(":")
		if colon then return tonumber(val:sub(colon + 1)) or 0 end
		return tonumber(val) or 0
	end

	local function esc_list(t)
			local out = {}
			for _, v in ipairs(t) do
				table.insert(out, core.formspec_escape(v))
			end
			return table.concat(out, ",")
		end

		local entries_str = #entries > 0 and esc_list(entries) or " "

		local sel_idx = 1
		for i, name in ipairs(lists) do
			if name == sl then sel_idx = i break end
		end

		local fs = "size[8,9.5]"
		fs = fs .. "bgcolor[#000000;true]"
		fs = fs .. "label[0,0;List: " .. core.formspec_escape(sl) .. "]"
		fs = fs .. "textlist[0,0.5;5,5;entries;" .. entries_str .. ";1]"
		fs = fs .. "button[0,5.7;0.6,0.7;btn_addentry;+]"
		fs = fs .. "button[0.7,5.7;0.6,0.7;btn_rmentry;-]"
		fs = fs .. "button[1.5,5.7;1.2,0.7;btn_clear;Clear]"
		fs = fs .. "dropdown[5.5,0.5;2.5;list_select;" .. esc_list(lists) .. ";" .. sel_idx .. "]"
		fs = fs .. "label[5.5,1.7;Lists]"
		fs = fs .. "button[5.5,2.2;1.2,0.8;btn_addlist;+ List]"
		fs = fs .. "button[6.8,2.2;1.2,0.8;btn_rmlist;- List]"
		fs = fs .. "label[0.3,6.7;Type a name below, then press + or -]"
		fs = fs .. "field[0.3,7;7.2,0.8;item_input;;]"
		fs = fs .. "button_exit[6.8,8.5;1.2,0.8;btn_done;Done]"
		return fs
	end,
})

core.register_on_formspec_input(function(formname, fields)
	if formname ~= "cheat_settings:nlist_edmode:custom" then return end

	if fields.btn_done or not next(fields) then return end

	if fields.list_select and fields.list_select ~= "" then
		nlist.select(fields.list_select)
	end

	if fields.btn_addlist and fields.item_input and fields.item_input ~= "" then
		nlist.set(fields.item_input, {})
		nlist.select(fields.item_input)
	elseif fields.btn_rmlist then
		local name = fields.list_select or sl
		nlist.delete(name)
		if sl == name then
			nlist.select("default")
		end
	elseif fields.btn_addentry and fields.item_input and fields.item_input ~= "" then
		nlist.add(sl, fields.item_input)
	elseif fields.btn_rmentry then
		if fields.item_input and fields.item_input ~= "" then
			nlist.remove(sl, fields.item_input)
		elseif fields.entries and fields.entries ~= "" then
			local entries = nlist.get(sl)
			local idx = textlist_idx(fields.entries)
			if idx > 0 and idx <= #entries then
				nlist.remove(sl, entries[idx])
			end
		end
	elseif fields.btn_clear then
		nlist.clear(sl)
	end

	core.show_cheat_settings_form("nlist_edmode")
end)

minetest.register_chatcommand('nls',{
	description = "Select a list",
	params = "<list>",
	func=function(list)
		nlist.select(list)
	end
})
minetest.register_chatcommand('nlshow',{
	description = "Show a list without selecting",
	params = "<list>",
	func=function() nlist.show_list(sl) end
})
minetest.register_chatcommand('nlhide',{
	description = "Hide the currently shown list",
	params = "",
	func=function() nlist.hide() end
})
minetest.register_chatcommand('nla',{
	description = "Add an item to the selected list or switch to 'add' mode if run without parameters",
	params = "[<item>]",
	func=function(el) nlist.add(sl,el)  end
})
minetest.register_chatcommand('nlr',{
	description = "Remove an item from the selected list or switch to 'remove' mode if run without parameters",
	params = "[<item>]",
	func=function(el) nlist.remove(sl,el) end
})
minetest.register_chatcommand('nlc',{
	description = "Clear the selected list",
	params = "",
	func=function(el) nlist.clear(sl) end
})

minetest.register_chatcommand('nlawi',{
	description = "Add wielded itemstring to the selected list",
	params = "",
	func=function() nlist.add(sl,minetest.localplayer:get_wielded_item():get_name())  end
})

minetest.register_chatcommand('nlrwi',{
	description = "Remove wielded itemstring from the selected list",
	params = "",
	func=function() nlist.remove(sl,minetest.localplayer:get_wielded_item():get_name())  end
})

minetest.register_chatcommand('nlapn',{
	description = "Add pointed node's itemstring to the selected list",
	params = "",
	func=function()
		local ptd = minetest.get_pointed_thing()
		if ptd then
			local nd=minetest.get_node_or_nil(ptd.under)
			if nd then nlist.add(sl,nd.name) end
		end
end})
minetest.register_chatcommand('nlrpn',{
	description = "Remove pointed node's itemstring from the selected list",
	params = "",
	func=function()
		local ptd = minetest.get_pointed_thing()
		if ptd then
			local nd=minetest.get_node_or_nil(ptd.under)
			if nd then nlist.remove(sl,nd.name) end
		end
end})


for k,v in pairs(minetest.registered_chatcommands) do
	if v.list_setting then
		local oldfunc = v.func
		minetest.registered_chatcommands[k].params = "del <item> | add <item> | list | nls"
		minetest.registered_chatcommands[k].description = v.description..", nls to import currently selected nlist"
		minetest.registered_chatcommands[k].func = function(p)
			if p == "nls" then
				nlist.copy(nlist.selected,v.list_setting)
				return
			end
			return oldfunc(p)
		end
	end
end
