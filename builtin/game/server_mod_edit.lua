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

	-- All operations require server priv
	if not core.check_player_privs(sender, {server = true}) then
		send_response({
			req_id = req.req_id,
			type = "error",
			msg = "server priv required",
		})
		return
	end

	if req.type == "list_mods" then
		core.log("action", "[srv_edit] list_mods from " .. sender)
		local mods = {}
		for _, name in ipairs(core.get_modnames()) do
			mods[#mods + 1] = {
				name = name,
				path = core.get_modpath(name),
			}
		end
		send_response({req_id = req.req_id, type = "mod_list", mods = mods})

	elseif req.type == "list_files" then
		core.log("action", "[srv_edit] list_files " .. dump(req.mod) .. " from " .. sender)
		local files = core.list_mod_files(req.mod)
		send_response({
			req_id = req.req_id,
			type = "file_list",
			mod = req.mod,
			files = files,
		})

	elseif req.type == "read_file" then
		core.log("action", "[srv_edit] read_file " .. dump(req.mod) .. "/" .. dump(req.file) .. " from " .. sender)
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
		core.log("action", "[srv_edit] write_file " .. dump(req.mod) .. "/" .. dump(req.file) .. " from " .. sender)
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
		core.log("action", "[srv_edit] write_and_reload " .. dump(req.mod) .. "/" .. dump(req.file) .. " from " .. sender)
		local ok, err = core.write_mod_file(req.mod, req.file, req.content)
		if ok == nil then
			ok = false
		end
		if ok then
			core.log("action", "[srv_edit] write ok, reloading " .. dump(req.mod))
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
			core.log("action", "[srv_edit] reload " .. dump(req.mod) .. " -> " .. tostring(r_ok))
		else
			core.log("action", "[srv_edit] write failed: " .. tostring(err))
			send_response({
				req_id = req.req_id,
				type = "ack",
				ok = false,
				msg = err,
			})
		end

	elseif req.type == "reload_mod" then
		core.log("action", "[srv_edit] reload_mod " .. dump(req.mod) .. " from " .. sender)
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
		core.log("action", "[srv_edit] reload_mod " .. dump(req.mod) .. " -> " .. tostring(success))
	end
end)

pcall(function()
	mod_channel = core.mod_channel_join("al_srvedit")
end)
