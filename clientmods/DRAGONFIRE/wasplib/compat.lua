-- CloakV4 compatibility shim: register_cheat_description
-- Stores a description string on the cheat def for tooltip rendering.
-- Compatible with both CloakV4's API and the help mod's README-based descriptions.

if not core.register_cheat_description then
	function core.register_cheat_description(name, category, setting, description)
		-- Create placeholder def if cheat hasn't registered yet
		if not core.cheat_defs[setting] then
			core.cheat_defs[setting] = {}
		end
		core.cheat_defs[setting].description = description
	end
end
