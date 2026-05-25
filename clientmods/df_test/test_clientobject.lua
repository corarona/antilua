-- Tests for DragonfireClient ClientObjectRef API

function test_clientobject_ref(T)
	-- Verify ClientObjectRef type exists globally
	T.run("ClientObjectRef type exists", function()
		local ref = core.localplayer:get_object()
		T.assert(ref ~= nil, "localplayer:get_object() should return a ClientObjectRef")
	end)

	-- Test get_pos on local player
	T.run("ClientObjectRef:get_pos works", function()
		local ref = core.localplayer:get_object()
		T.assert(ref ~= nil, "localplayer:get_object() should return ref")
		if ref then
			local pos = ref:get_pos()
			T.assert(type(pos) == "table", "get_pos should return a table")
			T.assert(type(pos.x) == "number", "pos.x should be a number")
			T.assert(type(pos.y) == "number", "pos.y should be a number")
			T.assert(type(pos.z) == "number", "pos.z should be a number")
		end
	end)

	-- Test get_velocity
	T.run("ClientObjectRef:get_velocity works", function()
		local ref = core.localplayer:get_object()
		if ref then
			local vel = ref:get_velocity()
			T.assert(type(vel) == "table", "get_velocity should return a table")
			T.assert(type(vel.x) == "number", "vel.x should be a number")
		end
	end)

	-- Test get_rotation
	T.run("ClientObjectRef:get_rotation works", function()
		local ref = core.localplayer:get_object()
		if ref then
			local rot = ref:get_rotation()
			T.assert(type(rot) == "table", "get_rotation should return a table")
		end
	end)

	-- Test is_player
	T.run("ClientObjectRef:is_player works", function()
		local ref = core.localplayer:get_object()
		if ref then
			local is_player = ref:is_player()
			T.assert(type(is_player) == "boolean", "is_player should return a boolean")
		end
	end)

	-- Test is_local_player
	T.run("ClientObjectRef:is_local_player works", function()
		local ref = core.localplayer:get_object()
		if ref then
			local is_local = ref:is_local_player()
			T.assert(is_local == true, "local player should report is_local_player=true")
		end
	end)

	-- Test get_name
	T.run("ClientObjectRef:get_name works", function()
		local ref = core.localplayer:get_object()
		if ref then
			local name = ref:get_name()
			T.assert(type(name) == "string", "get_name should return a string")
			T.assert(#name > 0, "player name should not be empty")
		end
	end)

	-- Test get_properties
	T.run("ClientObjectRef:get_properties works", function()
		local ref = core.localplayer:get_object()
		if ref then
			local props = ref:get_properties()
			T.assert(type(props) == "table", "get_properties should return a table")
			T.assert(props.hp_max ~= nil, "properties should have hp_max")
			T.assert(props.nametag ~= nil, "properties should have nametag")
			T.assert(props.textures ~= nil, "properties should have textures")
		end
	end)

	-- Test get_hp
	T.run("ClientObjectRef:get_hp works", function()
		local ref = core.localplayer:get_object()
		if ref then
			local hp = ref:get_hp()
			T.assert(type(hp) == "number", "get_hp should return a number")
		end
	end)

	-- Test get_objects_inside_radius
	T.run("core.get_objects_inside_radius works", function()
		local pos = core.localplayer:get_pos()
		local objs = core.get_objects_inside_radius(pos, 10)
		T.assert(type(objs) == "table", "get_objects_inside_radius should return a table")
		-- Should at least contain the local player
		T.assert(#objs > 0, "should find at least the local player")
	end)

	-- Verify object_refs table exists
	T.run("core.object_refs table exists", function()
		local refs = core.object_refs
		T.assert(type(refs) == "table", "core.object_refs should be a table")
	end)
end
