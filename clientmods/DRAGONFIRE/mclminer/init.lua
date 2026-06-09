local mclminer_tgt
local tpactive

local function pos_ok(pos, lava_range)
	lava_range = lava_range or 10
	local p = core.find_node_near(pos, lava_range,
		{"mcl_core:lava_source","mcl_core:lava_flowing","mcl_nether:nether_lava_source","mcl_nether:nether_lava_flowing"}, true)
	return not p
end

local function get_miner_node(pos, search_range)
	search_range = search_range or 50
	local nds = core.find_nodes_near(pos, search_range, nlist.get(nlist.selected), true)
	table.sort(nds, function(a, b) return vector.distance(pos, a) < vector.distance(pos, b) end)
	for _, p in ipairs(nds) do
		if pos_ok(p) then
			return p
		end
	end
end

local function do_tp(tpos, tpstep)
	if tpactive then return end
	tpactive = true
	local lp = core.localplayer:get_pos()
	core.after(1, function(lp, tpos)
		if not pos_ok(tpos) then
			core.localplayer:set_pos(vector.offset(lp, 0, 25, 0))
			mclminer_tgt = nil
			tpactive = false
			ws.notify("LAVAAA", ws.NOTIFY_WARNING)
			core.settings:set_bool("mclminer", false)
			return
		end
		core.localplayer:set_pos(tpos)
		tpactive = false
	end, lp, tpos)
end

local function lavapanic()
	local head = vector.offset(core.localplayer:get_pos(), 0, 1, 0)
	local headnode = core.get_node_or_nil(head)
	if headnode and headnode.name:find("lava") then
		core.localplayer:set_pos(vector.offset(head, 0, 10, 0))
	end
end

sbots.register_bot("Mclminer", {
	find_pos = function(self, pos)
		local search_range = tonumber(core.settings:get("mclminer.search_range")) or 50
		mclminer_tgt = get_miner_node(pos, search_range)
		if mclminer_tgt then
			return mclminer_tgt
		end
	end,
	do_pos = function(self, pos)
		return true
	end,
	do_step = function(self, dtime)
		lavapanic()
		local lp = core.localplayer:get_pos()
		local hp = core.localplayer:get_hp()
		local tpstep = tonumber(core.settings:get("mclminer.tp_step")) or 3.8
		local min_hp = tonumber(core.settings:get("mclminer.min_hp")) or 15
		local lava_range = tonumber(core.settings:get("mclminer.lava_range")) or 10
		if hp < min_hp then return end

		if mclminer_tgt then
			local its = core.get_objects_inside_radius(lp, 2)
			for _, o in pairs(its) do
				local p = o:get_properties()
				if not o:is_local_player() and not p.wield_item then
					return
				end
			end
			local n = core.get_node_or_nil(mclminer_tgt)
			if n and n.name == "air" then
				mclminer_tgt = nil
				return
			end
			local tpos = vector.offset(mclminer_tgt, 0, -1, 0)
			if not tpactive and vector.distance(lp, tpos) > tpstep then
				local tppos = vector.add(lp, vector.multiply(vector.direction(lp, tpos), tpstep))
				do_tp(tppos, tpstep)
			elseif not tpactive and pos_ok(tpos, lava_range) then
				do_tp(tpos, tpstep)
			else
				do_tp(vector.offset(lp, 0, 25, 0), tpstep)
			end
		end
	end,
	on_activate = function(self)
		core.settings:set_bool("autoeat", true)
		core.settings:set_bool("dighead", true)
		mclminer_tgt = nil
	end,
	landing_distance = 0,
	stand_waiting = false,
	delay = 0.2,
	cheat_settings = {
		tp_step = { type = "number", default = 3.8, min = 1, max = 20 },
		min_hp = { type = "number", default = 15, min = 1, max = 40 },
		lava_range = { type = "number", default = 10, min = 1, max = 50 },
		search_range = { type = "number", default = 50, min = 5, max = 200 },
	},
})
