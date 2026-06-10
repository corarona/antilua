modpath = core.get_modpath(core.get_current_modname())

async = {}
lua_async = async

dofile(string.format("%s/async.lua", modpath))
