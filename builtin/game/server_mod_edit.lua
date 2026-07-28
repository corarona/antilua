-- Antilua
-- SPDX-License-Identifier: LGPL-2.1-or-later
--
-- Server-side mod channel handler for DTE's "Server mods" tab.
-- Provides file read/write/list and mod reload over mod channel "al_srvedit".

local mod_channel

local function send_response(data)
	if mod_channel and mod_channel:is_writeable() then
		mod_channel:send_all(core.serialize(data))
	end
end

core.register_on_modchannel_message(function(channel, sender, msg)
	if channel ~= "al_srvedit" then
		return
	end

	local ok, req = pcall(core.deserialize, msg)
	if not ok or type(req) ~= "table" then
		return
	end

	if not core.check_player_privs(sender, {server = true}) then
		send_response({
			req_id = req.req_id,
			type = "error",
			msg = "server priv required",
		})
		return
	end

	if req.type == "list_mods" then
		local mods = {}
		for _, name in ipairs(core.get_modnames()) do
			mods[#mods + 1] = {
				name = name,
				path = core.get_modpath(name),
			}
		end
		send_response({req_id = req.req_id, type = "mod_list", mods = mods})

	elseif req.type == "list_files" then
		local files = core.list_mod_files(req.mod)
		send_response({
			req_id = req.req_id,
			type = "file_list",
			mod = req.mod,
			files = files,
		})

	elseif req.type == "read_file" then
		local content, err = core.read_mod_file(req.mod, req.file)
		send_response({
			req_id = req.req_id,
			type = "file_content",
			mod = req.mod,
			file = req.file,
			content = content,
			error = err,
		})

	elseif req.type == "write_file" then
		local ok, err = core.write_mod_file(req.mod, req.file, req.content)
		if ok == nil then
			ok = false
		end
		send_response({
			req_id = req.req_id,
			type = "ack",
			ok = ok,
			msg = err,
		})

	elseif req.type == "write_and_reload" then
		local ok, err = core.write_mod_file(req.mod, req.file, req.content)
		if ok == nil then
			ok = false
		end
		if ok then
			local r_ok, r_msg = core.reload_server_mod(req.mod)
			if r_ok == nil then
				r_ok = false
			end
			send_response({
				req_id = req.req_id,
				type = "ack",
				ok = r_ok,
				msg = r_msg,
			})
		else
			send_response({
				req_id = req.req_id,
				type = "ack",
				ok = false,
				msg = err,
			})
		end

	elseif req.type == "reload_mod" then
		local success, result = core.reload_server_mod(req.mod)
		if success == nil then
			success = false
		end
		send_response({
			req_id = req.req_id,
			type = "ack",
			ok = success,
			msg = result,
		})
	end
end)

pcall(function()
	mod_channel = core.mod_channel_join("al_srvedit")
end)
