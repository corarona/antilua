-- Antilua
-- SPDX-License-Identifier: LGPL-2.1-or-later
--
-- Server-side mod reloading support.
-- Provides cleanup functions and a chat command for reloading server mods
-- without restarting the engine (singleplayer and dedicated server).

-- Save original registration functions before register.lua neutralizes them.
-- These are restored during mod reload so the mod's init.lua can re-register
-- items, ABMs, LBMs, and aliases.
local orig_register_abm = core.register_abm
local orig_register_lbm = core.register_lbm
local orig_register_item = core.register_item
local orig_unregister_item = core.unregister_item
local orig_register_alias = core.register_alias
local orig_register_alias_force = core.register_alias_force
local orig_register_on_mapblocks_changed = core.register_on_mapblocks_changed

-- Factory for neutralized function stubs (matches register.lua's generic_reg_error)
local function neutralize_fn(what)
	return function(something)
		local described = what
		if type(something) == "table" and type(something.name) == "string" then
			described = what .. " " .. something.name
		elseif type(something) == "string" then
			described = what .. " " .. something
		end
		error("Tried to register " .. described .. " after load time!")
	end
end

local function unfreeze_table(t)
	local mt = getmetatable(t)
	if mt and mt.__newindex then
		mt.__newindex = nil
	end
end

local function refreeze_table(t)
	local mt = table.copy(getmetatable(t) or {})
	mt.__newindex = function()
		error("modification forbidden")
	end
	setmetatable(t, mt)
end

core.unfreeze_registration_tables = function()
	unfreeze_table(core.registered_abms)
	unfreeze_table(core.registered_lbms)
	unfreeze_table(core.registered_items)
	unfreeze_table(core.registered_nodes)
	unfreeze_table(core.registered_craftitems)
	unfreeze_table(core.registered_tools)
	unfreeze_table(core.registered_aliases)
	unfreeze_table(core.registered_on_mapblocks_changed)

	-- Restore original registration functions
	core.register_abm = orig_register_abm
	core.register_lbm = orig_register_lbm
	core.register_item = orig_register_item
	core.unregister_item = orig_unregister_item
	core.register_alias = orig_register_alias
	core.register_alias_force = orig_register_alias_force
	core.register_on_mapblocks_changed = orig_register_on_mapblocks_changed
end

core.refreeze_registration_tables = function()
	refreeze_table(core.registered_abms)
	refreeze_table(core.registered_lbms)
	refreeze_table(core.registered_items)
	refreeze_table(core.registered_nodes)
	refreeze_table(core.registered_craftitems)
	refreeze_table(core.registered_tools)
	refreeze_table(core.registered_aliases)
	refreeze_table(core.registered_on_mapblocks_changed)

	-- Re-neutralize registration functions
	core.register_abm = neutralize_fn("ABM")
	core.register_lbm = neutralize_fn("LBM")
	core.register_item = neutralize_fn("item")
	core.unregister_item = function(name)
		error("Refusing to unregister item " .. name .. " after load time")
	end
	core.register_alias = neutralize_fn("alias")
	core.register_alias_force = neutralize_fn("alias")
	core.register_on_mapblocks_changed = neutralize_fn("on_mapblocks_changed callback")
end

function core.cleanup_server_mod(modname)
	-- Remove callbacks from all registered_on_* tables
	for k, v in pairs(core) do
		if type(v) == "table" and k:match("^registered_on_") then
			for i = #v, 1, -1 do
				local origin = core.callback_origins[v[i]]
				if origin and origin.mod == modname then
					core.callback_origins[v[i]] = nil
					table.remove(v, i)
				end
			end
		end
	end

	-- Special case: registered_on_player_hpchanges has modifiers/loggers
	if core.registered_on_player_hpchanges then
		for _, subt in ipairs({"modifiers", "loggers"}) do
			local t = core.registered_on_player_hpchanges[subt]
			if t then
				for i = #t, 1, -1 do
					local origin = core.callback_origins[t[i]]
					if origin and origin.mod == modname then
						core.callback_origins[t[i]] = nil
						table.remove(t, i)
					end
				end
			end
		end
	end

	-- Remove ABMs registered by this mod
	for i = #core.registered_abms, 1, -1 do
		if core.registered_abms[i].mod_origin == modname then
			table.remove(core.registered_abms, i)
		end
	end

	-- Remove LBMs registered by this mod
	for i = #core.registered_lbms, 1, -1 do
		if core.registered_lbms[i].mod_origin == modname then
			table.remove(core.registered_lbms, i)
		end
	end

	-- Remove entities registered by this mod, warn about live instances
	local prefix = modname .. ":"
	for name, proto in pairs(core.registered_entities) do
		if name:sub(1, #prefix) == prefix then
			local live_count = 0
			for _, inst in pairs(core.luaentities) do
				if getmetatable(inst) == proto then
					live_count = live_count + 1
				end
			end
			if live_count > 0 then
				core.log("warning", "[reload] " .. name .. " has " .. live_count ..
					" live entity instance(s) — they may have stale state")
			end
			core.registered_entities[name] = nil
		end
	end

	-- Remove items/nodes/tools/craftitems registered by this mod
	for name in pairs(core.registered_items) do
		if name:sub(1, #prefix) == prefix then
			core.registered_nodes[name] = nil
			core.registered_craftitems[name] = nil
			core.registered_tools[name] = nil
			core.registered_items[name] = nil
		end
	end

	-- Remove aliases pointing to this mod's items
	for alias, target in pairs(core.registered_aliases) do
		if target:sub(1, #prefix) == prefix then
			core.registered_aliases[alias] = nil
		end
	end

	-- Remove chat commands registered by this mod
	if core.registered_chatcommands then
		for cmd, def in pairs(core.registered_chatcommands) do
			if def.mod_origin == modname then
				core.registered_chatcommands[cmd] = nil
			end
		end
	end

	-- Remove biomes/ores/decorations registered by this mod
	-- Note: this does NOT update the C++ BiomeManager/OreManager.
	-- Those remain unchanged until a full restart.
	if core.registered_biomes then
		for k in pairs(core.registered_biomes) do
			if type(k) == "string" and k:sub(1, #prefix) == prefix then
				core.registered_biomes[k] = nil
			end
		end
	end
	if core.registered_ores then
		for k in pairs(core.registered_ores) do
			if type(k) == "string" and k:sub(1, #prefix) == prefix then
				core.registered_ores[k] = nil
			end
		end
	end
	if core.registered_decorations then
		for k in pairs(core.registered_decorations) do
			if type(k) == "string" and k:sub(1, #prefix) == prefix then
				core.registered_decorations[k] = nil
			end
		end
	end

	-- Remove privileges registered by this mod
	if core.registered_privileges then
		for priv, def in pairs(core.registered_privileges) do
			if def.mod_origin == modname then
				core.registered_privileges[priv] = nil
			end
		end
	end

	-- Remove detached inventories registered by this mod
	if core.detached_inventories then
		for inv_name in pairs(core.detached_inventories) do
			if inv_name:sub(1, #prefix) == prefix then
				core.detached_inventories[inv_name] = nil
			end
		end
	end
end

-- Chat command for reloading server mods
core.register_chatcommand("reload_server_mod", {
	params = "<modname>",
	description = "Reload a server-side mod without restarting."
		.. " Only re-registers callbacks, ABMs, and item definitions."
		.. " Existing entity instances may have stale state."
		.. " Craft recipes and biome/ore/decorations are not updated.",
	privs = {server = true},
	func = function(name, param)
		local modname = param:match("^%s*(.-)%s*$")
		if not modname or modname == "" then
			return false, "Usage: /reload_server_mod <modname>"
		end
		local ok, err = pcall(core.reload_server_mod, modname)
		if ok then
			return true, "Mod '" .. modname .. "' reloaded successfully."
		else
			return false, "Reload failed: " .. tostring(err)
		end
	end,
})
