-- Tests for the unified layer system + cheat-menu desktops (tabs)

function test_layers(T)
	T.run("default desktops exist", function()
		local ok, err = pcall(function()
			return core.get_cheat_desktops()
		end)
		T.assert(ok, "get_cheat_desktops callable")
		local desktops = ok and err or {}
		T.assert(#desktops >= 3, "at least 3 default desktops, got " .. #desktops)
		local ids = {}
		for _, d in ipairs(desktops) do
			ids[d.id] = d
		end
		T.assert(ids.cheats ~= nil, "cheats desktop present")
		T.assert(ids.menu ~= nil, "menu desktop present")
		T.assert(ids.palette ~= nil, "palette desktop present")
		T.assert(ids.cheats.fullscreen == false, "cheats desktop is a panel workspace")
		T.assert(ids.menu.fullscreen == true, "menu desktop is fullscreen")
		T.assert(ids.palette.fullscreen == true, "palette desktop is fullscreen")
	end)

	T.run("switch desktop by id", function()
		local ok = core.cheat_desktop_show("menu")
		T.assert(ok == true, "switch to menu desktop succeeds")
		local desktops = core.get_cheat_desktops()
		for _, d in ipairs(desktops) do
			if d.id == "menu" then
				T.assert(d.active == true, "menu desktop is now active")
			else
				T.assert(d.active == false, d.id .. " desktop is inactive")
			end
		end
		-- restore
		T.assert(core.cheat_desktop_show("cheats") == true, "switch back to cheats")
	end)

	T.run("switch desktop unknown id fails", function()
		local ok = core.cheat_desktop_show("nonexistent_desktop_xyz")
		T.assert(ok == false, "unknown desktop id returns false")
	end)

	T.run("register_cheat_desktop", function()
		local drew = false
		local ok = core.register_cheat_desktop("test_desktop", {
			title = "Test Desktop",
			fullscreen = true,
			on_draw = function() drew = true end,
		})
		T.assert(ok == true, "register_cheat_desktop returns true")
		local found = nil
		for _, d in ipairs(core.get_cheat_desktops()) do
			if d.id == "test_desktop" then found = d end
		end
		T.assert(found ~= nil, "registered desktop listed")
		T.assert(found.title == "Test Desktop", "registered desktop title")
		T.assert(found.fullscreen == true, "registered desktop fullscreen")
		local ok2 = core.cheat_desktop_show("test_desktop")
		T.assert(ok2 == true, "switch to registered desktop")
		T.assert(core.cheat_desktop_show("cheats") == true, "switch back")
		T.assert(drew == false, "on_draw not called while desktop inactive")
	end)

	T.run("register_cheat_desktop rejects duplicates", function()
		local ok, err = pcall(core.register_cheat_desktop, "test_desktop", {
			title = "Duplicate",
		})
		T.assert(not ok, "duplicate desktop id errors")
		T.assert(type(err) == "string" and err:find("already exists") ~= nil,
			"duplicate error mentions existing desktop")
	end)

	T.run("layer API functions exist", function()
		T.assert(type(core.layer_show) == "function", "core.layer_show")
		T.assert(type(core.layer_hide) == "function", "core.layer_hide")
		T.assert(type(core.layer_toggle) == "function", "core.layer_toggle")
		T.assert(type(core.layer_is_visible) == "function", "core.layer_is_visible")
		T.assert(type(core.get_layers) == "function", "core.get_layers")
		T.assert(type(core.register_layer) == "function", "core.register_layer")
		T.assert(type(core.draw_rect) == "function", "core.draw_rect")
		T.assert(type(core.draw_text) == "function", "core.draw_text")
		T.assert(type(core.draw_texture) == "function", "core.draw_texture")
	end)

	T.run("default layers registered", function()
		local layers = core.get_layers()
		T.assert(type(layers) == "table" and #layers >= 3,
			"at least 3 default layers, got " .. #layers)
		local ids = {}
		for _, l in ipairs(layers) do
			ids[l.id] = l
		end
		T.assert(ids.cheat ~= nil, "cheat layer present")
		T.assert(ids.quick_palette ~= nil, "quick_palette layer present")
		T.assert(ids.bigmap ~= nil, "bigmap layer present")
		T.assert(ids.cheat.type == "container", "cheat layer is a container")
		T.assert(ids.bigmap.type == "fullscreen", "bigmap layer is fullscreen")
	end)

	T.run("register_layer + show/hide/toggle/is_visible", function()
		local ok = core.register_layer("test_layer", {
			title = "Test Layer",
			opaque = true,
		})
		T.assert(ok == true, "register_layer returns true")
		T.assert(core.layer_is_visible("test_layer") == false,
			"newly registered layer starts hidden")
		T.assert(core.layer_show("test_layer") == true, "layer_show makes visible")
		T.assert(core.layer_is_visible("test_layer") == true, "is_visible true")
		T.assert(core.layer_hide("test_layer") == true, "layer_hide hides")
		T.assert(core.layer_is_visible("test_layer") == false, "is_visible false")
		T.assert(core.layer_toggle("test_layer") == true, "toggle shows")
		T.assert(core.layer_is_visible("test_layer") == true, "toggle left visible")
		core.layer_hide("test_layer")
	end)

	T.run("register_layer rejects duplicates", function()
		local ok, err = pcall(core.register_layer, "test_layer", { title = "Dup" })
		T.assert(not ok, "duplicate layer id errors")
		T.assert(type(err) == "string" and err:find("already exists") ~= nil,
			"duplicate layer error mentions existing layer")
	end)

	T.run("layer_is_visible unknown id", function()
		T.assert(core.layer_is_visible("nonexistent_layer_xyz") == false,
			"unknown layer is not visible")
	end)

	T.run("draw queue functions accept args without error", function()
		T.assert(core.draw_rect(10, 10, 20, 20, "#ff0000") == nil,
			"draw_rect queues a rect")
		T.assert(core.draw_text("hello", 0, 0, 0, "#ffffff") == nil,
			"draw_text queues text with default size")
		T.assert(core.draw_text("hello", 0, 0, 24, "#ffffff") == nil,
			"draw_text queues text with explicit font size")
		T.assert(core.draw_texture("default_stone.png", 0, 0, 16, 16) == nil,
			"draw_texture queues a texture")
	end)

	T.run("register_layer accepts on_draw/on_input callbacks", function()
		local ok = core.register_layer("test_layer_callbacks", {
			title = "Callback Layer",
			opaque = true,
			on_draw = function() end,
			on_input = function(ev) return false end,
		})
		T.assert(ok == true, "register_layer with callbacks returns true")
		local layers = core.get_layers()
		local found = nil
		for _, l in ipairs(layers) do
			if l.id == "test_layer_callbacks" then found = l end
		end
		T.assert(found ~= nil, "callback layer listed")
		T.assert(core.layer_is_visible("test_layer_callbacks") == false,
			"callback layer starts hidden")
		core.layer_hide("test_layer_callbacks")
	end)

	T.run("layer on_draw is invoked while visible", function()
		local drew = false
		local ok = core.register_layer("test_layer_draw", {
			title = "Draw Layer",
			on_draw = function()
				drew = true
				core.draw_text("layer draw", 5, 5, 24, "#ffffff")
				core.draw_rect(1, 1, 10, 10, "#ff0000")
				core.draw_texture("default_stone.png", 10, 10, 16, 16)
			end,
		})
		if not ok then
			T.assert(false, "register_layer failed")
			return
		end
		core.layer_show("test_layer_draw")
		local attempts = 20 -- 20 * 0.25s = 5s timeout
		local function poll()
			if drew then
				core.layer_hide("test_layer_draw")
				core.log("info", "[AL_TEST] PASS: layer on_draw invoked (async)")
			elseif attempts > 0 then
				attempts = attempts - 1
				core.after(0.25, poll)
			else
				core.layer_hide("test_layer_draw")
				error("layer on_draw never called (timeout)")
			end
		end
		core.after(0.25, poll)
	end)

	T.run("desktop settings exist", function()
		T.assert(core.settings:get("cheat_menu_desktop") ~= nil,
			"cheat_menu_desktop setting present")
		T.assert(core.settings:get("keymap_cheat_desktop_next") ~= nil,
			"keymap_cheat_desktop_next present")
		T.assert(core.settings:get("keymap_cheat_desktop_prev") ~= nil,
			"keymap_cheat_desktop_prev present")
	end)

	T.run("cheat layer visibility is queryable via layer API", function()
		-- Toggling the cheat layer through its Lua binding updates the layer
		-- manager state; the cheat layer should appear in get_layers().
		local layers = core.get_layers()
		local cheat = nil
		for _, l in ipairs(layers) do
			if l.id == "cheat" then cheat = l end
		end
		T.assert(cheat ~= nil, "cheat layer listed")
		T.assert(type(cheat.visible) == "boolean", "cheat layer reports visibility")
	end)
end