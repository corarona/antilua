-- AutoMiner: automated mining bot
-- Finds nearest target node from nlist, jump-teleports toward it via rhythmtp,
-- digs the node before teleporting to its position (avoids noclip damage).

local autominer_tgt
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

local function find_nearest_target(pos, search_range)
	local nds = core.find_nodes_near(pos, search_range, nlist.get(nlist.selected), true)
	if not nds or #nds == 0 then
		return nil
	end
	table.sort(nds, function(a, b) return vector.distance(pos, a) < vector.distance(pos, b) end)
	for _, p in ipairs(nds) do
		if pos_ok(p) then
			return p
		end
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
	find_pos = function(self, pos)
		parse_lava_nodes()
		local search_range = tonumber(core.settings:get("autominer.search_range")) or 50
		autominer_tgt = find_nearest_target(pos, search_range)
		if autominer_tgt then
			return autominer_tgt
		end
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

		if autominer_tgt then
			-- Entity proximity check
			local its = core.get_objects_inside_radius(lp, 2)
			for _, o in pairs(its) do
				local p = o:get_properties()
				if not o:is_local_player() and not p.wield_item then
					return
				end
			end

			-- Target still exists?
			local n = core.get_node_or_nil(autominer_tgt)
			if n and n.name == "air" then
				autominer_tgt = nil
				self.stage = 0
				return
			end

			local dist = vector.distance(lp, autominer_tgt)
			local reach = get_reach()

			if dist <= reach then
				-- Dig first, then teleport into the now-empty space
				local tpos = autominer_tgt
				ws.dig(tpos)
				-- Place feet one below the ore so head is in the air pocket
				core.localplayer:set_pos(vector.offset(tpos, 0, -1, 0))
				autominer_tgt = nil
				self.stage = 0
			elseif not rhythmtp.is_moving() then
				ws.aim(autominer_tgt)
				rhythmtp.go_to(vector.offset(autominer_tgt, 0, -1, 0))
			end
		end
	end,
	on_activate = function(self)
		core.settings:set_bool("autoeat", true)
		core.settings:set_bool("dighead", true)
		parse_lava_nodes()
		autominer_tgt = nil
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
