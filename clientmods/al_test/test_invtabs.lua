-- Tests for the generalized inventory tab framework (core.inv_tabs)

local MC_FS = table.concat({
	"formspec_version[6]",
	"size[11.75,10.9]",
	"list[current_player;armor;0.375,0.375;1,1;1]",
	"style[tab_main;border=false;bgimg=;bgimg_pressed=;noclip=true]",
	"image[0.2,-1.34;1.5,1.44;crafting_creative_active.png]",
	"item_image_button[0.44,-1.1;1,1;mcl_crafting_table:crafting_table;tab_main;]",
	"tooltip[tab_main;Main Inventory]",
	"list[current_player;main;0.375,5.575;9,3;9]",
})

local SFINV_FS = table.concat({
	"size[8,9.1]",
	"tabheader[0,0;sfinv_nav_tabs;Crafting,Main;1;true;false]",
	"list[current_player;main;0,5.2;8,1;]",
	"list[current_player;main;0,6.35;8,3;8]",
})

local GENERIC_FS = "formspec_version[3]size[8,9.1]list[current_player;main;0,5.2;8,1;]"

-- Mineclonia creative inventory (mcl_inventory creative tabs).
local MC_CREATIVE_FS = table.concat({
	"formspec_version[6]",
	"size[13,11.43]",
	"no_prepend[]",
	"listcolors[#9990;#FFF7;#FFF0;#000;#FFF]",
	"bgcolor[#00000000;true]",
	"background9[0,1.34;13,8.75;mcl_base_textures_background9.png;;7]",
	"container[0,1.34]",
	"image[0.525,7.525;0,0;mcl_formspec_itemslot.png]",
	"list[current_player;main;0.375,7.375;9,1;]",
	"list[detached:trash;main;11.625,7.375;1,1;]",
	"image[0.525,1.025;0,0;mcl_formspec_itemslot.png]",
	"scroll_container[0.375,0.875;11.575,6;scroll;vertical;1.25]",
	"list[detached:creative_al_test;main;0,0;9,50;]",
	"scroll_container_end[]",
	"scrollbaroptions[min=0;max=45;smallstep=1;largestep=1;arrows=hide]",
	"scrollbar[11.75,0.825;0.75,6.1;vertical;scroll;0]",
	"label[0.375,0.375;Building Blocks]",
	"style[blocks;border=false;bgimg=;bgimg_pressed=]",
	"style[blocks_outer;border=false;bgimg=crafting_creative_active.png;bgimg_pressed=crafting_creative_active.png]",
	"button[0.2,-1.34;1.5,1.44;blocks_outer;]",
	"item_image_button[0.44,-1.1;1,1;mcl_core:brick_block;blocks;]",
	"tooltip[blocks;Building Blocks]",
	"button[11.3,8.64;1.5,1.44;inv_outer;]",
	"item_image_button[11.54,8.89;1,1;mcl_chests:chest;inv;]",
	"tooltip[inv;Survival Inventory]",
	"container_end[]",
	"p1",
})

function test_invtabs(T)
	T.run("core.inv_tabs framework exists", function()
		T.assert(core.inv_tabs ~= nil, "core.inv_tabs should exist")
		for _, fn in ipairs({
			"register_tab", "get_tabs", "get_active", "set_active", "get_game", "is_open",
		}) do
			T.assert(type(core.inv_tabs[fn]) == "function",
				"core.inv_tabs." .. fn .. " should be a function")
		end
	end)

	T.run("get_game returns a string", function()
		T.assert(type(core.inv_tabs.get_game()) == "string", "get_game should return a string")
	end)

	T.run("register_tab + get_tabs round-trip", function()
		core.inv_tabs.register_tab({
			id = "al_test_tab",
			title = "Test",
			icon = "mcl_core:stone",
			build = function() return "label[1,1;hello]" end,
		})
		local found = false
		for _, t in ipairs(core.inv_tabs.get_tabs()) do
			if t.id == "al_test_tab" then
				found = true
				T.assert(t.title == "Test", "title should be preserved")
				T.assert(t.active == true, "active should default to true")
			end
		end
		T.assert(found, "registered tab should appear in get_tabs()")
	end)

	T.run("duplicate register_tab errors", function()
		local ok = pcall(core.inv_tabs.register_tab, {
			id = "al_test_tab",
			title = "Dup",
			build = function() return "" end,
		})
		T.assert(not ok, "duplicate tab id should raise an error")
	end)

	T.run("set_active/get_active round-trip", function()
		T.assert(core.inv_tabs.set_active("al_test_tab"), "set_active should succeed")
		T.assert_eq(core.inv_tabs.get_active(), "al_test_tab", "get_active should return the set id")
		T.assert(core.inv_tabs.set_active("main"), "set_active('main') should succeed")
		T.assert_eq(core.inv_tabs.get_active(), "main", "get_active('main')")
		T.assert(core.inv_tabs.set_active("does_not_exist") == false, "invalid id should return false")
		core.inv_tabs.set_active("main")
	end)

	T.run("remove_tab removes a registered tab", function()
		core.inv_tabs.register_tab({
			id = "al_remove_test",
			title = "RemoveMe",
			build = function() return "" end,
		})
		T.assert(core.inv_tabs.remove_tab("al_remove_test"), "remove_tab should succeed")
		local found = false
		for _, t in ipairs(core.inv_tabs.get_tabs()) do
			if t.id == "al_remove_test" then found = true end
		end
		T.assert(not found, "removed tab should not be listed")
		T.assert(core.inv_tabs.remove_tab("al_remove_test") == false, "double remove should fail")
	end)

	-- Generic integration (unknown game / no native tab system)
	T.run("generic main wrap adds a tab bar", function()
		local out = core.inv_tabs._build(GENERIC_FS, "main", "generic")
		T.assert(out:find("al_tab_main", 1, true) ~= nil, "main tab button should be injected")
		T.assert(out:find("al_tab_al_test_tab", 1, true) ~= nil, "registered tab button should be injected")
		T.assert(out:find("formspec_version[3]", 1, true) ~= nil, "server formspec should be preserved")
	end)

	T.run("generic page builds a full formspec", function()
		local out = core.inv_tabs._build(GENERIC_FS, "al_test_tab", "generic")
		T.assert(out:find("formspec_version[6]", 1, true) ~= nil, "page should set its own version")
		T.assert(out:find("size[8,9.1]", 1, true) ~= nil, "page should reuse the server size")
		T.assert(out:find("hello", 1, true) ~= nil, "page should include the tab build content")
		T.assert(out:find("al_tab_main", 1, true) ~= nil, "page bar should include the main tab")
		T.assert(out:find("list[current_player;main", 1, true) ~= nil, "page should include inventory lists")
	end)

	-- mineclone* integration (mcl_inventory survival tab row)
	T.run("mineclonia main wrap appends tabs after native bar", function()
		local out = core.inv_tabs._build(MC_FS, "main", "mineclonia")
		T.assert(out:find("crafting_creative_active.png", 1, true) ~= nil, "native bar should be preserved")
		T.assert(out:find("tab_main", 1, true) ~= nil, "native tab button should be preserved")
		T.assert(out:match("item_image_button%[[^%]]*al_tab_al_test_tab[^%]]*%]") ~= nil,
			"our icon tab should be appended to the row")
	end)

	T.run("mineclonia page re-renders native + our tabs", function()
		local out = core.inv_tabs._build(MC_FS, "al_test_tab", "mineclonia")
		T.assert(out:find("tab_main", 1, true) ~= nil, "native tab should be re-rendered")
		T.assert(out:find("al_tab_al_test_tab", 1, true) ~= nil, "our tab should be rendered active")
		T.assert(out:find("size[11.75,10.9]", 1, true) ~= nil, "page should use the native size")
		T.assert(out:find("list[current_player;main;0.375,5.575", 1, true) ~= nil,
			"page should include inventory lists")
	end)

	T.run("mineclonia main wrap shows Main tab when no native bar rendered", function()
		local fs = "formspec_version[6]size[11.75,10.9]list[current_player;main;0.375,5.575;9,3;9]"
		local out = core.inv_tabs._build(fs, "main", "mineclonia")
		T.assert(out:find("al_tab_main", 1, true) ~= nil, "main view should show a Main tab button")
		T.assert(out:find("crafting_creative_active.png", 1, true) ~= nil,
			"the Main tab should render as the active tab")
	end)

	T.run("mineclonia page adds Main button when no native bar rendered", function()
		local fs = "formspec_version[6]size[11.75,10.9]list[current_player;main;0.375,5.575;9,3;9]"
		local out = core.inv_tabs._build(fs, "al_test_tab", "mineclonia")
		T.assert(out:find("al_tab_main", 1, true) ~= nil, "page should include a Main button")
		T.assert(out:find("al_tab_al_test_tab", 1, true) ~= nil, "our tab should be rendered")
	end)

	T.run("unrecognized formspec falls back to a tab bar", function()
		local creative = "formspec_version[6]size[13,11.43]tabheader[0,0;foo;A,B;1]"
		local out = core.inv_tabs._build(creative, "main", "generic")
		T.assert(out:find("al_tab_main", 1, true) ~= nil, "generic bar should be injected")
		T.assert(out:find("size[13,11.43]", 1, true) ~= nil, "original size should be preserved")
	end)

	-- mineclone* creative inventory (left-side tab column + shifted content)
	T.run("creative main wrap is auto-detected and adds the side column", function()
		local out = core.inv_tabs._build(MC_CREATIVE_FS, "main")
		T.assert(out:find("size[14.3,11.43]", 1, true) ~= nil,
			"creative form should grow to fit the side column")
		T.assert(out:find("size[13,11.43]", 1, true) == nil, "original size should be replaced")
		T.assert(out:find("background9[0,1.34;14.3,8.75;", 1, true) ~= nil,
			"themed panel should stretch to the grown width")
		T.assert(out:find("al_tab_main", 1, true) ~= nil, "side column should include the Main tab")
		T.assert(out:find("al_tab_al_test_tab", 1, true) ~= nil, "side column should include our tab")
		T.assert(out:find("button[0.2,1.6;1.2,0.9;al_tab_main;", 1, true) ~= nil,
			"Main button should sit at the top of the left column")
		T.assert(out:find("p1", 1, true) ~= nil, "trailing pagenum marker should be preserved")
	end)

	T.run("creative wrap shifts native content right", function()
		local out = core.inv_tabs._build(MC_CREATIVE_FS, "main", "mineclonia_creative")
		T.assert(out:find("list[current_player;main;1.675,7.375;9,1;]", 1, true) ~= nil,
			"hotbar list should shift right")
		T.assert(out:find("list[detached:trash;main;12.925,7.375;1,1;]", 1, true) ~= nil,
			"trash slot should shift right")
		T.assert(out:find("scroll_container[1.675,0.875;11.575,6;", 1, true) ~= nil,
			"scroll_container should shift right")
		T.assert(out:find("list[detached:creative_al_test;main;0,0;9,50;]", 1, true) ~= nil,
			"list inside scroll_container should keep relative coords")
		T.assert(out:find("scrollbar[13.05,0.825;0.75,6.1;", 1, true) ~= nil,
			"scrollbar should shift right")
		T.assert(out:find("button[1.5,-1.34;1.5,1.44;blocks_outer;]", 1, true) ~= nil,
			"native top tab should shift right")
		T.assert(out:find("item_image_button[1.74,-1.1;1,1;mcl_core:brick_block;blocks;]", 1, true) ~= nil,
			"native tab icon should shift right")
		T.assert(out:find("button[12.6,8.64;1.5,1.44;inv_outer;]", 1, true) ~= nil,
			"native inv tab should shift right")
		T.assert(out:find("style[blocks;border=false;bgimg=;bgimg_pressed=]", 1, true) ~= nil,
			"style elements should be preserved")
		T.assert(out:find("tooltip[blocks;Building Blocks]", 1, true) ~= nil,
			"tooltip elements should be preserved")
		T.assert(out:find("container[0,1.34]", 1, true) ~= nil, "native container should be preserved")
	end)

	T.run("creative page builds a full formspec with the side column", function()
		local out = core.inv_tabs._build(MC_CREATIVE_FS, "al_test_tab", "mineclonia_creative")
		T.assert(out:find("size[14.3,11.43]", 1, true) ~= nil, "page should use the grown creative size")
		T.assert(out:find("al_tab_al_test_tab", 1, true) ~= nil, "page should include the active tab button")
		T.assert(out:find("al_tab_main", 1, true) ~= nil, "page should include a Main button")
		T.assert(out:find("hello", 1, true) ~= nil, "page should include the tab build content")
	end)

	T.run("creative resolve routes our tabs", function()
		core.inv_tabs.set_active("al_test_tab")
		core.inv_tabs._handle({ al_tab_main = "" }, "mineclonia_creative")
		T.assert_eq(core.inv_tabs.get_active(), "main", "al_tab_main should return to the native form")
		core.inv_tabs._handle({ al_tab_poi = "" }, "mineclonia_creative")
		T.assert_eq(core.inv_tabs.get_active(), "poi", "al_tab_poi should activate the poi tab")
		core.inv_tabs._handle({ al_tab_al_test_tab = "" }, "mineclonia_creative")
		T.assert_eq(core.inv_tabs.get_active(), "al_test_tab", "al_tab_al_test_tab should activate our tab")
		core.inv_tabs.set_active("main")
	end)

	-- sfinv integration (minetest_game tabheader)
	-- Returns the index of `title` in a tabheader element, or nil.
	local function tabheader_index(th, title)
		local params = th:match("^tabheader%[([^%]]*)%]$")
		if not params then return nil end
		local parts = {}
		for part in params:gmatch("[^;]+") do
			parts[#parts + 1] = part
		end
		if not parts[3] then return nil end
		local i = 0
		for t in parts[3]:gmatch("[^,]+") do
			i = i + 1
			if t == title then return i end
		end
		return nil
	end

	T.run("sfinv main wrap appends titles to the tabheader", function()
		local out = core.inv_tabs._build(SFINV_FS, "main", "sfinv")
		local th = out:match("tabheader%[[^%]]*%]")
		T.assert(th ~= nil, "tabheader should be present")
		T.assert(th:find("Crafting,Main", 1, true) ~= nil, "native titles should be preserved")
		T.assert(tabheader_index(th, "Test") ~= nil, "our title should be appended")
		T.assert(th:find(";1;", 1, true) ~= nil, "current index should stay at the native index")
	end)

	T.run("sfinv page sets the current index to our tab", function()
		local out = core.inv_tabs._build(SFINV_FS, "al_test_tab", "sfinv")
		local th = out:match("tabheader%[[^%]]*%]")
		T.assert(th ~= nil, "tabheader should be present")
		local idx = tabheader_index(th, "Test")
		T.assert(idx ~= nil, "tabheader should include our title")
		T.assert(th:find(";" .. idx .. ";", 1, true) ~= nil,
			"current index should point at our tab (" .. idx .. ")")
		T.assert(out:find("hello", 1, true) ~= nil, "page should include the tab build content")
	end)

	-- poi mod registers itself as an inventory tab
	T.run("poi registers itself as an inventory tab", function()
		T.assert(type(poi) == "table", "poi module should be loaded")
		T.assert(type(poi.build_formspec_content) == "function",
			"poi.build_formspec_content should exist")
		local found = false
		for _, t in ipairs(core.inv_tabs.get_tabs()) do
			if t.id == "poi" then
				found = true
				T.assert_eq(t.title, "Waypoints", "poi tab title")
				T.assert(t.active == true, "poi tab should be active")
			end
		end
		T.assert(found, "poi tab should be registered")
	end)

	T.run("poi tab page embeds poi content", function()
		local out = core.inv_tabs._build(GENERIC_FS, "poi", "generic")
		T.assert(out:find("wp_list", 1, true) ~= nil, "poi waypoint list should be embedded")
		T.assert(out:find("poi_show_all", 1, true) ~= nil, "poi header should be embedded")
		T.assert(out:find("al_tab_poi", 1, true) ~= nil, "poi tab button should be rendered")
	end)

	T.run("poi tab handle consumes poi fields", function()
		T.assert(poi.handle_fields({}) == true, "empty fields should be consumed by poi")
	end)

	-- autocraft registers itself as an inventory tab
	T.run("autocraft registers itself as an inventory tab", function()
		T.assert(type(autocraft) == "table", "autocraft module should be loaded")
		T.assert(type(autocraft.build_gui_content) == "function",
			"autocraft.build_gui_content should exist")
		local found = false
		for _, t in ipairs(core.inv_tabs.get_tabs()) do
			if t.id == "autocraft" then
				found = true
				T.assert_eq(t.title, "Autocraft", "autocraft tab title")
				T.assert(t.active == true, "autocraft tab should be active")
			end
		end
		T.assert(found, "autocraft tab should be registered")
	end)

	T.run("autocraft tab page embeds the crafting GUI", function()
		local out = core.inv_tabs._build(GENERIC_FS, "autocraft", "generic")
		T.assert(out:find("autocraft_toggle", 1, true) ~= nil, "autocraft toggle button should be embedded")
		T.assert(out:find("list[current_player;craft", 1, true) ~= nil, "craft grid should be embedded")
		T.assert(out:find("al_tab_autocraft", 1, true) ~= nil, "autocraft tab button should be rendered")
	end)

	T.run("autocraft tab handle consumes fields", function()
		T.assert(autocraft.handle_gui_fields({}) == true, "empty fields should be consumed by autocraft")
	end)

	-- openInv registers itself as an inventory tab
	T.run("openinv registers itself as an inventory tab", function()
		T.assert(type(invviewer) == "table", "invviewer module should be loaded")
		T.assert(type(invviewer.build_content) == "function",
			"invviewer.build_content should exist")
		local found = false
		for _, t in ipairs(core.inv_tabs.get_tabs()) do
			if t.id == "openinv" then
				found = true
				T.assert_eq(t.title, "Inventories", "openinv tab title")
				T.assert(t.active == true, "openinv tab should be active")
			end
		end
		T.assert(found, "openinv tab should be registered")
	end)

	T.run("openinv tab handle consumes fields", function()
		T.assert(invviewer.handle_fields({}) == true, "empty fields should be consumed by openinv")
	end)

	-- Deferred until core.localplayer exists (openInv's re-render reads it)
	T.defer("openinv tab page embeds the inventory viewer", function()
		local out = core.inv_tabs._build(GENERIC_FS, "openinv", "generic")
		T.assert(out:find("al_subtab_openinv_0", 1, true) ~= nil, "openinv sub-tab button should be embedded")
		T.assert(out:find("al_subtab_openinv_1", 1, true) ~= nil, "openinv sub-tab button should be embedded")
		T.assert(out:find("select_list", 1, true) ~= nil, "openinv list selector should be embedded")
		T.assert(out:find("al_tab_openinv", 1, true) ~= nil, "openinv tab button should be rendered")
	end)

	T.defer("openinv sub-tab button switches the view", function()
		local ok, err = pcall(invviewer.handle_fields, { al_subtab_openinv_1 = "Nearby" })
		T.assert(ok, "sub-tab click should not error: " .. tostring(err))
		T.assert(invviewer.handle_fields({ al_subtab_openinv_0 = "Inventories" }) == true,
			"sub-tab click should be consumed")
	end)

	-- schembuilder registers itself as an inventory tab
	T.run("schembuilder registers itself as an inventory tab", function()
		T.assert(type(schembuilder) == "table", "schembuilder module should be loaded")
		T.assert(type(schembuilder.build_browser_content) == "function",
			"schembuilder.build_browser_content should exist")
		local found = false
		for _, t in ipairs(core.inv_tabs.get_tabs()) do
			if t.id == "schembuilder" then
				found = true
				T.assert_eq(t.title, "Schematics", "schembuilder tab title")
				T.assert(t.active == true, "schembuilder tab should be active")
			end
		end
		T.assert(found, "schembuilder tab should be registered")
	end)

	T.run("schembuilder tab page embeds content + sub-tabs", function()
		local out = core.inv_tabs._build(GENERIC_FS, "schembuilder", "generic")
		for i = 0, 4 do
			T.assert(out:find("al_subtab_schembrowser_" .. i, 1, true) ~= nil,
				"schembuilder sub-tab button " .. i .. " should be embedded")
		end
		T.assert(out:find("al_tab_schembuilder", 1, true) ~= nil,
			"schembuilder tab button should be rendered")
	end)

	T.run("schembuilder tab handle consumes fields", function()
		T.assert(schembuilder.handle_browser_fields({}) == true,
			"empty fields should be consumed by schembuilder")
		T.assert(schembuilder.handle_browser_fields({ al_subtab_schembrowser_1 = "Saved Builds" }) == true,
			"sub-tab click should be consumed by schembuilder")
	end)

	-- Tab content padding
	T.run("simple tabs get container padding", function()
		local out = core.inv_tabs._build(GENERIC_FS, "autocraft", "generic")
		T.assert(out:find("container[0.25,0.25]", 1, true) ~= nil,
			"simple tab content should be padded")
		T.assert(out:find("container_end[]", 1, true) ~= nil,
			"padded content should close the container")
	end)

	T.run("sub-tab tabs skip container padding", function()
		local out = core.inv_tabs._build(GENERIC_FS, "schembuilder", "generic")
		T.assert(out:find("container[0.25,0.25]", 1, true) == nil,
			"sub-tab-managed tabs manage their own layout")
	end)

	-- dte registers itself as an inventory tab named "Code"
	T.run("dte registers itself as an inventory tab", function()
		T.assert(type(dte) == "table", "dte module should be loaded")
		T.assert(type(dte.build_content) == "function", "dte.build_content should exist")
		local found = false
		for _, t in ipairs(core.inv_tabs.get_tabs()) do
			if t.id == "dte" then
				found = true
				T.assert_eq(t.title, "Code", "dte tab title")
				T.assert(t.active == true, "dte tab should be active")
			end
		end
		T.assert(found, "dte tab should be registered")
	end)

	T.run("dte tab page embeds editor content + sub-tabs", function()
		local out = core.inv_tabs._build(GENERIC_FS, "dte", "generic")
		T.assert(out:find("codeedit", 1, true) ~= nil or out:find("textarea", 1, true) ~= nil,
			"editor widget should be embedded")
		T.assert(out:find("al_subtab_dte_0", 1, true) ~= nil, "sub-tab button should be embedded")
		T.assert(out:find("al_subtab_dte_5", 1, true) ~= nil, "sub-tab button should be embedded")
		T.assert(out:find("al_tab_dte", 1, true) ~= nil, "dte tab button should be rendered")
	end)

	T.run("dte tab handle consumes fields", function()
		T.assert(dte.handle_tab_fields({}) == true, "empty fields should be consumed by dte")
		T.assert(dte.handle_tab_fields({ al_subtab_dte_1 = "Lua Console" }) == true,
			"sub-tab click should be consumed by dte")
	end)

	T.run("framework routes non-tab fields to the active tab handle", function()
		local called
		core.inv_tabs.register_tab({
			id = "al_handle_test",
			title = "HandleTest",
			build = function() return "button[1,1;1,1;htest;X]" end,
			handle = function(fields)
				called = fields.htest
				return true
			end,
		})
		core.inv_tabs.set_active("al_handle_test")
		core.inv_tabs._handle({ htest = "X" })
		T.assert_eq(called, "X", "active tab handle should receive non-tab fields")
		core.inv_tabs.set_active("main")
	end)

	T.run("framework processes button_exit action before quit", function()
		local called
		core.inv_tabs.register_tab({
			id = "al_quit_test",
			title = "QuitTest",
			build = function() return "" end,
			handle = function(fields)
				called = fields.quit_action
				return true
			end,
		})
		core.inv_tabs.set_active("al_quit_test")
		core.inv_tabs._handle({ quit_action = "Go", quit = "true" })
		T.assert_eq(called, "Go", "button_exit action should reach the tab handle before quit")
		T.assert(core.inv_tabs.is_open() == false, "quit submission should mark the form closed")
		core.inv_tabs.set_active("main")
	end)

	T.run("framework closes form state on plain quit", function()
		local called
		core.inv_tabs.register_tab({
			id = "al_quit_test2",
			title = "QuitTest2",
			build = function() return "" end,
			handle = function(fields)
				called = true
				return true
			end,
		})
		core.inv_tabs.set_active("al_quit_test2")
		core.inv_tabs._handle({ quit = "true" })
		T.assert(called, "tab handle should still see the plain quit submission")
		T.assert(core.inv_tabs.is_open() == false, "plain quit should mark the form closed")
		core.inv_tabs.set_active("main")
	end)

	-- Deferred until core.localplayer exists (poi's re-render reads it)
	T.defer("framework routes poi button clicks to poi.handle_fields", function()
		core.inv_tabs.set_active("poi")
		local ok, err = pcall(core.inv_tabs._handle, { sort_toggle = "Dist" })
		if not ok then
			core.log("warning", "[AL_TEST] poi button click error: " .. tostring(err))
		end
		T.assert(ok, "poi button click through the framework should not error")
		core.inv_tabs.set_active("main")
	end)

	-- Restore clean state: drop the test-only tabs so they don't clutter the
	-- player's real inventory tab bar.
	core.inv_tabs.remove_tab("al_test_tab")
	core.inv_tabs.remove_tab("al_handle_test")
	core.inv_tabs.remove_tab("al_quit_test")
	core.inv_tabs.remove_tab("al_quit_test2")
	core.inv_tabs.set_active("main")
end
