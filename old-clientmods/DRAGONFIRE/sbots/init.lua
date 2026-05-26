sbots = {}

local function round2(num, numDecimalPlaces)
	return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end

local function aim(tpos)
	local ppos=minetest.localplayer:get_pos()
	if not ppos then return end
	if not tpos or not tpos.x then return end
	local dir=vector.direction(ppos,tpos)
	local yyaw=0;
	local pitch=0;
	if dir.x < 0 then
		yyaw = math.atan2(-dir.x, dir.z) + (math.pi * 2)
	else
		yyaw = math.atan2(-dir.x, dir.z)
	end
	yyaw = round2(math.deg(yyaw),2)
	pitch = round2(math.deg(math.asin(-dir.y) * 1),2)
	minetest.localplayer:set_yaw(yyaw)
	minetest.localplayer:set_pitch(pitch)
end

local bot_class = {
	find_pos = function(self,pos) end,
	do_pos = function(self,pos) end,
	do_step = function(self, dtime) end,
	update_pos = function(self,pos) return self:find_pos(self,pos) end,
	active = false,
	landing_distance = 1,
	moving_target = false,
	stand_waiting = false,
	target_pos = nil,
}

local bot_class_meta = {__index = bot_class}

local function techname(name)
	return name
end

local registered_bots = {}

function sbots.register_bot(name,def)
	local tn = techname(name)
	registered_bots[tn] = setmetatable(def,bot_class_meta)
	minetest.register_cheat(name,"Bots",tn)
	minetest.register_globalstep(function(dtime)
		if not minetest.settings:get_bool(tn) then
			if registered_bots[tn].active then --deactivated
				registered_bots[tn].active = false
				minetest.settings:set_bool("continuous_forward",false)
				minetest.settings:set_bool("pitch_move",false)
			end

			if registered_bots[tn].on_deactivate then
				return registered_bots[tn].on_deactivate(registered_bots[tn])
			end
			return
		end

		if not registered_bots[tn].active then --activated
			registered_bots[tn].orig_pos = minetest.localplayer:get_pos()
			registered_bots[tn].target_pos = nil
			registered_bots[tn].stage = 0
			minetest.settings:set_bool("pitch_move",true)
			minetest.settings:set_bool("free_move",true)
			registered_bots[tn].active = true
			if registered_bots[tn].on_activate then
				return registered_bots[tn].on_activate(registered_bots[tn])
			end
			return
		end

		local self = registered_bots[tn]
		local lp = minetest.localplayer:get_pos()
		if self.stage == 0 then --searching
			self.target_pos = self:find_pos(lp)
			if self.target_pos then
				self.stage = 1
			elseif self.orig_pos and vector.distance(lp,self.orig_pos) > self.landing_distance then
				--aim(self.orig_pos)
				minetest.settings:set_bool("continuous_forward",false)
				--minetest.settings:set_bool("continuous_forward",true)
			else
				minetest.settings:set_bool("continuous_forward",false)
				if not self.stand_waiting then
					minetest.log("nothing found!")
					minetest.settings:set_bool("continuous_forward",false)
					minetest.settings:set_bool(tn,false)
				end
			end
		elseif self.stage == 1 then --flying
			if not self.target_pos then
				return
			end
			aim(self.target_pos)
			minetest.settings:set_bool("continuous_forward",true)
			if vector.distance(lp,self.target_pos) < self.landing_distance then
				self.stage = 2
			end
		elseif self.stage == 2 then --acting/waiting
			minetest.settings:set_bool("continuous_forward",false)
			if self:do_pos(lp) then
				self.stage = 0
			end
		else self.stage = 0	end
		if self.moving_target then
			self.target_pos = self:update_pos(lp)
		end
		self:do_step(dtime)
	end)
end

if nlist then
	sbots.register_bot("listDigBot",{
		find_pos = function(self,pos)
			local nds = minetest.find_nodes_near(pos,60,nlist.get(nlist.selected))
			if not nds or #nds == 0 then return end
			table.sort(nds,function(a, b) return vector.distance(pos,a) < vector.distance(pos,b) end)
			return nds[1]
		end,
		do_pos = function(self,pos)
			local nn=minetest.find_nodes_near(pos,1,nlist.get(nlist.selected),true)
			if not nn or #nn == 0 then return true end
			for _,v in pairs(nn) do ws.dig(v) end
		end,
	})
end


