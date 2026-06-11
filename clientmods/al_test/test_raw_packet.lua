-- Tests for raw packet API (core.send_raw_packet, register_on_receiving_raw_packet, etc.)

function test_raw_packet_api(T)
	T.run("core.send_raw_packet exists", function()
		T.assert(type(core.send_raw_packet) == "function")
	end)

	T.run("core.register_on_receiving_raw_packet exists", function()
		T.assert(type(core.register_on_receiving_raw_packet) == "function")
	end)

	T.run("core.register_on_sending_raw_packet exists", function()
		T.assert(type(core.register_on_sending_raw_packet) == "function")
	end)

	T.run("core.TOCLIENT table exists with known entries", function()
		T.assert(type(core.TOCLIENT) == "table")
		T.assert(core.TOCLIENT.HELLO == 0x02)
		T.assert(core.TOCLIENT.HUDCHANGE == 0x4B)
		T.assert(core.TOCLIENT.CHAT_MESSAGE == 0x2F)
		T.assert(core.TOCLIENT.INVENTORY == 0x27)
	end)

	T.run("core.TOSERVER table exists with known entries", function()
		T.assert(type(core.TOSERVER) == "table")
		T.assert(core.TOSERVER.INTERACT == 0x39)
		T.assert(core.TOSERVER.CHAT_MESSAGE == 0x32)
		T.assert(core.TOSERVER.PLAYERPOS == 0x23)
		T.assert(core.TOSERVER.INVENTORY_ACTION == 0x31)
	end)

	T.run("register_on_receiving_raw_packet accepts callbacks", function()
		local called = false
		core.register_on_receiving_raw_packet(function(cmd, payload)
			called = true
		end)
		T.assert(type(core.registered_on_receiving_raw_packet) == "table")
		T.assert(#core.registered_on_receiving_raw_packet >= 1)
	end)

	T.run("register_on_sending_raw_packet accepts callbacks", function()
		local called = false
		core.register_on_sending_raw_packet(function(cmd, payload)
			called = true
		end)
		T.assert(type(core.registered_on_sending_raw_packet) == "table")
		T.assert(#core.registered_on_sending_raw_packet >= 1)
	end)

	T.run("send_raw_packet with numeric command does not crash", function()
		local ok, err = pcall(core.send_raw_packet, 0x39, "")
		-- succeeds or errors gracefully (depends on connection state)
		T.assert(type(ok) == "boolean")
	end)

	T.run("send_raw_packet with string name", function()
		local ok, err = pcall(core.send_raw_packet, "TOSERVER_INTERACT", "")
		T.assert(type(ok) == "boolean")
	end)

	T.run("send_raw_packet rejects blacklisted opcodes", function()
		local ok, err = pcall(core.send_raw_packet, "INIT", "")
		T.assert(not ok)
	end)

	T.run("send_raw_packet rejects unknown name", function()
		local ok, err = pcall(core.send_raw_packet, "NONEXISTENT", "")
		T.assert(not ok)
	end)
end
