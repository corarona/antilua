local is_spongebot = false

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

local function checknode(pos)
	if pos then
		local tn = core.get_node_or_nil(pos)
		if tn and tn.name ~= "air" then return true end
	end
end

sbots.register_bot("SpongeBot", {
	find_pos = function(self, pos)
		local lp = ws.dircoord(0, 0, 0)
		local nds = core.find_nodes_near(lp, 50, {"mcl_core:water_source"}, true)
		local closest, min_dst
		for _, v in ipairs(nds) do
			local dst = vector.distance(lp, v)
			if dst < (min_dst or math.huge) and v.y > 1 then
				closest = v
				min_dst = dst
			end
		end
		if not closest then
			if core.sound_play then
				core.sound_play("mcl_bells_bell_stroke", { pitch = 1.5, gain = 1.5 })
			end
			return nil
		end
		return closest
	end,
	do_pos = function(self, pos)
		if checknode(self.target_pos) then
			ws.dig(self.target_pos)
		end
		return true
	end,
	do_step = function(self, dtime)
		-- Keep moving while searching or approaching target
		if self.stage ~= 2 then
			core.settings:set_bool("continuous_forward", true)
		end
		-- Bedrock/obsidian check: teleport out if stuck
		local blk = core.find_nodes_in_area(
			ws.dircoord(0, -1, 0), ws.dircoord(1, 2, 0),
			{'mcl_core:bedrock', 'mcl_core:obsidian'})
		if blk and #blk > 0 then
			core.localplayer:set_pos(ws.dircoord(math.random(-1, 1), 2, math.random(-1, 1)))
		end
		-- Check if target still exists
		if self.stage == 1 and self.target_pos and not checknode(self.target_pos) then
			self.stage = 0
		end
	end,
	on_activate = function(self)
		math.randomseed(os.clock())
		override_prediction(true)
		core.settings:set_bool("autosponge", true)
		core.settings:set_bool("autoclog", true)
		core.settings:set_bool("autoeat", true)
	end,
	on_deactivate = function(self)
		override_prediction(false)
	end,
	landing_distance = 1,
	stand_waiting = false,
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

