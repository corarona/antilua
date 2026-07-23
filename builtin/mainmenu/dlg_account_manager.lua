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
		names[i] = account.username
	end
	return table.concat(names, ",")
end

local function get_formspec(dialogdata)
	local selected = tonumber(dialogdata.selected_index) or account_manager.get_selected_index() or 1
	local account = account_manager.get_accounts()[selected]

	-- Always derive from the selected account, not from cached dialogdata
	local current_username = account and account.username or ""
	local current_password = account and account.password or ""
	dialogdata.selected_index = selected
	dialogdata.username = current_username
	dialogdata.password = current_password
	local mapped_server = account and account.server or ""
	if mapped_server == "" then
		mapped_server = fgettext("No server mapped")
	end

	return table.concat({
		"formspec_version[6]",
		"size[11.4,9.1]",
		"label[0.55,0.55;" .. fgettext("Account Manager") .. "]",
		"textlist[0.45,1.1;4.35,7.2;accounts;" .. account_list_text() .. ";" .. selected .. "]",
		"label[5.3,1.1;" .. fgettext("Username") .. ":]",
		"field[5.3,1.45;5.45,0.8;username;;" .. core.formspec_escape(current_username) .. "]",
		"label[5.3,2.6;" .. fgettext("Password") .. ":]",
		"pwdfield[5.3,2.95;5.45,0.75;password;]",
		"label[5.3,4.0;" .. fgettext("Server") .. ": " .. core.formspec_escape(mapped_server) .. "]",
		"button[5.3,4.8;5.45,0.75;save;" .. fgettext("Add / Update") .. "]",
		"button[5.3,5.7;5.45,0.75;set_default;" .. fgettext("Set Default") .. "]",
		"button[5.3,6.6;5.45,0.75;remove;" .. fgettext("Remove") .. "]",
		"button[5.3,7.5;5.45,0.75;back;" .. fgettext("Back") .. "]"
	}, "\n")
end

local function buttonhandler(this, fields)
	if fields.accounts then
		local event = core.explode_textlist_event(fields.accounts)
		if event.type == "CHG" or event.type == "DCL" then
			this.data.selected_index = event.index
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

	if fields.save then
		local ok, err = account_manager.upsert(fields.username or "", fields.password or "")
		if not ok then
			gamedata.errormessage = err or fgettext("Unable to save account.")
		else
			this.data.selected_index = account_manager.get_selected_index()
			this.data.password = ""
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

function create_account_manager_dlg()
	local dlg = dialog_create("dlg_account_manager", get_formspec, buttonhandler, eventhandler)
	return dlg
end
