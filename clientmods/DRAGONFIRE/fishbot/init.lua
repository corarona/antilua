local fb_state=0
local fb_obpos=vector.new(0,0,0)

local function find_closest_water_source(self)
	local lp=ws.dircoord(0,0,0)
	local range = tonumber(core.settings:get(self.setting .. ".water_range")) or 10
	local nds=minetest.find_nodes_near(lp, range, {"mcl_core:water_source"})
	local odst=100
	local rt=vector.new()
	for k,v in ipairs(nds) do
		local dst=vector.distance(lp,v)
		if dst < odst then rt=v odst=dst end
	end
	return rt
end

local function get_bobber_pos(self)
	local range = tonumber(core.settings:get(self.setting .. ".bobber_range")) or 10
	local obs=minetest.get_objects_inside_radius(ws.dircoord(0,0,0), range)
	for k,v in ipairs(obs) do
		local txt = (v.get_properties and v:get_properties().textures[1]) or (v.get_item_textures and v:get_item_textures())  or ""
		if txt:find("bobber") then
			return v:get_pos()
		end
	end
	return false
end

ws.rg('FishBot', {
	category = 'Bots',
	setting = 'fishbot',
	on_step = function(self, dtime)
		if not ws.switch_to_item('mcl_fishing:fishing_rod_enchanted') then
			ws.switch_to_item('mcl_fishing:fishing_rod')
		end
		local bpos=get_bobber_pos(self)
		if not bpos then fb_state=0 end
		if fb_state == 0 then
			minetest.interact("activate",{type="nothing"})
			fb_state=1
		elseif fb_state == 1 then
			if vector.distance(bpos,fb_obpos) == 0 then
				fb_state=2
			end
		elseif fb_state == 2 then
			local nd=minetest.get_node_or_nil(vector.add(bpos,vector.new(0,-0.5,0)))
			if vector.distance(bpos,fb_obpos) > 0 then
				minetest.after('0.1',function()
					minetest.interact("activate",{type="nothing"})
				end)
				fb_state=3
			end
			if nd.name ~= "mcl_core:water_source" then
				fb_state=0
			end
		elseif fb_state == 3 then
			if not get_bobber_pos(self) then fb_state=0 end
		end
		if bpos then fb_obpos=bpos end
	end,
	on_start = function(self)
		if ws.game ~= "mineclone" then ws.notify("Fishbot only works on mineclone/ia", ws.NOTIFY_ERROR) end
		if not ws.switch_to_item('mcl_fishing:fishing_rod_enchanted') and not ws.switch_to_item('mcl_fishing:fishing_rod') then
			ws.notify("Put a fishing rod in the hotbar", ws.NOTIFY_WARNING)
			return true
		end
	end,
	on_stop = function(self)
		fb_state=0
	end,
	daughters = {'autodump','autoeject','lockview'},
	cheat_settings = {
		water_range = { type = "number", default = 10, min = 1, max = 50 },
		bobber_range = { type = "number", default = 10, min = 1, max = 50 },
	},
})
