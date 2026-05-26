## sBots

A library for simple "fly (straightly) there and do things" bots for dragonfire.

### Usage
To create a new bot use

`sbots.register_bot(name,bot_definition)`

### Bot Definition
```lua
{
	find_pos = function(self,pos) end,
	--This function is used to find a new position for the bot to go to.
	--If it returns falsey it considers itsself done and calls it a day unless
	--stand_waiting is true.

	do_pos = function(self,pos) end,
	--Function that is called when a bot arrives at the target position.
	--Return true to consider this position done and find the next.

	do_step = function(dtime) end,
	--This function is run every globalstep when the bot is active indiscriminately.

	update_pos = function(self,pos) return self:find_pos(self,pos) end,
	--This function is run every globalstep when moving_target is true
	--to update the target position. By default it just runs the bot's
	--find_pos method.

	landing_distance = 1,
	--How far from the target the bot should stop moving.

	moving_target = false,
	--Wether the target position needs to be updated "en route".

	stand_waiting = false,
	--if this is true the bot will not deactivate itsself when find_pos does
	--not find any new positions currently.

	target_pos = nil, --internal: the current target position.
	active = false, --internal if the but is currently active.
}
```

#### Example Bot
included, needs nlist (optional dependency)

Finds and digs nodes from the currently selected nlist

```lua
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
```
