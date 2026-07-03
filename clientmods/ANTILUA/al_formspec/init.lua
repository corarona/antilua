local al_formspec = setmetatable({}, { __index = function(_, key)
	local theme_map = {
		BG_COLOR   = { "theme_bg", "#121212" },
		TEXT_COLOR = { "theme_text", "#00cc00" },
		ACCENT     = { "theme_accent", "#ff8800" },
		RED        = { "theme_bad", "#ff4444" },
		GREEN      = { "theme_good", "#44ff44" },
		YELLOW     = { "theme_warning", "#ffff44" },
	}
	local entry = theme_map[key]
	if entry then
		return core.settings:get(entry[1]) or entry[2]
	end
	return nil
end})

local sb_meta = {}

function sb_meta:add(...)
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if v ~= nil then
			if type(v) == "table" then
				for _, w in ipairs(v) do
					table.insert(self, w)
				end
			else
				table.insert(self, tostring(v))
			end
		end
	end
end

function sb_meta:get()
	return table.concat(self, "")
end

function al_formspec.new()
	return setmetatable({}, { __index = sb_meta })
end

function al_formspec.begin(...)
	local sb = al_formspec.new()
	sb:add(
		"formspec_version[10]",
		...
	)
	sb:add(
		"no_prepend[]",
		"bgcolor[" .. al_formspec.BG_COLOR .. ";true]"
	)
	return sb
end

function al_formspec.cheat_form_begin(size_str)
	local sb = al_formspec.new()
	sb:add(
		size_str,
		"no_prepend[]",
		al_formspec.bgcolor(al_formspec.BG_COLOR, true)
	)
	return sb
end

function al_formspec.escape(s)
	return core.formspec_escape(tostring(s))
end

function al_formspec.color(hex, s)
	return core.colorize(hex, tostring(s))
end

function al_formspec.bar(filled, max, segments)
	segments = segments or 10
	local n = math.max(0, math.min(math.floor((filled / math.max(max, 1)) * segments), segments))
	local out = {}
	for i = 1, segments do
		out[i] = i <= n and "█" or "░"
	end
	return table.concat(out)
end

function al_formspec.label(x, y, text)
	return "label[" .. x .. "," .. y .. ";" .. al_formspec.escape(text) .. "]"
end

function al_formspec.button(x, y, w, h, id, label)
	return "button[" .. x .. "," .. y .. ";" .. w .. "," .. h .. ";" .. id .. ";" .. al_formspec.escape(label) .. "]"
end

function al_formspec.button_exit(x, y, w, h, id, label)
	return "button_exit[" .. x .. "," .. y .. ";" .. w .. "," .. h .. ";" .. id .. ";" .. al_formspec.escape(label) .. "]"
end

function al_formspec.field(x, y, w, h, id, label, default)
	local s = "field[" .. x .. "," .. y .. ";" .. w .. "," .. h .. ";" .. id .. ";" .. al_formspec.escape(label or "") .. ";"
	s = s .. (default and al_formspec.escape(default) or "") .. "]"
	return s
end

function al_formspec.textlist(x, y, w, h, id, items)
	local s = "textlist[" .. x .. "," .. y .. ";" .. w .. "," .. h .. ";" .. id .. ";"
	if items and #items > 0 then
		local escaped = {}
		for _, v in ipairs(items) do
			table.insert(escaped, al_formspec.escape(v))
		end
		s = s .. table.concat(escaped, ",")
	else
		s = s .. " "
	end
	s = s .. ";1]"
	return s
end

function al_formspec.dropdown(x, y, w, id, items, selected_idx)
	local s = "dropdown[" .. x .. "," .. y .. ";" .. w .. ",0.5;" .. id .. ";"
	if items and #items > 0 then
		local escaped = {}
		for _, v in ipairs(items) do
			table.insert(escaped, al_formspec.escape(v))
		end
		s = s .. table.concat(escaped, ",")
	end
	s = s .. ";" .. (selected_idx or 1) .. "]"
	return s
end

function al_formspec.image(x, y, w, h, texture)
	return "image[" .. x .. "," .. y .. ";" .. w .. "," .. h .. ";" .. texture .. "]"
end

function al_formspec.bgcolor(color, fullscreen)
	return "bgcolor[" .. color .. ";" .. (fullscreen and "true" or "false") .. "]"
end

function al_formspec.padding(x, y)
	return "padding[" .. x .. "," .. y .. "]"
end

function al_formspec.textlist_event(field_value)
	if not field_value or field_value == "" then return nil end
	local parts = string.split(field_value, ":")
	if #parts < 2 then return nil end
	local etype = parts[1]
	local idx = tonumber(parts[2]) or 0
	if etype ~= "CHG" and etype ~= "DCL" then return nil end
	return { type = etype, idx = idx }
end

function al_formspec.textlist_selected(items, field_value)
	local ev = al_formspec.textlist_event(field_value)
	if not ev or not items or ev.idx < 1 or ev.idx > #items then
		return nil
	end
	return items[ev.idx]
end

function al_formspec.refresh_cheat_form(setting_name)
	core.show_cheat_settings_form(setting_name)
end

core.al_formspec = al_formspec

--
-- Formspec blocker + trash injector (merged from formspec_utils)
--

local blocked_patterns = {}

core.register_cheat("FormspecBlocker", { category = "Interact", setting = "formspec_blocker",
	description = "Block server formspecs from showing" })

local function inject_trash_button(formname, formspec)
	if formname ~= "" then
		return nil
	end
	local btn = "button[7.5,4.5;1,0.5;trash;Trash]"
	local close = "button[8.5,4.5;1,0.5;close;Close]"
	local idx = formspec:find("formspec_version")
	if not idx then
		return nil
	end
	local eol = formspec:find("\n", idx)
	if not eol then
		return nil
	end
	local modified = formspec:sub(1, eol) .. btn .. close .. formspec:sub(eol + 1)
	return modified
end

core.register_on_receiving_inventory_form(function(formname, formspec)
	return inject_trash_button(formname, formspec)
end)

core.register_on_receiving_formspec(function(formname, formspec)
	-- Blocker: return empty to suppress
	if core.settings:get_bool("formspec_blocker") then
		for _, pattern in ipairs(blocked_patterns) do
			if formname:find(pattern) then
				return ""
			end
		end
	end
	-- Trash button injector
	return inject_trash_button(formname, formspec)
end)

return al_formspec
