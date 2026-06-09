-- Tests for witherbot mod

function test_witherbot(T)
	local cheats = {"safeaura", "selkillaura", "evade_wither", "autoevade",
		"ObsBot", "PlBot", "CrystalBot", "MobsBot", "HostileMobs", "ItemBot"}

	for _, name in ipairs(cheats) do
		T.run(name .. " cheat setting exists", function()
			T.assert(core.settings:get(name) ~= nil)
		end)
	end

	T.run("safeaura.range default exists", function()
		local v = core.settings:get("safeaura.range")
		T.assert(v ~= nil)
		T.assert(tonumber(v) == 5)
	end)

	T.run("selkillaura.range default exists", function()
		local v = core.settings:get("selkillaura.range")
		T.assert(v ~= nil)
		T.assert(tonumber(v) == 4)
	end)

	T.run("evade_wither.range default exists", function()
		local v = core.settings:get("evade_wither.range")
		T.assert(v ~= nil)
	end)

	T.run("autoevade defaults exist", function()
		T.assert(core.settings:get("autoevade.scan_range") ~= nil)
		T.assert(core.settings:get("autoevade.trigger_distance") ~= nil)
		T.assert(core.settings:get("autoevade.evade_distance") ~= nil)
	end)

	T.run("SafeAura registered in Combat category", function()
		local combat = core.cheats["Combat"]
		T.assert(combat ~= nil)
		local found = false
		for name, _ in pairs(combat) do
			if name:lower() == "safeaura" then found = true; break end
		end
		T.assert(found)
	end)

	T.run("bots registered in Bots category", function()
		local bots = core.cheats["Bots"]
		T.assert(bots ~= nil)
		for _, name in ipairs({"ObsBot", "PlBot", "CrystalBot", "MobsBot", "HostileMobs", "ItemBot"}) do
			local found = false
			for n, _ in pairs(bots) do
				if n:lower() == name:lower() then found = true; break end
			end
			T.assert(found, name .. " found in Bots")
		end
	end)
end
