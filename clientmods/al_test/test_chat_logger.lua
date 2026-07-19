function test_chat_logger(T)
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

	T.run("chat_logger setting exists and can be toggled", function()
		local orig = core.settings:get_bool("chat_logging", false)
		core.settings:set_bool("chat_logging", true)
		T.assert(core.settings:get_bool("chat_logging", false),
			"chat_logging can be set to true")
		core.settings:set_bool("chat_logging", orig)
	end)

	T.run("register_on_connect exists", function()
		T.assert(type(core.register_on_connect) == "function",
			"core.register_on_connect is a function")
	end)

	T.defer("chat_logger writes chat.log via append_file", function()
		local esc = string.char(0x1b)
		local ts = os.date("%H:%M:%S")
		local sdir = core.get_serverdata_path()
		T.assert(type(sdir) == "string" and #sdir > 0,
			"serverdata_path is non-empty string")

		local test_log = sdir .. "/chat.log"

		T.assert(core.append_file(test_log,
			"\n--- Session started " .. os.date("%Y-%m-%d %H:%M:%S") .. " ---\n"),
			"append_file writes session start to chat.log")

		local test_msg = "ANTILUA_TEST_SENTINEL_" .. os.time()
		local colored = test_msg .. " " .. esc .. "(c@#FF0000)trailing"
		local stripped = core.strip_colors(colored)
		T.assert(core.append_file(test_log,
			"[" .. ts .. "] " .. stripped .. "\n"),
			"append_file writes color-stripped message")

		local ok, content = pcall(core.read_file, test_log)
		T.assert(ok, "chat.log readable")
		T.assert(content:find("Session started"),
			"chat.log contains session start marker")
		T.assert(content:find(test_msg),
			"chat.log contains the test message")
		T.assert(not content:find(esc .. "%("),
			"chat.log contains no color codes")

		local found_ts
		for line in content:gmatch("[^\n]+") do
			if line:find(test_msg, 1, true) then
				found_ts = line:match("^%[%d+:%d+:%d+%] ")
				break
			end
		end
		T.assert(found_ts,
			"logged message has [HH:MM:SS] timestamp prefix")

		core.write_file(test_log, "")
	end)
end
