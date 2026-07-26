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

sbots.register_bot("FishBot", {
	description = "Bot that fishes automatically",
	movement = "stationary",
	find_pos = function(self, pos)
		return nil
	end,
	do_pos = function(self, pos)
		return true
	end,
	do_step = function(self, dtime)
		self.state = self.state or 0
		self.obpos = self.obpos or vector.new(0, 0, 0)

		local rod = "mcl_fishing:fishing_rod_enchanted"
		if not ws.switch_to_item(rod) then
			ws.switch_to_item("mcl_fishing:fishing_rod")
		end

		local bobber_range = tonumber(core.settings:get("fishbot.bobber_range")) or 10
		local bpos = get_bobber_pos(bobber_range)
		if not bpos then
			self.state = 0
			return
		end
		if self.state == 0 then
			core.interact("activate", {type="nothing"})
			ws.notify("FishBot: cast", ws.NOTIFY_INFO, {chat = false})
			self.state = 1
		elseif self.state == 1 then
			if vector.distance(bpos, self.obpos) == 0 then
				self.state = 2
			end
		elseif self.state == 2 then
			local nd = core.get_node_or_nil(vector.add(bpos, vector.new(0, -0.5, 0)))
			if vector.distance(bpos, self.obpos) > 0 then
				ws.notify("FishBot: bite!", ws.NOTIFY_SUCCESS, {chat = false})
				core.after(0.1, function()
					core.interact("activate", {type="nothing"})
				end)
				self.state = 3
			end
			if nd and nd.name ~= "mcl_core:water_source" then
				self.state = 0
			end
		elseif self.state == 3 then
			if not get_bobber_pos(bobber_range) then
				ws.notify("FishBot: reeling in", ws.NOTIFY_INFO, {chat = false})
				self.state = 0
			end
		end
		if bpos then
			self.obpos = bpos
		end
	end,
	on_activate = function(self)
		if not core.get_item_def("mcl_fishing:fishing_rod") then
			ws.notify("Fishbot only works on mineclone/ia", ws.NOTIFY_ERROR)
			return true
		end
		if not ws.switch_to_item("mcl_fishing:fishing_rod_enchanted")
				and not ws.switch_to_item("mcl_fishing:fishing_rod") then
			ws.notify("Put a fishing rod in the hotbar", ws.NOTIFY_WARNING)
			return true
		end
		self.state = 0
	end,
	on_deactivate = function(self)
		self.state = 0
	end,
	stand_waiting = true,
	delay = 0.2,
	daughters = {"autodump", "autoeject", "lockview"},
	cheat_settings = {
		bobber_range = { type = "number", default = 10, min = 1, max = 50 },
	},
})
