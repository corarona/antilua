modpath = minetest.get_modpath("async")

async = {}

dofile(string.format("%s/async.lua", modpath))
