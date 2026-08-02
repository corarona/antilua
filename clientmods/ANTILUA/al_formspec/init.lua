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

function al_formspec.textlist(x, y, w, h, id, items, selected_idx)
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
	s = s .. ";" .. (selected_idx or 1) .. "]"
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

--
-- searchbar: returns { field, button } pair for a filter/search bar.
-- Button uses id "__<id>_search". Consumers check for this field in
-- register_on_formspec_input, or check key_enter_field on the field id.
--
function al_formspec.searchbar(x, y, w, id, opts)
	opts = opts or {}
	local bw = opts.button_width or 1.7
	local bw_half = bw / 2
	local field_w = w - bw - 0.3
	return {
		al_formspec.field(x, y, field_w, 0.8, id, opts.placeholder or "Filter:", opts.default or ""),
		al_formspec.button(x + field_w + 0.3, y, bw, 0.8, "__" .. id .. "_search", opts.button or "Go"),
	}
end

--
-- confirm_layout: returns { label, btn_no, btn_yes } for embedding in a
-- larger formspec. Caller positions x,y and the dialog spans w wide.
-- opts: { yes_label, no_label }
--
function al_formspec.confirm_layout(x, y, w, text, yes_id, no_id, opts)
	opts = opts or {}
	local btn_w = math.max((w - 0.3) / 2, 2)
	return {
		al_formspec.label(x, y, text),
		al_formspec.button(x, y + 0.8, btn_w, 0.7, no_id or "cancel", opts.no_label or "Cancel"),
		al_formspec.button(x + btn_w + 0.3, y + 0.8, btn_w, 0.7, yes_id or "confirm", opts.yes_label or "Confirm"),
	}
end

--
-- confirm_dialog: returns a complete standalone formspec string for a
-- confirmation popup. Wraps confirm_layout with begin()/get().
-- opts: { size, yes_label, no_label }
--
function al_formspec.confirm_dialog(text, yes_id, no_id, opts)
	opts = opts or {}
	local sb = al_formspec.begin(opts.size or "size[6,2.5]")
	sb:add(al_formspec.confirm_layout(0.35, 0.25, 5.3, text, yes_id, no_id, {
		yes_label = opts.yes_label,
		no_label = opts.no_label,
	}))
	return sb:get()
end

--
-- progress_bar: returns { box_bg, box_fill, label } for a visual progress
-- indicator. Use with sb:add() which flattens tables.
-- opts: { fill_color, bg_color }
--
function al_formspec.progress_bar(x, y, w, h, id, value, max, opts)
	opts = opts or {}
	max = math.max(max or 1, 1)
	local pct = math.max(0, math.min(value / max, 1))
	local fill_w = (w - 0.2) * pct
	local fill_color = opts.fill_color or al_formspec.ACCENT
	local bg_color = opts.bg_color or al_formspec.BG_COLOR
	local pct_text = math.floor(pct * 100) .. "%"
	return {
		"box[" .. x .. "," .. y .. ";" .. w .. "," .. h .. ";" .. bg_color .. "]",
		"box[" .. (x + 0.1) .. "," .. (y + 0.1) .. ";" .. math.max(fill_w, 0) .. "," .. (h - 0.2) .. ";" .. fill_color .. "]",
		al_formspec.label(x + w / 2 - 0.3, y + h / 2 - 0.25, pct_text),
	}
end

function al_formspec.tabheader(x, y, id, tabs, current)
	local s = "tabheader[" .. x .. "," .. y .. ";" .. id .. ";"
	if tabs and #tabs > 0 then
		local escaped = {}
		for _, v in ipairs(tabs) do
			table.insert(escaped, al_formspec.escape(v))
		end
		s = s .. table.concat(escaped, ",")
	end
	s = s .. ";" .. (current or 1) .. "]"
	return s
end

function al_formspec.box(x, y, w, h, color)
	return "box[" .. x .. "," .. y .. ";" .. w .. "," .. h .. ";" .. (color or al_formspec.BG_COLOR) .. "]"
end

function al_formspec.scroll_container(x, y, w, h, id, orientation)
	return "scroll_container[" .. x .. "," .. y .. ";" .. w .. "," .. h .. ";" .. id .. ";" .. (orientation or "vertical") .. "]"
end

function al_formspec.scroll_container_end()
	return "scroll_container_end[]"
end

core.al_formspec = al_formspec

--
-- Formspec blocker + trash injector (merged from formspec_utils)
--

local blocked_patterns = {}

core.register_cheat("FormspecBlocker", { category = "Interact", setting = "formspec_blocker",
	description = "Block server formspecs from showing" })

local function inject_trash_button(formname, formspec)
	if not formspec or formname ~= "" then
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

-- The `on_receiving_inventory_form` hook now receives (formname, formspec).
-- The trash injector only ever matched the player inventory (formname == "")
-- and its buttons have no field handler, so leave the inventory formspec
-- untouched (the blocker above applies to other formspecs).
core.register_on_receiving_inventory_form(function(_, formspec)
	return formspec
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
