core.register_chatcommand("entityinfo", {
	params = "",
	description = "Show info about the entity or node you are pointing at",
	func = function()
		local pt = core.get_pointed_thing()
		if not pt or pt.type == "nothing" then
			core.display_chat_message("Not pointing at anything")
			return
		end
		if pt.type == "node" then
			local pos = pt.under
			local node = core.get_node_or_nil(pos)
			local def = node and core.get_node_def(node.name)
			core.display_chat_message("Node: " .. (node and node.name or "unknown"))
			core.display_chat_message("  Position: " .. pos.x .. ", " .. pos.y .. ", " .. pos.z)
			if def then
				core.display_chat_message("  Drawtype: " .. (def.drawtype or "?"))
				core.display_chat_message("  Groups: " .. dump(def.groups or {}))
			end
		elseif pt.type == "object" then
			local ref = pt.ref
			local name = ref:get_name()
			local hp = ref:get_hp()
			local props = ref:get_properties()
			core.display_chat_message("Entity: " .. name)
			core.display_chat_message("  HP: " .. hp .. " / " .. (props.hp_max or "?"))
			core.display_chat_message("  Position: " .. dump(ref:get_pos()))
			if props then
				core.display_chat_message("  Visual: " .. (props.visual or "?"))
				core.display_chat_message("  Mesh: " .. (props.mesh or "?"))

				if props.nametag and #props.nametag > 0 then
					core.display_chat_message("  Nametag: " .. props.nametag)
				end
			end
			core.display_chat_message("  Is player: " .. tostring(ref:is_player()))
			core.display_chat_message("  Is local: " .. tostring(ref:is_local_player()))
		end
	end,
})
