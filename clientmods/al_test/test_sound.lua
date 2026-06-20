-- Tests for sound_play API (recently wired up)

function test_sound_api(T)
	-- Test that core.sound_play exists and returns something
	T.run("core.sound_play exists", function()
		T.assert(type(core.sound_play) == "function", "sound_play should be a function")
	end)

	-- Test that sound_play returns a userdata handle (or nil if dummy backend)
	T.defer("core.sound_play returns handle", function()
		local handle = core.sound_play({ name = "" }, { gain = 0 })
		T.assert(handle ~= nil, "sound_play should return a value")
	end)

	-- Local sound (no position)
	T.defer("core.sound_play local sound", function()
		local handle = core.sound_play({ name = "" }, { gain = 0 })
		if handle then
			T.assert(type(handle.stop) == "function", "handle should have :stop()")
			T.assert(type(handle.fade) == "function", "handle should have :fade()")
		end
	end)

	-- Positional sound
	T.defer("core.sound_play positional sound", function()
		local pos = core.localplayer:get_pos()
		local handle = core.sound_play(
			{ name = "" },
			{ gain = 0, pos = pos }
		)
		if handle then
			T.assert(type(handle.stop) == "function", "positional handle should have :stop()")
		end
	end)

	-- :stop() should not error
	T.defer("core.sound_play handle:stop()", function()
		local handle = core.sound_play({ name = "" }, { gain = 0 })
		if handle then
			local ok, err = pcall(function() handle:stop() end)
			T.assert(ok, "handle:stop() should not error: " .. tostring(err))
		end
	end)

	-- :fade() should not error
	T.defer("core.sound_play handle:fade()", function()
		local handle = core.sound_play({ name = "" }, { gain = 0 })
		if handle then
			local ok, err = pcall(function() handle:fade(-1, 0) end)
			T.assert(ok, "handle:fade() should not error: " .. tostring(err))
		end
	end)

	-- debug_print_playing_sounds exists
	T.run("core.debug_print_playing_sounds exists", function()
		T.assert(type(core.debug_print_playing_sounds) == "function",
			"debug_print_playing_sounds should be a function")
	end)
end
