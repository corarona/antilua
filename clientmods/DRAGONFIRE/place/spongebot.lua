local sb_state = 0
local sb_target = nil
local sb_startpos
local is_spongebot = false
math.randomseed(os.clock())

minetest.register_on_mods_loaded(function()
	for k, v in pairs(minetest.registered_items) do
		minetest.override_item(k, { node_placement_prediction = "" })
	end
end)

ws.on_connect(function()
	if minetest.settings:get_bool("autoclog") then
		is_spongebot = true
		local lp = minetest.localplayer:get_pos()
		minetest.localplayer:set_pos(vector.new(lp.x, lp.y + 30, lp.z))
	end
end)

local function find_closest(ndnames, range)
	range = range or ws.range
	local lp = ws.dircoord(0, 0, 0)
	local nds = minetest.find_nodes_near(lp, range, ndnames, true)
	local odst = 100
	local rt = nil
	for _, v in ipairs(nds) do
		local dst = vector.distance(lp, v)
		if dst < odst and v.y > 1 then odst = dst rt = v end
	end
	if not rt then
		minetest.settings:set_bool("continuous_forward", false)
		minetest.sound_play("mcl_bells_bell_stroke", { pitch = 1.5, gain = 1.5 })
		minetest.settings:set_bool("spongebot", false)
	end
	return rt, odst
end

local function checknode(pos)
	if pos then
		local tn = minetest.get_node_or_nil(pos)
		if tn and tn.name ~= "air" then return true end
	end
end

ws.rg("SpongeBot", { category = "Bots", setting = "spongebot",
	on_step = function(self)
		local dst = 200
		local lp = minetest.localplayer:get_pos()
		if sb_state == 0 then
			sb_target, dst = find_closest({"mcl_core:water_source"}, 50)
			if checknode(sb_target) then
				local blk = minetest.find_nodes_in_area(
					ws.dircoord(0, -1, 0), ws.dircoord(1, 2, 0),
					{'mcl_core:bedrock', 'mcl_core:obsidian'})
				if blk and #blk > 0 then
					minetest.localplayer:set_pos(ws.dircoord(math.random(-1, 1), 2, math.random(-1, 1)))
				end
				sb_state = 1
				return
			end
		elseif sb_state == 1 then
			ws.aim(sb_target)
			if not checknode(sb_target) then
				sb_state = 0
				return
			end
		end
		if sb_target and vector.distance(lp, sb_target) < 1 then
			minetest.settings:set_bool("continuous_forward", false)
			ws.dig(sb_target)
		else
			minetest.settings:set_bool("continuous_forward", true)
		end
	end,
	on_start = function(self)
		sb_state = 0
		sb_target = nil
		math.randomseed(os.clock())
		sb_startpos = minetest.localplayer:get_pos()
		minetest.settings:set_bool("pitch_move", true)
		minetest.settings:set_bool("free_move", true)
		minetest.settings:set_bool("autosponge", true)
		minetest.settings:set_bool("autoclog", true)
		minetest.settings:set_bool("autoeat", true)
	end,
	on_stop = function(self)
		minetest.settings:set_bool("pitch_move", false)
	end,
	cheat_settings = {
		search_range = { type = "number", default = 50, min = 5, max = 200 },
		travel_range = { type = "number", default = 200, min = 10, max = 500 },
	},
})

ws.rg("Autosponge", { category = "World", setting = "autosponge",
	on_step = function(self)
		local range = tonumber(core.settings:get(self.setting .. ".range")) or 10
		local water = minetest.find_node_near(minetest.localplayer:get_pos(), range, "mcl_core:water_source")
		if water then
			ws.place(water, "mcl_sponges:sponge")
		end
	end,
	cheat_settings = {
		range = { type = "number", default = 10, min = 1, max = 50 },
	},
})

ws.rg("DigFreeSponge", { category = "Dig", setting = "autospongedig",
	on_step = function(self)
		local range = tonumber(core.settings:get(self.setting .. ".range")) or 4
		local water_dist = tonumber(core.settings:get(self.setting .. ".water_distance")) or 6
		local lp = minetest.localplayer:get_pos()
		for _, sp in pairs(minetest.find_nodes_near(lp, range, {"mcl_sponges:sponge", "mcl_sponges:sponge_wet"})) do
			if not minetest.find_node_near(sp, water_dist, "mcl_core:water_source") then
				ws.dig(sp)
			end
		end
	end,
	cheat_settings = {
		range = { type = "number", default = 4, min = 1, max = 20 },
		water_distance = { type = "number", default = 6, min = 1, max = 20 },
	},
})

local chatscore = 0
local chatlimit = 10

local function chat(msg)
	if chatscore < chatlimit then
		minetest.send_chat_message(msg)
		chatscore = chatscore + 1
		minetest.after(5, function() chatscore = math.max(0, chatscore - 1) end)
	end
end

minetest.register_on_receiving_chat_message(function(message)
	if not is_spongebot then return end
	if message:find("greeferdude Left$") then
		chat(" I AM TEH GREEFADOOD HEET MA EVAL PROPER GANDER! WE ARE TEH SOLDIRS OFF ANACRY WE AR TOTALY NOD KINDAGARDN (WE ALRDY PRESKOOL). WE DO NOT FROGIV! EXCEPT UZ!")
	elseif message:find("^<greeferdude>") then
		if math.random(20) == 1 then
			chat("WE ARE TEH SOLDIRS OFF ANACRY WE AR TOTALY NOD KINDAGARDN (WE ALRDY PRESKOOL). WE DO NOT FROGIV! EXCEPT UZ!")
		end
	elseif message:find("^Burrowing_Owl Joined$") then
		chat("Hi!")
	elseif message:find("^Burrowing_Owl Left$") then
		chat("Another satisfied customer!")
	end
end)

local digcyl_mid
local digcyl_rad

minetest.register_chatcommand("digcyl", { func = function(p)
	local pos = minetest.string_to_pos(p)
	if pos then
		digcyl_mid = pos
		ws.dcm("digcyl mid set to " .. p)
	else
		digcyl_mid = ws.dircoord(0, 0, 0)
		ws.dcm("digcyl mid set to player pos")
	end
end})
minetest.register_chatcommand("digcyl_rad", { func = function(p)
	local n = tonumber(p)
	if n then
		digcyl_rad = n
		ws.dcm("digcyl rad set to " .. n)
	end
end})

ws.rg("Digcyl", { category = "Dig", setting = "digcyl",
	on_step = function(self)
		if not digcyl_mid or not digcyl_rad then return end
		local floor_y = tonumber(core.settings:get(self.setting .. ".floor_y")) or -125
		local lp = minetest.localplayer:get_pos()
		for _, v in pairs(minetest.find_nodes_near(lp, ws.range, nlist.get(nlist.selected), true)) do
			local n = minetest.get_node_or_nil(v)
			if v.y > floor_y and vector.distance(vector.new(v.x, 0, v.z), vector.new(digcyl_mid.x, 0, digcyl_mid.z)) < digcyl_rad and n and n.name ~= "air" then
				ws.dig(v)
			end
		end
	end,
	delay = 2,
	cheat_settings = {
		floor_y = { type = "number", default = -125, min = -31000, max = 31000 },
	},
})
