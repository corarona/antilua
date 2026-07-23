-- Antilua: builtin/client/init.lua
local scriptpath = core.get_builtin_path()
local clientpath = scriptpath.."client"..DIR_DELIM
local commonpath = scriptpath.."common"..DIR_DELIM

local builtin_shared = {}
assert(loadfile(commonpath .. "register.lua"))(builtin_shared)
assert(loadfile(clientpath .. "register.lua"))(builtin_shared)
dofile(clientpath .. "register_al.lua")
dofile(commonpath .. "after.lua")
assert(loadfile(commonpath .. "item_s.lua"))({})
dofile(commonpath .. "chatcommands.lua")
dofile(commonpath .. "vector.lua")
dofile(commonpath .. "voxelarea.lua")
dofile(clientpath .. "util.lua")
dofile(clientpath .. "chatcommands.lua")
dofile(clientpath .. "chatcommands_al.lua")
dofile(clientpath .. "death_formspec.lua")
dofile(clientpath .. "cheats.lua")
dofile(clientpath .. "misc.lua")

-- unset, as promised in initializeSecurityClient()
debug.getinfo = nil

