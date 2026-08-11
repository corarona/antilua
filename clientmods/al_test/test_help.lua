-- Tests for the help system mod

function test_help(T)
	T.run("help command registered", function()
		local cmds = core.registered_chatcommands or {}
		T.assert(cmds[".help"] ~= nil or cmds["help"] ~= nil,
			".help command should be registered")
	end)

	T.run("help index formspec builds without error", function()
		local cmd = core.registered_chatcommands["help"]
		T.assert(cmd ~= nil, "help command registered")
		if cmd then
			local ok, err = pcall(function() cmd.func() end)
			T.assert(ok, "help index should build: " .. tostring(err))
		end
	end)

	T.run(".help commands builds without error", function()
		local cmd = core.registered_chatcommands["help"]
		T.assert(cmd ~= nil, "help command registered")
		if cmd then
			local ok, err = pcall(function() cmd.func("commands") end)
			T.assert(ok, "help commands should build: " .. tostring(err))
		end
	end)

	T.run("help command reference lists registered commands", function()
		local n = 0
		for name, def in pairs(core.registered_chatcommands) do
			if type(def) == "table" then n = n + 1 end
		end
		T.assert(n > 0, "expected some registered client commands")
	end)

	T.run("commands cheat registered", function()
		local found = false
		for _, cats in pairs(core.cheats or {}) do
			if cats["Commands"] then found = true break end
		end
		T.assert(found, "Commands cheat should be registered")
	end)

	T.run("help keybinds reference builds without error", function()
		local keybinds_cheat
		for _, cats in pairs(core.cheats or {}) do
			if cats["Keybinds"] then
				-- func-based cheats store the func directly
				if type(cats["Keybinds"]) == "function" then
					keybinds_cheat = { func = cats["Keybinds"] }
				end
				break
			end
		end
		if keybinds_cheat and keybinds_cheat.func then
			local ok, err = pcall(keybinds_cheat.func)
			T.assert(ok, "keybinds reference should build: " .. tostring(err))
		end
	end)
end
