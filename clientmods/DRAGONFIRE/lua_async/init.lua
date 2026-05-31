modpath = minetest.get_modpath(minetest.get_current_modname())

async = {}
lua_async = async

dofile(string.format("%s/async.lua", modpath))
