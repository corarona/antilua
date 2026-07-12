local target = nil
local remaining = 0

local function punch()
	if not target or not core.localplayer then target = nil; return end
	if not target:get_pos() then target = nil; return end
	target:punch()
	remaining = remaining - 1
	if remaining > 0 then core.after(0.05, punch) end
end

ws.rg("Killaura", {
	category = "Combat",
	setting = "killaura",
	description = "Auto-attack nearby entities",
	on_step = function()
		core.log("loL")
		local lp = core.localplayer:get_pos()
		if not lp then return end
		local range = tonumber(core.settings:get("killaura.range")) or 5
		local hit_mobs = core.settings:get_bool("killaura.attack_mobs")
		local best, best_d = nil, math.huge

		for _, obj in pairs(core.get_objects_inside_radius(lp, range)) do
			if obj and not obj:is_local_player() then
				local ok = obj:is_player()
				if not ok and hit_mobs then
					local name = obj:get_name() or ""
					ok = name:find("mobs_mc:") == 1 or name:find("extra_mobs:") == 1
				end
				if ok then
					local d = vector.distance(lp, obj:get_pos())
					if d < best_d then best, best_d = obj, d end
				end
			end
		end

		if best then
			if target ~= best then remaining = 0; target = best end
			if remaining == 0 then remaining = 8; core.after(0, punch) end
		end
	end,
	cheat_settings = {
		range = { type = "number", default = 5, min = 1, max = 30 },
		attack_mobs = { type = "bool", default = false },
	},
})
