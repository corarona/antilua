-- ParticleBlocker + ParticleSaver

local saved_textures = {}

local function matches_filter(texture, keyword_str)
	if keyword_str == "" then
		return true
	end
	local tex_lower = texture:lower()
	for keyword in keyword_str:gmatch("[^,]+") do
		local kw = keyword:match("^%s*(.-)%s*$")
		if kw ~= "" and tex_lower:find(kw) then
			return true
		end
	end
	return false
end

local texture_count = 0

core.register_on_receive_particlespawner(function(spawner)
	if texture_count > 500 then
		saved_textures = {}
		texture_count = 0
	end
	saved_textures[spawner.id] = spawner.texture
	texture_count = texture_count + 1
end)

core.register_on_spawn_particle(function(particle)
	if not core.settings:get_bool("particleblocker") then
		return
	end
	local keywords = core.settings:get("particleblocker.keywords") or ""
	if matches_filter(particle.texture, keywords) then
		return true
	end
end)

core.register_on_receive_particlespawner(function(spawner)
	if not core.settings:get_bool("particleblocker") then
		return
	end
	local block_spawners = core.settings:get_bool("particleblocker.block_spawners", true)
	if not block_spawners then
		return
	end
	local keywords = core.settings:get("particleblocker.keywords") or ""
	if matches_filter(spawner.texture, keywords) then
		return true
	end
end)

core.register_on_delete_particlespawner(function(server_id)
	local tex = saved_textures[server_id]
	saved_textures[server_id] = nil
	if not core.settings:get_bool("particlesaver") then
		return
	end
	local filter = core.settings:get("particlesaver.filter") or ""
	if filter == "" then
		return true
	end
	if tex and tex:lower():find(filter:lower()) then
		return true
	end
end)

core.register_cheat({ name = "ParticleBlocker", category = "Render",
	setting = "particleblocker",
	description = "Block particles by texture keyword (rain,snow,etc.)",
	cheat_settings = {
		keywords = { type = "string", default = "rain,snow" },
		block_spawners = { type = "bool", default = true },
	},
})

core.register_cheat({ name = "ParticleSaver", category = "Render",
	setting = "particlesaver",
	description = "Prevent particle spawners from being removed by the server",
	cheat_settings = {
		filter = { type = "string", default = "",
			options = {"", "portal", "aura", "fire", "smoke", "spell"} },
	},
})
