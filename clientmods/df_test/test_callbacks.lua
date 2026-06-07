-- Tests for DragonfireClient Lua callbacks

function test_callback_registration(T)
	T.run("register_on_death exists and accepts callbacks", function()
		T.assert(type(core.register_on_death) == "function",
			"core.register_on_death should be a function")
		local ok = pcall(core.register_on_death, function() end)
		T.assert(ok, "registering a death callback should not crash")
	end)

	T.run("register_on_formspec_input exists", function()
		T.assert(type(core.register_on_formspec_input) == "function",
			"core.register_on_formspec_input should be a function")
		local ok = pcall(core.register_on_formspec_input, function() end)
		T.assert(ok, "registering a formspec callback should not crash")
	end)

	T.run("register_on_receiving_inventory_form exists", function()
		T.assert(type(core.register_on_receiving_inventory_form) == "function",
			"core.register_on_receiving_inventory_form should be a function")
		local ok = pcall(core.register_on_receiving_inventory_form, function() end)
		T.assert(ok, "registering form callback should not crash")
	end)

	T.run("register_on_open_nodemeta_form exists", function()
		T.assert(type(core.register_on_open_nodemeta_form) == "function",
			"core.register_on_open_nodemeta_form should be a function")
		local ok = pcall(core.register_on_open_nodemeta_form, function() end)
		T.assert(ok, "registering nodemeta form callback should not crash")
	end)

	T.run("register_on_recieve_physics_override exists", function()
		T.assert(type(core.register_on_recieve_physics_override) == "function",
			"core.register_on_recieve_physics_override should be a function")
		local ok = pcall(core.register_on_recieve_physics_override, function() end)
		T.assert(ok, "registering physics callback should not crash")
	end)

	T.run("register_on_play_sound exists", function()
		T.assert(type(core.register_on_play_sound) == "function",
			"core.register_on_play_sound should be a function")
		local ok = pcall(core.register_on_play_sound, function() end)
		T.assert(ok, "registering sound callback should not crash")
	end)

	T.run("register_on_receive_particlespawner exists", function()
		T.assert(type(core.register_on_receive_particlespawner) == "function")
	end)

	T.run("register_on_object_add exists", function()
		T.assert(type(core.register_on_object_add) == "function",
			"core.register_on_object_add should be a function")
		local ok = pcall(core.register_on_object_add, function() end)
		T.assert(ok, "registering object add callback should not crash")
	end)

	T.run("register_on_object_hp_change exists", function()
		T.assert(type(core.register_on_object_hp_change) == "function",
			"core.register_on_object_hp_change should be a function")
		local ok = pcall(core.register_on_object_hp_change, function() end)
		T.assert(ok, "registering hp change callback should not crash")
	end)

	T.run("register_on_object_properties_change exists", function()
		T.assert(type(core.register_on_object_properties_change) == "function",
			"core.register_on_object_properties_change should be a function")
		local ok = pcall(core.register_on_object_properties_change, function() end)
		T.assert(ok, "registering properties change callback should not crash")
	end)

	T.run("registered_on_death table exists", function()
		T.assert(type(core.registered_on_death) == "table",
			"core.registered_on_death should be a table")
	end)

	T.run("registered_on_object_add table exists", function()
		T.assert(type(core.registered_on_object_add) == "table",
			"core.registered_on_object_add should be a table")
	end)

	T.run("send_chat_message exists", function()
		T.assert(type(core.send_chat_message) == "function",
			"core.send_chat_message should be a function")
		-- Don't actually call it — it would broadcast publicly on servers
	end)

	T.run("register_on_death multiple callbacks", function()
		local count = 0
		local reg1 = pcall(core.register_on_death, function() count = count + 1 end)
		local reg2 = pcall(core.register_on_death, function() count = count + 1 end)
		T.assert(reg1 and reg2, "registering multiple death callbacks should work")
	end)

	T.run("register_on_detached_inventory_update exists", function()
		T.assert(type(core.register_on_detached_inventory_update) == "function",
			"core.register_on_detached_inventory_update should be a function")
		local ok = pcall(core.register_on_detached_inventory_update, function() end)
		T.assert(ok, "registering detached inventory callback should not crash")
	end)

	-- New Phase 2: Interception callbacks
	T.run("register_on_receiving_formspec exists", function()
		T.assert(type(core.register_on_receiving_formspec) == "function")
		pcall(core.register_on_receiving_formspec, function() end)
	end)

	T.run("register_on_node_add exists", function()
		T.assert(type(core.register_on_node_add) == "function")
		pcall(core.register_on_node_add, function() end)
	end)

	T.run("register_on_node_remove exists", function()
		T.assert(type(core.register_on_node_remove) == "function")
		pcall(core.register_on_node_remove, function() end)
	end)

	T.run("register_on_hud_add/remove/change exist", function()
		T.assert(type(core.register_on_hud_add) == "function")
		T.assert(type(core.register_on_hud_remove) == "function")
		T.assert(type(core.register_on_hud_change) == "function")
		pcall(core.register_on_hud_add, function() end)
		pcall(core.register_on_hud_remove, function() end)
		pcall(core.register_on_hud_change, function() end)
	end)

	T.run("register_on_time_of_day exists", function()
		T.assert(type(core.register_on_time_of_day) == "function")
		pcall(core.register_on_time_of_day, function() end)
	end)

	-- New Phase 3: Notification callbacks
	T.run("register_on_connect exists", function()
		T.assert(type(core.register_on_connect) == "function")
		pcall(core.register_on_connect, function() end)
	end)

	T.run("register_on_disconnect exists", function()
		T.assert(type(core.register_on_disconnect) == "function")
		pcall(core.register_on_disconnect, function() end)
	end)

	T.run("register_on_privileges_changed exists", function()
		T.assert(type(core.register_on_privileges_changed) == "function")
		pcall(core.register_on_privileges_changed, function() end)
	end)

	T.run("register_on_breath_changed exists", function()
		T.assert(type(core.register_on_breath_changed) == "function")
		pcall(core.register_on_breath_changed, function() end)
	end)

	T.run("register_on_player_list_changed exists", function()
		T.assert(type(core.register_on_player_list_changed) == "function")
		pcall(core.register_on_player_list_changed, function() end)
	end)

	T.run("register_on_lighting_changed exists", function()
		T.assert(type(core.register_on_lighting_changed) == "function")
		pcall(core.register_on_lighting_changed, function() end)
	end)

	-- New Phase 4: Game loop hooks
	T.run("register_on_pre_step/post_step exist", function()
		T.assert(type(core.register_on_pre_step) == "function")
		T.assert(type(core.register_on_post_step) == "function")
		pcall(core.register_on_pre_step, function() end)
		pcall(core.register_on_post_step, function() end)
	end)
end
