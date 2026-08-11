core.register_chatcommand("entityinfo", {
	params = "",
	description = "Show info about the entity or node you are pointing at",
	func = function()
		local function say(msg)
			ws.notify(msg, ws.NOTIFY_INFO, {toast = false})
		end
		local pt = core.get_pointed_thing()
		if not pt or pt.type == "nothing" then
			say("Not pointing at anything")
			return
		end
		if pt.type == "node" then
			local pos = pt.under
			local node = core.get_node_or_nil(pos)
			local def = node and core.get_node_def(node.name)
			say("Node: " .. (node and node.name or "unknown"))
			say("  Position: " .. pos.x .. ", " .. pos.y .. ", " .. pos.z)
			if def then
				say("  Drawtype: " .. (def.drawtype or "?"))
				say("  Groups: " .. dump(def.groups or {}))
			end
		elseif pt.type == "object" then
			local ref = pt.ref
			local name = ref:get_name()
			local hp = ref:get_hp()
			local props = ref:get_properties()
			say("Entity: " .. name)
			say("  HP: " .. hp .. " / " .. (props.hp_max or "?"))
			say("  Position: " .. dump(ref:get_pos()))
			if props then
				say("  Visual: " .. (props.visual or "?"))
				say("  Mesh: " .. (props.mesh or "?"))

				if props.nametag and #props.nametag > 0 then
					say("  Nametag: " .. props.nametag)
				end
			end
			say("  Is player: " .. tostring(ref:is_player()))
			say("  Is local: " .. tostring(ref:is_local_player()))
		end
	end,
})
