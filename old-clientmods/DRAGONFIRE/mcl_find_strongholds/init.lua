local stronghold_rings = {
	-- amount: Number of strongholds in ring.
	-- min, max: Minimum and maximum distance from (X=0, Z=0).
	{ amount = 3, min = 1408, max = 2688 },
	{ amount = 6, min = 4480, max = 5760 },
	{ amount = 10, min = 7552, max = 8832 },
	{ amount = 15, min = 10624, max = 11904 },
	{ amount = 21, min = 13696, max = 14976 },
	{ amount = 28, min = 16768, max = 18048 },
	{ amount = 36, min = 19840, max = 21120 },
	{ amount = 9, min = 22912, max = 24192 },
}

local strongholds = {}
local mg_overworld_min = -128
local mg_bedrock_overworld_max = mg_overworld_min +4

local function init_strongholds(seed)
	local stronghold_positions = {}

	local pr = PseudoRandom(seed)
	for s=1, #stronghold_rings do
		local ring = stronghold_rings[s]

		-- Get random angle
		local angle = pr:next()
		-- Scale angle to 0 .. 2*math.pi
		angle = (angle / 32767) * (math.pi*2)
		for a=1, ring.amount do
			local dist = pr:next(ring.min, ring.max)
			local y = pr:next(mg_bedrock_overworld_max+1, mg_overworld_min+48)
			local pos = { x = math.cos(angle) * dist, y = y, z = math.sin(angle) * dist }
			pos = vector.round(pos)
			table.insert(stronghold_positions, pos)
			-- Rotate angle by (360 / amount) degrees.
			-- This will cause the angles to be evenly distributed in the stronghold ring
			angle = math.fmod(angle + ((math.pi*2) / ring.amount), math.pi*2)
		end
	end
	return stronghold_positions
end

minetest.register_chatcommand("find_strongholds",{
	params = "[<seed>]",
	description = "Returns a list of mcl* stronghold positions using the current or if specified the seed supplied in the first parameter.",
	func = function(p)
		local seed = tonumber(p)
		if not seed and not minetest.get_server_info().seed then
			minetest.display_chat_message("minetest.get_server_info().seed not available, try supplying the seed as an argument to this command. update dragonfire to automatically retrieve map seed.")
		elseif not seed then
			seed = tonumber(minetest.get_server_info().seed)
		end
		if not seed then minetest.display_chat_message("ERROR: seed must be a number.") return end

		local lp = minetest.localplayer:get_pos()
		local sp = init_strongholds(seed)
		table.sort(sp,function(a,b)
			return vector.distance(lp,a) < vector.distance(lp,b)
		end)
		if poi then
			poi.display(sp[1],"Closest stronghold")
		end
		minetest.display_chat_message("strongholds for seed "..string.format("%18.0f",seed)..":")
		minetest.display_chat_message("(sorted by distance from player)")
		local l = ""
		for _,v in ipairs(sp) do
			l=l.." "..minetest.pos_to_string(v)
		end
		minetest.display_chat_message(l)
		minetest.log("info",l)
	end,
})
