-- Tests for DragonfireClient ClientObjectRef API
-- All deferred until core.localplayer is available

function test_clientobject_ref(T)
	T.defer("ClientObjectRef:get_pos", function()
		local ref = core.localplayer:get_object()
		local pos = ref:get_pos()
		T.assert(type(pos) == "table", "get_pos should return a table")
	end)

	T.defer("ClientObjectRef:get_velocity", function()
		local ref = core.localplayer:get_object()
		local vel = ref:get_velocity()
		T.assert(type(vel) == "table", "get_velocity should return a table")
	end)

	T.defer("ClientObjectRef:get_rotation", function()
		local ref = core.localplayer:get_object()
		local rot = ref:get_rotation()
		T.assert(type(rot) == "table", "get_rotation should return a table")
	end)

	T.defer("ClientObjectRef:is_player", function()
		local ref = core.localplayer:get_object()
		T.assert(type(ref:is_player()) == "boolean", "is_player should return boolean")
	end)

	T.defer("ClientObjectRef:is_local_player", function()
		local ref = core.localplayer:get_object()
		T.assert(ref:is_local_player() == true, "local player should be local")
	end)

	T.defer("ClientObjectRef:get_name", function()
		local ref = core.localplayer:get_object()
		T.assert(type(ref:get_name()) == "string", "get_name should return string")
	end)

	T.defer("ClientObjectRef:get_properties", function()
		local ref = core.localplayer:get_object()
		local props = ref:get_properties()
		T.assert(props.hp_max ~= nil, "properties should have hp_max")
	end)

	T.defer("ClientObjectRef:get_hp", function()
		local ref = core.localplayer:get_object()
		T.assert(type(ref:get_hp()) == "number", "get_hp should return number")
	end)

	T.defer("core.get_objects_inside_radius works", function()
		local pos = core.localplayer:get_pos()
		local objs = core.get_objects_inside_radius(pos, 10)
		T.assert(type(objs) == "table", "should return a table")
	end)

	T.known_failure("core.object_refs table (not yet populated)", function()
		T.assert(type(core.object_refs) == "table", "core.object_refs should be a table")
	end)
end
