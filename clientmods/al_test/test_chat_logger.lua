function test_chat_logger(T)
	core.settings:set_bool("chat_logging", true)

	T.run("core.append_file exists", function()
		T.assert(type(core.append_file) == "function",
			"core.append_file should be a function")
	end)

	T.run("core.append_file writes and appends", function()
		local path = "/tmp/antilua_test_append.txt"
		core.write_file(path, "")
		T.assert(core.append_file(path, "line1\n"),
			"append_file returns true on first append")
		T.assert(core.append_file(path, "line2\n"),
			"append_file returns true on second append")
		local ok, data = pcall(core.read_file, path)
		T.assert(ok, "read_file succeeds")
		T.assert_eq(data, "line1\nline2\n", "append_file appends correctly")
		core.write_file(path, "")
	end)

	T.run("core.append_file rejects path traversal", function()
		local ok = core.append_file("../../evil.log", "pwned")
		T.assert(not ok, "append_file with '..' returns false")
	end)

	T.run("core.strip_colors strips escape color codes", function()
		local esc = string.char(0x1b)
		local raw = "hello " .. esc .. "(c@#FF0000)world"
		local stripped = core.strip_colors(raw)
		T.assert(not stripped:find(esc),
			"strip_colors removes escape sequences")
		T.assert(stripped:find("hello") and stripped:find("world"),
			"strip_colors keeps text content")
	end)

	T.run("register_on_receiving_chat_message callbacks exist", function()
		T.assert(type(core.registered_on_receiving_chat_message) == "table",
			"registered_on_receiving_chat_message is a table")
		T.assert(#core.registered_on_receiving_chat_message > 0,
			"at least one callback is registered")
	end)

	T.run("chat_logger setting can be read", function()
		T.assert(type(core.settings.get_bool) == "function",
			"core.settings.get_bool exists")
	end)

	T.run("register_on_connect exists", function()
		T.assert(type(core.register_on_connect) == "function",
			"core.register_on_connect is a function")
	end)

	T.defer("chat_logger produces non-empty chat.log with session start and messages", function()
		local esc = string.char(0x1b)
		local sdir = core.get_serverdata_path()
		T.assert(type(sdir) == "string" and #sdir > 0,
			"serverdata_path is non-empty string")

		local log_path = sdir .. "/chat.log"
		local ok, content = pcall(core.read_file, log_path)

		T.assert(ok, "chat.log exists — on_connect fired")
		T.assert(#content > 0, "chat.log is not empty")
		T.assert(content:find("Session started"),
			"chat.log contains session start marker")

		local test_msg = "ANTILUA_TEST_SENTINEL_" .. os.time()
		for _, cb in ipairs(core.registered_on_receiving_chat_message) do
			cb(test_msg)
		end

		local ok2, content2 = pcall(core.read_file, log_path)
		T.assert(ok2, "chat.log readable after message callbacks")
		T.assert(content2:find(test_msg),
			"chat.log contains the sentinel message written via callbacks")

		for line in content2:gmatch("[^\n]+") do
			if line:find(test_msg, 1, true) then
				T.assert(line:match("^%[%d+:%d+:%d+%] "),
					"logged message line has [HH:MM:SS] timestamp prefix")
				break
			end
		end

		core.log("action", "[AL_TEST] chat.log is " .. #content2 ..
			" bytes with " .. select(2, content2:gsub("\n", "\n")) .. " lines")
	end)
end
