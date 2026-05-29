-- Dragonfire-specific callback registrations and utilities.
-- Loaded after register.lua — keeps DF additions separate from upstream.

local getinfo = debug.getinfo
local function make_df_registration()
	local t = {}
	local registerfunc = function(func)
		t[#t + 1] = func
		core.callback_origins[func] = {
			mod = core.get_current_modname() or "??",
			name = getinfo(1, "n").name or "??"
		}
	end
	return t, registerfunc
end

core.registered_on_recieve_physics_override, core.register_on_recieve_physics_override = make_df_registration()
core.registered_on_play_sound, core.register_on_play_sound = make_df_registration()
core.registered_on_spawn_particle, core.register_on_spawn_particle = make_df_registration()
core.registered_on_object_properties_change, core.register_on_object_properties_change = make_df_registration()
core.registered_on_object_hp_change, core.register_on_object_hp_change = make_df_registration()
core.registered_on_object_add, core.register_on_object_add = make_df_registration()
core.registered_on_receive_particlespawner, core.register_on_receive_particlespawner = make_df_registration()
core.registered_on_sending_inventory_fields, core.register_on_sending_inventory_fields = make_df_registration()
core.registered_on_sending_nodemeta_fields, core.register_on_sending_nodemeta_fields = make_df_registration()
core.registered_on_detached_inventory_update, core.register_on_detached_inventory_update = make_df_registration()
core.registered_on_receiving_inventory_form, core.register_on_receiving_inventory_form = make_df_registration()
core.registered_on_open_nodemeta_form, core.register_on_open_nodemeta_form = make_df_registration()

-- DF data tables
core.registered_nodes = {}
core.registered_items = {}
core.object_refs = {}

-- Client-side item override (mirrors server-side minetest.override_item)
function core.override_item(name, redefinition)
	if redefinition.name ~= nil then
		error("Attempt to redefine name of "..name.." to "..dump(redefinition.name), 2)
	end
	if redefinition.type ~= nil then
		error("Attempt to redefine type of "..name.." to "..dump(redefinition.type), 2)
	end
	local itemdef = core.get_item_def(name)
	if not itemdef then
		error("Attempt to override non-existent item "..name, 2)
	end
	local nodedef = core.get_node_def(name)
	table.combine(itemdef, nodedef)

	for k, v in pairs(redefinition) do
		rawset(itemdef, k, v)
	end
	core.register_item_raw(itemdef)
end
