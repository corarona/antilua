local sb_state = 0
local sb_target = nil
local sb_startpos
local is_spongebot = false
math.randomseed(os.clock())

local function override_prediction(enable)
	for k, v in pairs(core.registered_items) do
		core.override_item(k, { node_placement_prediction = enable and "" or nil })
	end
end

ws.on_connect(function()
	if core.settings:get_bool("autoclog") then
		is_spongebot = true
		local lp = core.localplayer:get_pos()
		core.localplayer:set_pos(vector.new(lp.x, lp.y + 30, lp.z))
	end
end)

local function find_closest(ndnames, range)
	range = range or ws.range
	local lp = ws.dircoord(0, 0, 0)
	local nds = core.find_nodes_near(lp, range, ndnames, true)
	local odst = 100
	local rt = nil
	for _, v in ipairs(nds) do
		local dst = vector.distance(lp, v)
		if dst < odst and v.y > 1 then odst = dst rt = v end
	end
	if not rt then
		core.settings:set_bool("continuous_forward", false)
		if core.sound_play then
			core.sound_play("mcl_bells_bell_stroke", { pitch = 1.5, gain = 1.5 })
		end
		core.settings:set_bool("spongebot", false)
	end
	return rt, odst
end

local function checknode(pos)
	if pos then
		local tn = core.get_node_or_nil(pos)
		if tn and tn.name ~= "air" then return true end
	end
end

ws.rg("SpongeBot", { category = "Bots", setting = "spongebot",
	on_step = function(self)
		local dst = 200
		local lp = core.localplayer:get_pos()
		if sb_state == 0 then
			sb_target, dst = find_closest({"mcl_core:water_source"}, 50)
			if checknode(sb_target) then
				local blk = core.find_nodes_in_area(
					ws.dircoord(0, -1, 0), ws.dircoord(1, 2, 0),
					{'mcl_core:bedrock', 'mcl_core:obsidian'})
				if blk and #blk > 0 then
					core.localplayer:set_pos(ws.dircoord(math.random(-1, 1), 2, math.random(-1, 1)))
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
			core.settings:set_bool("continuous_forward", false)
			ws.dig(sb_target)
		else
			core.settings:set_bool("continuous_forward", true)
		end
	end,
	on_start = function(self)
		sb_state = 0
		sb_target = nil
		math.randomseed(os.clock())
		sb_startpos = core.localplayer:get_pos()
		override_prediction(true)
		core.settings:set_bool("pitch_move", true)
		core.settings:set_bool("free_move", true)
		core.settings:set_bool("autosponge", true)
		core.settings:set_bool("autoclog", true)
		core.settings:set_bool("autoeat", true)
	end,
	on_stop = function(self)
		override_prediction(false)
		core.settings:set_bool("pitch_move", false)
	end,
	cheat_settings = {
		search_range = { type = "number", default = 50, min = 5, max = 200 },
		travel_range = { type = "number", default = 200, min = 10, max = 500 },
	},
})

ws.rg("Autosponge", { category = "Place", setting = "autosponge",
	on_step = function(self)
		local range = tonumber(core.settings:get(self.setting .. ".range")) or 10
		local water = core.find_node_near(core.localplayer:get_pos(), range, "mcl_core:water_source")
		if water then
			ws.place(water, "mcl_sponges:sponge")
		end
	end,
	cheat_settings = {
		range = { type = "number", default = 10, min = 1, max = 50 },
	},
})



local chatscore = 0
local chatlimit = 10

local function chat(msg)
	if chatscore < chatlimit then
		core.send_chat_message(msg)
		chatscore = chatscore + 1
		core.after(5, function() chatscore = math.max(0, chatscore - 1) end)
	end
end

-- (spongebot chat responses removed for public release)

