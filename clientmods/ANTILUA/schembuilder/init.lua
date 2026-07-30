local modpath = core.get_modpath(core.get_current_modname())

-- Forward declarations for optional mapart integration
handle_mapart_events = nil
get_mapart_tab = nil
schembuilder_api = nil

schembuilder = {pos1={x=nil,y=nil,z=nil}, pos2={x=nil,y=nil,z=nil}}
place_nodes = {}
place_nodes_total = 0
supply_chests = {}

storage = nil
if type(core.get_mod_storage) == "function" then
	local ok, mod = pcall(core.get_mod_storage, "schembuilder")
	if ok then storage = mod end
end

current_build_id = nil

dofile(modpath .. "/storage.lua")
dofile(modpath .. "/preview.lua")
dofile(modpath .. "/loader.lua")
dofile(modpath .. "/place_common.lua")
dofile(modpath .. "/hud.lua")
dofile(modpath .. "/formspec.lua")
dofile(modpath .. "/serialize.lua")
dofile(modpath .. "/shapes.lua")
dofile(modpath .. "/commands.lua")
dofile(modpath .. "/bot.lua")
dofile(modpath .. "/rhythmbot.lua")
dofile(modpath .. "/looter.lua")
dofile(modpath .. "/init_api.lua")
