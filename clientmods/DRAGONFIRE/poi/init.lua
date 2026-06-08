poi={}
local storage = minetest.get_mod_storage("poi")
local info=minetest.get_server_info()
local stprefix="POI-".. info['address']  .. '-'
local displayed_pois={}

local DISTANCE_NEAR = 256

local formspec_list = {}
poi.registered_transports={}
poi.speed=0

local selected_name

poi.last_name=nil
poi.last_pos=nil

local lpos
local etime=0

local shown_huds = {}

local hud_wp

function poi.check_vector(v)
	if not v then return false end
	for _,d in pairs({"x","y","z"}) do
		if not v[d] or not tonumber(v[d]) or minetest.is_nan(v[d]) then return false end
	end
	return true
end

function poi.getwps()
	local wp={}
	for name, _ in pairs(storage:to_table().fields) do
		if name:sub(1, string.len(stprefix)) == stprefix then
			table.insert(wp, name:sub(string.len(stprefix)+1))
		end
	end
	table.sort(wp)
	return wp
end

function poi.set_waypoint(pos, name)
	pos = ws.pos_to_string(pos)
	if not pos then return end
	storage:set_string(stprefix .. tostring(name), pos)
	return true
end

function poi.delete_waypoint(name)
	storage:set_string(stprefix .. tostring(name), '')
end

function poi.get_waypoint(name)
	return ws.string_to_pos(storage:get_string(stprefix .. tostring(name)))
end

function poi.has_wp_near(pos)
	for _,v in pairs(poi.getwps()) do
		local wpos = poi.get_waypoint(v)
		if poi.check_vector(wpos) then
			if vector.distance(pos,wpos) <= DISTANCE_NEAR then return true end
		end
	end
end

function poi.rename_waypoint(oldname, newname)
	oldname, newname = tostring(oldname), tostring(newname)
	local pos = poi.get_waypoint(oldname)
	if not pos or not poi.set_waypoint(pos, newname) then return end
	if oldname ~= newname then
		poi.delete_waypoint(oldname)
	end
	return true
end

function poi.get_quad()
	local lp=minetest.localplayer:get_pos()
	local quad=""

	if lp.z < 0 then quad="South"
	else quad="North" end

	if lp.x < 0 then quad=quad.."-west"
	else quad=quad.."-east" end

	return quad
end

local lpos = nil

local function update_speed() --to be called once a second by globalstep to get speed in nodes per second
	if minetest.localplayer then
		local cpos = minetest.localplayer:get_pos()
		if lpos and cpos then
			poi.speed = ws.round2(vector.distance(cpos,lpos),2)
		end
		lpos=cpos
	end
end

minetest.register_on_death(function()
	if not minetest.localplayer then return end
	if core.settings:get_bool("auto_death_waypoint", true) then
		local name = 'Death waypoint'
		local pos  = minetest.localplayer:get_pos()
		poi.death_pos = vector.new(pos)
		poi.last_pos = pos
		poi.last_name = name
		poi.set_waypoint(pos,name)
		poi.display(pos,name)
	end
	if minetest.settings:get_bool("death_tp") then
		minetest.after(0.5,function()
			minetest.localplayer:set_pos(poi.death_pos)
			core.after(0.1, function()
				local n = core.get_node_or_nil(poi.death_pos)
				if n and n.name == "bones:bones" then
					ws.dig_node(poi.death_pos())
				end
			end)
		end)
	end
end)

core.register_cheat("DeathWaypoints", {
	category = "Player",
	setting = "auto_death_waypoint",
	description = "Auto-create a waypoint at death location",
})
ws.rg("DeathTP","Player","death_tp",function()end,function()end,function()end,{"autorespawn"})

function poi.set_hud_wp(pos, title)
	pos = ws.string_to_pos(pos)
	if not pos then return end
	if not title then
		title = ws.pos_to_string(pos)
	end
	poi.last_name=title
	poi.last_pos=pos
	if shown_huds[title] then
		minetest.localplayer:hud_change(shown_huds[title], 'name', title)
		minetest.localplayer:hud_change(shown_huds[title], 'world_pos', pos)
	else
		hud_wp = minetest.localplayer:hud_add({
			hud_elem_type = 'waypoint',
			name		  = title,
			text		  = 'm',
			number		= 0x00ff00,
			world_pos	 = pos
		})
	end
	shown_huds[title] = hud_wp
	return true
end

function poi.get_nearest_name()
	local ww=poi.getwps()
	local lp=minetest.localplayer:get_pos()
	local odst=500
	local rt=false
	for k,v in pairs(ww) do
		local lwp=poi.get_waypoint(v)
		if type(lwp) == 'table' then
			local dst=vector.distance(lp,lwp)
			if dst < 500 then
				if dst < odst then
					odst=dst
					rt=v
				end
			end
		end
	end
	if not rt then rt=poi.get_quad() end
	return rt
end

local function calculate_eta(tpos,speed)
	local etatime = -1
	local dst = vector.distance(ws.dircoord(0,0,0),tpos)
	if not (poi.speed == 0) then etatime = ws.round2(dst / poi.speed / 60,2) end
	return etatime
end


function poi.display(pos,name)
	if name == nil then name=ws.pos_to_string(pos) end
	local pos=ws.string_to_pos(pos)
	poi.set_hud_wp(pos, name)
	return true
end


function poi.display_waypoint(name)
	local pos=poi.get_waypoint(name)
	poi.last_name = name
	poi.last_pos = pos
	ws.aim(poi.last_pos)
	poi.display(pos,name)
	return true
end


poi.registered_transports={}
local tspeed = 20 -- speed in blocks per second
local speed=0;
local ltime=0
function poi.register_transport(name,func)
	table.insert(poi.registered_transports,{name=name,func=func})
end
function poi.display_formspec()
	local formspec = "formspec_version[4]"..
		"size[12,10]" ..
		"background9[1,1;1,1;blank.png;true;7]"..
		"bgcolor[#000000AA;false]"..

		"label[0.25,0.5;Waypoint list]" ..

		"button_exit[0.5,7.5;1,0.5;display;Show]" ..
		"button[9,7.5;1.3,0.5;rename;Rename]" ..
		"button[10.5,7.5;1.3,0.5;delete;Delete]"

	local sp = 0.5
	local y = 8.25
	for k,v in pairs(poi.registered_transports) do
		formspec=formspec.."button_exit["..sp..","..y..";1,0.5;"..v.name..";"..v.name.."]"
		sp=sp+1
		if sp > 10 then
			y = y + 0.75
			sp = 0.5
		end
	end

	formspec=formspec..'textlist[0.25,0.75;11.5,6;wp_list;'
	local selected = 1
	formspec_list = {}

	local waypoints = poi.getwps()


	for id, name in ipairs(waypoints) do
		if id > 1 then
			formspec = formspec .. ','
		end
		if not selected_name then
			selected_name = name
		end
		if name == selected_name then
			selected = id
		end
		formspec_list[#formspec_list + 1] = name
		formspec = formspec .. '##' .. minetest.formspec_escape(name)
	end

	formspec = formspec .. ';' .. tostring(selected) .. ']'

	if selected_name then
		local pos = poi.get_waypoint(selected_name)
		if pos then
			pos = minetest.formspec_escape(tostring(pos.x) .. ', ' ..
			tostring(pos.y) .. ', ' .. tostring(pos.z))
			pos = 'Waypoint position: ' .. pos
			formspec = formspec .. 'label[0.25,7.25;' .. pos .. ']'
		end
	else
		-- Draw over the buttons
		formspec = formspec .. 'button_exit[0,10.5;5.25,0.5;quit;Close dialog]' ..
			'label[0,6.75;No waypoints. Add one with ".wa".]'
	end

	-- Display the formspec
	return minetest.show_formspec('poi-csm', formspec)
end

local speed_etime = 1
minetest.register_globalstep(function(dtime)
	speed_etime = speed_etime - dtime
	if speed_etime > 0 then return end
	speed_etime = 1
	update_speed()
	if poi.last_pos then
		poi.etatime = calculate_eta(poi.last_pos, poi.speed)
	end
	poi.target = poi.last_pos
	poi.eta = poi.etatime
end)


minetest.register_on_formspec_input(function(formname, fields)
	if formname == 'poi-ignore' then
		return true
	elseif formname ~= 'poi-csm' then
		return
	end
	local name = false
	if fields.wp_list then
		local event = minetest.explode_textlist_event(fields.wp_list)
		if event.index then
			name = formspec_list[event.index]
		end
	else
		name = selected_name
	end

	if name then
		for k,v in pairs(poi.registered_transports) do
			if fields[v.name] then
				if v.func(poi.get_waypoint(name),name) then
					ws.notify('Error with '..v.name, ws.NOTIFY_ERROR)
					return
				end
			end
		end
		if fields.display then
			if not poi.display_waypoint(name) then
				ws.notify('Error displaying waypoint!', ws.NOTIFY_ERROR)
				return
			end
		elseif fields.rename then
			minetest.show_formspec('poi-csm', 'size[6,3]' ..
				'label[0.35,0.2;Rename poi]' ..
				'field[0.3,1.3;6,1;new_name;New name;' ..
				minetest.formspec_escape(name) .. ']' ..
				'button[0,2;3,1;cancel;Cancel]' ..
				'button[3,2;3,1;rename_confirm;Rename]')
		elseif fields.rename_confirm then
			if fields.new_name and #fields.new_name > 0 then
				if poi.rename_waypoint(name, fields.new_name) then
					selected_name = fields.new_name
				else
					ws.notify('Error renaming poi!', ws.NOTIFY_ERROR)
				end
				poi.display_formspec()
			else
				ws.notify("New name required", ws.NOTIFY_ERROR)
			end
		elseif fields.delete then
			minetest.show_formspec('poi-csm', 'size[6,2]' ..
				'label[0.35,0.25;Are you sure you want to delete this poi?]' ..
				'button[0,1;3,1;cancel;Cancel]' ..
				'button[3,1;3,1;delete_confirm;Delete]')
		elseif fields.delete_confirm then
			poi.delete_waypoint(name)
			selected_name = false
			poi.display_formspec()
		elseif fields.cancel then
			poi.display_formspec()
		elseif name ~= selected_name then
			selected_name = name
			poi.display_formspec()
		end
	elseif fields.display or fields.delete then
		ws.notify('Please select a poi.', ws.NOTIFY_ERROR)
	end
	return true
end)

minetest.register_chatcommand('waypoints', {
	params	  = '',
	description = 'Open the poi GUI',
	func = function(param) poi.display_formspec() end
})

ws.register_chatcommand_alias('waypoints','wp', 'wps', 'waypoint')

minetest.register_chatcommand('add_waypoint', {
	params	  = '<pos / "here" / "there"> <name>',
	description = 'Adds a waypoint.',
	func = function(param)
		local s, e = param:find(' ')
		if not s or not e then
			return false, 'Invalid syntax! See .help add_mrkr for more info.'
		end
		local pos = param:sub(1, s - 1)
		local name = param:sub(e + 1)
		if not pos then
			return false, err
		end
		if not name or #name < 1 then
			return false, 'Invalid name!'
		end
		return poi.set_waypoint(pos, name), 'Done!'
	end
})
ws.register_chatcommand_alias('add_waypoint','wa', 'add_wp')


minetest.register_chatcommand('add_waypoint_here', {
	params	  = 'name',
	description = 'marks the current position',
	func = function(param)
		local name = os.date("%Y-%m-%d %H:%M:%S")
		if tostring(param) ~= "" then name=param end
		local pos  = minetest.localplayer:get_pos()
		return poi.set_waypoint(pos, name), 'Done!'
	end
})
ws.register_chatcommand_alias('add_waypoint_here', 'wah', 'add_wph')

minetest.register_chatcommand('clear_waypoint', {
	description = 'Hides the displayed waypoint.',
	func = function(param)
		if poi.flying then poi.flying=false end
		if hud_wp then
			minetest.localplayer:hud_remove(hud_wp)
			hud_wp = nil
			return true, 'Hidden the currently displayed waypoint.'
		else
			return false, 'No waypoint is currently being displayed!'
		end
		for k,v in wps do
			minetest.localplayer:hud_remove(v)
			table.remove(k)
		end

	end,
})
ws.register_chatcommand_alias('clear_waypoint', 'cwp','cls')

minetest.register_chatcommand('wpdisplay', {
	params	  = 'position name',
	description = 'display waypoint',
	func = function(pos,name)
	  poi.display(pos,name)
	end
})
ws.register_chatcommand_alias('wpdisplay', 'wpd')

minetest.register_chatcommand("dump_pois",{
	func = function()
		for name, pos in pairs(storage:to_table().fields) do
			minetest.log(name.. " : "..pos)
		end
	end
})

core.register_cheat("ShowNames", { category = "Render", setting = "poi_shownames" })
core.register_cheat("POIs", { category = "Misc", func = poi.display_formspec })
