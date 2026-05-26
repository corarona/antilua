-- Tests for DragonfireClient ClientObjectRef API
-- All deferred until core.localplayer is available

function test_clientobject_ref(T)
	T.defer("ClientObjectRef type exists", function()
		local ref = core.localplayer:get_object()
		T.assert(ref ~= nil, "localplayer:get_object() should return a ClientObjectRef")
	end)

	T.defer("ClientObjectRef:get_pos works", function()
		local ref = core.localplayer:get_object()
		if ref then
			local pos = ref:get_pos()
			T.assert(type(pos) == "table", "get_pos should return a table")
			T.assert(type(pos.x) == "number", "pos.x should be a number")
			T.assert(type(pos.y) == "number", "pos.y should be a number")
			T.assert(type(pos.z) == "number", "pos.z should be a number")
		end
	end)

	T.defer("ClientObjectRef:get_velocity works", function()
		local ref = core.localplayer:get_object()
		if ref then
			local vel = ref:get_velocity()
			T.assert(type(vel) == "table", "get_velocity should return a table")
		end
	end)

	T.defer("ClientObjectRef:get_rotation works", function()
		local ref = core.localplayer:get_object()
		if ref then
			local rot = ref:get_rotation()
			T.assert(type(rot) == "table", "get_rotation should return a table")
		end
	end)

	T.defer("ClientObjectRef:is_player works", function()
		local ref = core.localplayer:get_object()
		if ref then
			local is_player = ref:is_player()
			T.assert(type(is_player) == "boolean", "is_player should return a boolean")
		end
	end)

	T.defer("ClientObjectRef:is_local_player works", function()
		local ref = core.localplayer:get_object()
		if ref then
			local is_local = ref:is_local_player()
			T.assert(is_local == true, "local player should report is_local_player=true")
		end
	end)

	T.defer("ClientObjectRef:get_name works", function()
		local ref = core.localplayer:get_object()
		if ref then
			local name = ref:get_name()
			T.assert(type(name) == "string", "get_name should return a string")
		end
	end)

	T.defer("ClientObjectRef:get_properties works", function()
		local ref = core.localplayer:get_object()
		if ref then
			local props = ref:get_properties()
			T.assert(type(props) == "table", "get_properties should return a table")
			T.assert(props.hp_max ~= nil, "properties should have hp_max")
		end
	end)

	T.defer("ClientObjectRef:get_hp works", function()
		local ref = core.localplayer:get_object()
		if ref then
			local hp = ref:get_hp()
			T.assert(type(hp) == "number", "get_hp should return a number")
		end
	end)

	T.defer("core.get_objects_inside_radius works", function()
		local pos = core.localplayer:get_pos()
		local objs = core.get_objects_inside_radius(pos, 10)
		T.assert(type(objs) == "table", "get_objects_inside_radius should return a table")
		T.assert(#objs > 0, "should find at least the local player")
	end)

	T.defer("core.object_refs table exists", function()
		local refs = core.object_refs
		T.assert(type(refs) == "table", "core.object_refs should be a table")
	end)
end
