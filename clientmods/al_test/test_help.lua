-- Tests for the help system mod

function test_help(T)
	T.run("help command registered", function()
		local cmds = core.registered_chatcommands or {}
		T.assert(cmds[".help"] ~= nil or cmds["help"] ~= nil,
			".help command should be registered")
	end)
end
