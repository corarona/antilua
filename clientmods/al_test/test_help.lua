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
end
