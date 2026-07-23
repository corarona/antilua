-- Antilua — Account Manager Dialog
-- Based on Lunarchy's dlg_account_manager.lua
-- SPDX-License-Identifier: LGPL-2.1-or-later

local function account_list_text()
	local accounts = account_manager.get_accounts()
	if #accounts == 0 then
		return fgettext("No accounts saved")
	end
	local names = {}
	for i, account in ipairs(accounts) do
		if account.server and account.server ~= "" then
			names[i] = account.username .. " (" .. account.server .. ")"
		else
			names[i] = account.username
		end
	end
	return table.concat(names, ",")
end

local function get_formspec(dialogdata)
	local selected = tonumber(dialogdata.selected_index) or account_manager.get_selected_index() or 1
	local account = account_manager.get_accounts()[selected]

	-- Always derive from the selected account, not from cached dialogdata
	local current_username = account and account.username or ""
	local current_password = account and account.password or ""
	-- dialogdata.server (when non-nil) is a user-typed or prefilled value that
	-- wins over the selected account's server until a different account is
	-- picked or it is saved; selecting an account resets it (see buttonhandler).
	local current_server
	if dialogdata.server ~= nil then
		current_server = dialogdata.server
	else
		current_server = account and account.server or ""
	end
	dialogdata.selected_index = selected
	dialogdata.username = current_username
	dialogdata.password = current_password
	dialogdata.server = current_server

	return table.concat({
		"formspec_version[6]",
		"size[11.4,9.1]",
		"label[0.55,0.55;" .. fgettext("Account Manager") .. "]",
		"textlist[0.45,1.1;4.35,7.2;accounts;" .. account_list_text() .. ";" .. selected .. "]",
		"label[5.3,1.1;" .. fgettext("Username") .. ":]",
		"field[5.3,1.45;5.45,0.8;username;;" .. core.formspec_escape(current_username) .. "]",
		"label[5.3,2.6;" .. fgettext("Password") .. ":]",
		"field[5.3,2.95;5.45,0.75;password;;" .. core.formspec_escape(current_password) .. "]",
		"label[5.3,4.0;" .. fgettext("Server") .. ":]",
		"field[5.3,4.35;5.45,0.75;server;;" .. core.formspec_escape(current_server) .. "]",
		"tooltip[server;" .. fgettext("Map to a server (address:port); blank for any server.") .. "]",
		"button[5.3,5.2;5.45,0.75;save;" .. fgettext("Add / Update") .. "]",
		"button[5.3,6.1;5.45,0.75;set_default;" .. fgettext("Set Default") .. "]",
		"button[5.3,7.0;5.45,0.75;remove;" .. fgettext("Remove") .. "]",
		"button[5.3,7.9;5.45,0.75;back;" .. fgettext("Back") .. "]"
	}, "\n")
end

local function buttonhandler(this, fields)
	if fields.accounts then
		local event = core.explode_textlist_event(fields.accounts)
		if event.type == "CHG" or event.type == "DCL" then
			this.data.selected_index = event.index
			this.data.server = nil -- re-derive from the newly selected account
			local account = account_manager.get_accounts()[event.index]
			if account then
				this.data.username = account.username
				this.data.password = ""
			end
			return true
		end
	end

	if fields.username then
		this.data.username = fields.username
	end
	if fields.password then
		this.data.password = fields.password
	end
	if fields.server ~= nil then
		this.data.server = fields.server
	end

	if fields.save then
		local ok, err = account_manager.upsert(fields.username or "", fields.password or "", fields.server or "")
		if not ok then
			gamedata.errormessage = err or fgettext("Unable to save account.")
		else
			this.data.selected_index = account_manager.get_selected_index()
			this.data.password = ""
			this.data.server = nil -- re-derive from the saved account (source of truth)
		end
		return true
	end

	if fields.set_default then
		local index = tonumber(this.data.selected_index) or account_manager.get_selected_index()
		if account_manager.select_index(index) then
			local account = account_manager.get_selected_account()
			if account then
				this.data.username = account.username
				this.data.password = ""
			end
		end
		this.data.server = nil
		return true
	end

	if fields.remove then
		account_manager.remove_selected()
		this.data.selected_index = account_manager.get_selected_index()
		local account = account_manager.get_selected_account()
		if account then
			this.data.username = account.username
			this.data.password = ""
		else
			this.data.username = ""
			this.data.password = ""
		end
		this.data.server = nil
		return true
	end

	if fields.back then
		this:delete()
		return true
	end
end

local function eventhandler(event)
	if event == "DialogShow" then
		return true
	elseif event == "MenuQuit" then
		local current = ui.find_by_name("dlg_account_manager")
		current:delete()
		ui.update()
		return true
	end
	return false
end

function create_account_manager_dlg(initial_server)
	local dlg = dialog_create("dlg_account_manager", get_formspec, buttonhandler, eventhandler)
	if initial_server then
		dlg.data.server = initial_server
	end
	return dlg
end
