local function get_number(key, default)
	return tonumber(core.settings:get("item_esp." .. key)) or default
end

local function get_bool(key, default)
	local v = core.settings:get("item_esp." .. key)
	if v == "" then return default end
	return v == "true"
end

local nametags = {}

local function build_label(le)
	local is = le.itemstring
	if not is or is == "" then return nil end
	local def = core.get_item_def(is)
	local name = def and def.description or is
	if get_bool("show_count", true) then
		local count = le.itemcount or 1
		if count > 1 then
			name = name .. " x" .. count
		end
	end
	return name
end

local function namespace()
	if not core.localplayer then return end
	local range = get_number("range", 32)
	local objs = core.get_nearby_objects(range)
	local seen = {}

	for _, obj in ipairs(objs) do
		if obj:get_entity_name() == ":__builtin:item" then
			local le = obj:get_luaentity()
			if le then
				local id = obj:get_id()
				local label = build_label(le)
				if label then
					local pos = obj:get_pos()
					if pos then
						seen[id] = true
						if nametags[id] then
							core.camera:remove_nametag(nametags[id])
						end
						nametags[id] = core.camera:add_nametag({
							pos = pos,
							text = label,
							color = "#FFFFFF",
							size = 14,
							scale_z = true,
						})
					end
				end
			end
		end
	end

	for id, ntid in pairs(nametags) do
		if not seen[id] then
			core.camera:remove_nametag(ntid)
			nametags[id] = nil
		end
	end
end

ws.rg("ItemESP", {
	category = "Render",
	setting = "item_esp",
	description = "Show item names on dropped items",
	delay = 0.5,
	on_step = function() namespace() end,
	on_stop = function()
		for _, ntid in pairs(nametags) do
			core.camera:remove_nametag(ntid)
		end
		nametags = {}
	end,
	cheat_settings = {
		range = { type = "number", default = 32, min = 5, max = 128 },
		show_count = { type = "bool", default = true },
	},
})
