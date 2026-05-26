-- Tests for DragonfireClient ClientObjectRef API
-- All depend on localplayer:get_object() from DF's l_localplayer.cpp

function test_clientobject_ref(T)
	T.known_failure("ClientObjectRef:get_pos (needs l_localplayer changes)", function()
		local ref = core.localplayer:get_object()
		local pos = ref:get_pos()
		T.assert(type(pos) == "table", "get_pos should return a table")
	end)

	T.known_failure("ClientObjectRef:get_velocity (needs l_localplayer changes)", function()
		local ref = core.localplayer:get_object()
		local vel = ref:get_velocity()
		T.assert(type(vel) == "table", "get_velocity should return a table")
	end)

	T.known_failure("ClientObjectRef:get_rotation (needs l_localplayer changes)", function()
		local ref = core.localplayer:get_object()
		local rot = ref:get_rotation()
		T.assert(type(rot) == "table", "get_rotation should return a table")
	end)

	T.known_failure("ClientObjectRef:is_player (needs l_localplayer changes)", function()
		local ref = core.localplayer:get_object()
		T.assert(type(ref:is_player()) == "boolean", "is_player should return boolean")
	end)

	T.known_failure("ClientObjectRef:is_local_player (needs l_localplayer changes)", function()
		local ref = core.localplayer:get_object()
		T.assert(ref:is_local_player() == true, "local player should be local")
	end)

	T.known_failure("ClientObjectRef:get_name (needs l_localplayer changes)", function()
		local ref = core.localplayer:get_object()
		T.assert(type(ref:get_name()) == "string", "get_name should return string")
	end)

	T.known_failure("ClientObjectRef:get_properties (needs l_localplayer changes)", function()
		local ref = core.localplayer:get_object()
		local props = ref:get_properties()
		T.assert(props.hp_max ~= nil, "properties should have hp_max")
	end)

	T.known_failure("ClientObjectRef:get_hp (needs l_localplayer changes)", function()
		local ref = core.localplayer:get_object()
		T.assert(type(ref:get_hp()) == "number", "get_hp should return number")
	end)

	T.known_failure("core.get_objects_inside_radius (needs ModApiClient)", function()
		local pos = core.localplayer:get_pos()
		local objs = core.get_objects_inside_radius(pos, 10)
		T.assert(#objs > 0, "should find at least the local player")
	end)

	T.known_failure("core.object_refs table (needs ModApiClient)", function()
		T.assert(type(core.object_refs) == "table", "core.object_refs should be a table")
	end)
end
