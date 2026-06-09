local fb_state = 0
local fb_obpos = vector.new(0, 0, 0)
local had_rod = false

local function get_bobber_pos(range)
	local lp = core.localplayer:get_pos()
	local obs = core.get_objects_inside_radius(lp, range)
	for _, v in ipairs(obs) do
		local props = v:get_properties()
		local tex = props and props.textures
		local txt = (tex and tex[1]) or ""
		if txt:find("bobber") then
			return v:get_pos()
		end
	end
	return false
end

ws.rg("FishBot", {
	category = "Bots",
	setting = "fishbot",
	on_step = function(self, dtime)
		local rod = "mcl_fishing:fishing_rod_enchanted"
		if not ws.switch_to_item(rod) then
			ws.switch_to_item("mcl_fishing:fishing_rod")
		end
		had_rod = true

		local bobber_range = tonumber(core.settings:get("fishbot.bobber_range")) or 10
		local bpos = get_bobber_pos(bobber_range)
		if not bpos then
			fb_state = 0
			return
		end
		if fb_state == 0 then
			core.interact("activate", {type="nothing"})
			fb_state = 1
		elseif fb_state == 1 then
			if vector.distance(bpos, fb_obpos) == 0 then
				fb_state = 2
			end
		elseif fb_state == 2 then
			local nd = core.get_node_or_nil(vector.add(bpos, vector.new(0, -0.5, 0)))
			if vector.distance(bpos, fb_obpos) > 0 then
				core.after(0.1, function()
					core.interact("activate", {type="nothing"})
				end)
				fb_state = 3
			end
			if nd and nd.name ~= "mcl_core:water_source" then
				fb_state = 0
			end
		elseif fb_state == 3 then
			if not get_bobber_pos(bobber_range) then
				fb_state = 0
			end
		end
		if bpos then
			fb_obpos = bpos
		end
	end,
	on_start = function(self)
		if ws.game ~= "mineclone" then
			ws.notify("Fishbot only works on mineclone/ia", ws.NOTIFY_ERROR)
			return false
		end
		if not ws.switch_to_item("mcl_fishing:fishing_rod_enchanted")
				and not ws.switch_to_item("mcl_fishing:fishing_rod") then
			ws.notify("Put a fishing rod in the hotbar", ws.NOTIFY_WARNING)
			return false
		end
		had_rod = true
	end,
	on_stop = function(self)
		fb_state = 0
	end,
	daughters = {"autodump", "autoeject", "lockview"},
	cheat_settings = {
		water_range = { type = "number", default = 10, min = 1, max = 50 },
		bobber_range = { type = "number", default = 10, min = 1, max = 50 },
	},
})
