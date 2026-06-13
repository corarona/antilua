-- AutoMiner: automated mining bot
-- Finds nearest target node from nlist, jump-teleports toward it via rhythmtp,
-- digs the node before teleporting to its position (avoids noclip damage).

local lava_nodes_list

local function parse_lava_nodes()
	local s = core.settings:get("autominer.lava_nodes")
	if s and s ~= "" then
		lava_nodes_list = s:split(",")
	else
		lava_nodes_list = {}
	end
end

local function pos_ok(pos, lava_range)
	lava_range = lava_range or 10
	local p = core.find_node_near(pos, lava_range, lava_nodes_list, true)
	return not p
end

local function lavapanic()
	local head = vector.offset(core.localplayer:get_pos(), 0, 1, 0)
	local headnode = core.get_node_or_nil(head)
	if headnode and headnode.name:find("lava") then
		core.localplayer:set_pos(vector.offset(head, 0, 10, 0))
	end
end

local function get_reach()
	local reach = core.settings:get("reach")
	if reach then
		return tonumber(reach) or 10
	end
	return 10
end

sbots.register_bot("AutoMiner", {
	description = "Bot that mines ores automatically",
	movement = "teleport",
	find_pos = function(self, pos)
		parse_lava_nodes()
		local search_range = tonumber(core.settings:get("autominer.search_range")) or 50
		self.target = sbots.find_nearest(pos, search_range, nlist.get(nlist.selected), pos_ok)
		return self.target
	end,
	do_pos = function(self, pos)
		return true
	end,
	do_step = function(self, dtime)
		lavapanic()
		local lp = core.localplayer:get_pos()
		local hp = core.localplayer:get_hp()
		local min_hp = tonumber(core.settings:get("autominer.min_hp")) or 15

		if hp < min_hp then return end

		-- After digging: wait until all dropped items are picked up
		if self.pickup_wait then
			local objects = core.get_objects_inside_radius(lp, 4)
			local has_items = false
			for _, obj in ipairs(objects) do
				if not obj:is_player() then
					local props = obj:get_properties()
					if props.visual == "wielditem" or props.visual == "sprite" then
						has_items = true
						break
					end
				end
			end
			if has_items then
				return
			end
			self.pickup_wait = false
			self.stage = 0
			return
		end

		if self.target then
			-- Entity proximity check
			local its = core.get_objects_inside_radius(lp, 2)
			for _, o in pairs(its) do
				local p = o:get_properties()
				if not o:is_local_player() and not p.wield_item then
					return
				end
			end

			-- Target still exists?
			local n = core.get_node_or_nil(self.target)
			if n and n.name == "air" then
				self.target = nil
				self.stage = 0
				return
			end

			local dist = vector.distance(lp, self.target)
			local reach = get_reach()

			if dist <= reach then
				-- Dig first, then teleport below so head is in the air pocket
				local tpos = self.target
				ws.dig(tpos)
				core.localplayer:set_pos(vector.offset(tpos, 0, -1, 0))
				self.target = nil
				self.pickup_wait = true
			end
			-- Movement (stage 1) is handled by the sbots teleport strategy
		end
	end,
	on_activate = function(self)
		core.settings:set_bool("autoeat", true)
		core.settings:set_bool("dighead", true)
		parse_lava_nodes()
		self.target = nil
	end,
	landing_distance = 0,
	stand_waiting = false,
	delay = 0.2,
	cheat_settings = {
		lava_nodes = { type = "string", default = "mcl_core:lava_source,mcl_core:lava_flowing,mcl_nether:nether_lava_source,mcl_nether:nether_lava_flowing,default:lava_source,default:lava_flowing" },
		tp_step = { type = "number", default = 3.8, min = 1, max = 20 },
		min_hp = { type = "number", default = 15, min = 1, max = 40 },
		lava_range = { type = "number", default = 10, min = 1, max = 50 },
		search_range = { type = "number", default = 50, min = 5, max = 200 },
	},
})
