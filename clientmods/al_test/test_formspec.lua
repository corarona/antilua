-- Tests for al_formspec library

function test_formspec(T)
	T.run("al_formspec global exists", function()
		T.assert(core.al_formspec ~= nil, "core.al_formspec should exist")
		T.assert(type(core.al_formspec) == "table", "core.al_formspec should be a table")
	end)

	T.run("al_formspec.new() returns stringbuilder", function()
		local sb = core.al_formspec.new()
		T.assert(sb ~= nil, "new() should return a table")
		T.assert(type(sb.add) == "function", "stringbuilder should have add method")
		T.assert(type(sb.get) == "function", "stringbuilder should have get method")
	end)

	T.run("al_formspec.new():add():get() concatenates", function()
		local sb = core.al_formspec.new()
		sb:add("a", "b", "c")
		T.assert_eq(sb:get(), "abc", "add+get should concatenate strings")
	end)

	T.run("al_formspec.new():add() skips nil values", function()
		local sb = core.al_formspec.new()
		sb:add("a", nil, "b")
		T.assert_eq(sb:get(), "ab", "nil values should be skipped")
	end)

	T.run("al_formspec.new():add() flattens tables", function()
		local sb = core.al_formspec.new()
		sb:add({"a", "b", "c"})
		T.assert_eq(sb:get(), "abc", "table args should be flattened")
	end)

	T.run("al_formspec.begin() includes no_prepend and bgcolor", function()
		local result = core.al_formspec.begin("size[8,6]")
		local s = result:get()
		T.assert(s:find("no_prepend") ~= nil, "begin() should include no_prepend[]")
		T.assert(s:find("bgcolor") ~= nil, "begin() should include bgcolor[]")
		local theme_bg = core.settings:get("theme_bg") or "#121212"
		T.assert(s:find(theme_bg) ~= nil, "begin() should use theme bg color (" .. theme_bg .. ")")
		T.assert(s:find("formspec_version") ~= nil, "begin() should include formspec_version")
	end)

	T.run("al_formspec.begin() includes size arg", function()
		local result = core.al_formspec.begin("size[8,6]")
		local s = result:get()
		T.assert(s:find("size%[8,6%]") ~= nil, "begin() should include the size argument")
	end)

	T.run("al_formspec.escape wraps core.formspec_escape", function()
		local s = core.al_formspec.escape("hello [world]")
		T.assert(type(s) == "string", "escape should return a string")
	end)

	T.run("al_formspec.bar produces correct ratio", function()
		local full = core.al_formspec.bar(10, 10, 10)
		local full_filled = select(2, full:gsub("█", ""))
		local full_empty = select(2, full:gsub("░", ""))
		T.assert_eq(full_filled, 10, "full bar: 10 filled")
		T.assert_eq(full_empty, 0, "full bar: 0 empty")

		local empty = core.al_formspec.bar(0, 10, 10)
		local empty_filled = select(2, empty:gsub("█", ""))
		local empty_empty = select(2, empty:gsub("░", ""))
		T.assert_eq(empty_filled, 0, "empty bar: 0 filled")
		T.assert_eq(empty_empty, 10, "empty bar: 10 empty")

		local half = core.al_formspec.bar(5, 10, 10)
		local half_filled = select(2, half:gsub("█", ""))
		local half_empty = select(2, half:gsub("░", ""))
		T.assert_eq(half_filled, 5, "half bar: 5 filled")
		T.assert_eq(half_empty, 5, "half bar: 5 empty")
	end)

	T.run("al_formspec.bar defaults to 10 segments", function()
		local bar = core.al_formspec.bar(10, 10)
		local filled = select(2, bar:gsub("█", ""))
		local empty = select(2, bar:gsub("░", ""))
		T.assert_eq(filled + empty, 10, "default bar should be 10 segments")
	end)

	T.run("al_formspec.bar clamps values", function()
		T.assert_eq(core.al_formspec.bar(-1, 10, 5), string.rep("░", 5), "negative filled clamps to 0")
		T.assert_eq(core.al_formspec.bar(20, 10, 5), string.rep("█", 5), "overfilled clamps to max")
	end)

	T.run("al_formspec.label produces correct format", function()
		local result = core.al_formspec.label(0.5, 1, "Hello")
		T.assert_eq(result, "label[0.5,1;Hello]", "label format")
	end)

	T.run("al_formspec.label escapes text", function()
		local result = core.al_formspec.label(0, 0, "a[b]c")
		T.assert(result:find("a%[b%]c") == nil, "label should escape brackets")
	end)

	T.run("al_formspec.button produces correct format", function()
		local result = core.al_formspec.button(0, 1, 2, 0.8, "btn_ok", "OK")
		T.assert_eq(result, "button[0,1;2,0.8;btn_ok;OK]", "button format")
	end)

	T.run("al_formspec.button_exit produces correct format", function()
		local result = core.al_formspec.button_exit(0, 0, 1, 1, "close", "Close")
		T.assert_eq(result, "button_exit[0,0;1,1;close;Close]", "button_exit format")
	end)

	T.run("al_formspec.field produces correct format", function()
		local result = core.al_formspec.field(0, 0, 5, 0.8, "input", "Name", "default")
		T.assert(result:find("field") ~= nil, "field should start with field[")
		T.assert(result:find("Name") ~= nil, "field should include label")
		T.assert(result:find("default") ~= nil, "field should include default")
	end)

	T.run("al_formspec.field works without default", function()
		local result = core.al_formspec.field(0, 0, 5, 0.8, "input", "Name")
		T.assert(result ~= nil, "field without default should work")
	end)

	T.run("al_formspec.textlist produces correct format", function()
		local result = core.al_formspec.textlist(0, 0, 5, 3, "mylist", {"a", "b", "c"})
		T.assert(result:find("textlist") ~= nil, "textlist should start with textlist[")
		T.assert(result:find("mylist") ~= nil, "textlist should include id")
		T.assert(result:find(",b,") ~= nil or result:find("a,b,c") ~= nil, "textlist should include items")
	end)

	T.run("al_formspec.textlist handles empty items", function()
		local result = core.al_formspec.textlist(0, 0, 5, 3, "empty", {})
		T.assert(result ~= nil, "textlist with empty items should not crash")
	end)

	T.run("al_formspec.dropdown produces correct format", function()
		local result = core.al_formspec.dropdown(0, 0, 3, "mode", {"a", "b", "c"}, 1)
		T.assert(result:find("dropdown") ~= nil, "dropdown should start with dropdown[")
		T.assert(result:find("mode") ~= nil, "dropdown should include id")
		T.assert(result:find(",b,") ~= nil or result:find("a,b,c") ~= nil, "dropdown should include items")
	end)

	T.run("al_formspec.image produces correct format", function()
		local result = core.al_formspec.image(0, 0, 1, 1, "test.png")
		T.assert_eq(result, "image[0,0;1,1;test.png]", "image format")
	end)

	T.run("al_formspec.bgcolor produces correct format", function()
		local result = core.al_formspec.bgcolor("#000", true)
		T.assert_eq(result, "bgcolor[#000;true]", "bgcolor format")
	end)

	T.run("al_formspec.padding produces correct format", function()
		local result = core.al_formspec.padding(0.5, 0.5)
		T.assert_eq(result, "padding[0.5,0.5]", "padding format")
	end)

	T.run("al_formspec.textlist_event parses CHG", function()
		local ev = core.al_formspec.textlist_event("CHG:3")
		T.assert(ev ~= nil, "CHG should be parsed")
		T.assert_eq(ev.type, "CHG", "type should be CHG")
		T.assert_eq(ev.idx, 3, "idx should be 3")
	end)

	T.run("al_formspec.textlist_event parses DCL", function()
		local ev = core.al_formspec.textlist_event("DCL:1")
		T.assert(ev ~= nil, "DCL should be parsed")
		T.assert_eq(ev.type, "DCL", "type should be DCL")
		T.assert_eq(ev.idx, 1, "idx should be 1")
	end)

	T.run("al_formspec.textlist_event returns nil for empty", function()
		T.assert(core.al_formspec.textlist_event("") == nil, "empty string should return nil")
		T.assert(core.al_formspec.textlist_event(nil) == nil, "nil should return nil")
	end)

	T.run("al_formspec.textlist_selected returns correct item", function()
		local items = {"a", "b", "c"}
		T.assert_eq(core.al_formspec.textlist_selected(items, "CHG:2"), "b", "should return second item")
		T.assert(core.al_formspec.textlist_selected(items, "CHG:99") == nil, "out of range should return nil")
		T.assert(core.al_formspec.textlist_selected({}, "CHG:1") == nil, "empty list should return nil")
	end)

	T.run("al_formspec.color wraps core.colorize", function()
		local s = core.al_formspec.color("#ff0", "test")
		T.assert(type(s) == "string", "color should return a string")
	end)

	-- textlist with selected_idx
	T.run("al_formspec.textlist with selected_idx", function()
		local result = core.al_formspec.textlist(0, 0, 5, 3, "mylist", {"a", "b"}, 2)
		T.assert(result:match(";2%]") ~= nil, "should end with ;2]")
		local result0 = core.al_formspec.textlist(0, 0, 5, 3, "empty", {}, 0)
		T.assert(result0:match(";0%]") ~= nil, "empty list with selected_idx=0")
	end)

	-- searchbar
	T.run("al_formspec.searchbar returns {field, button}", function()
		local result = core.al_formspec.searchbar(0, 0, 8.2, "filter")
		T.assert(type(result) == "table", "should be a table")
		T.assert_eq(#result, 2, "should have 2 elements")
		T.assert(result[1]:find("^field%[") ~= nil, "first element should be field")
		T.assert(result[2]:find("^button%[") ~= nil, "second element should be button")
		T.assert(result[2]:find("__filter_search") ~= nil, "button id should be __<id>_search")
	end)

	T.run("al_formspec.searchbar uses custom opts", function()
		local result = core.al_formspec.searchbar(0, 0, 8.2, "test", {
			placeholder = "Search:", button = "Find", default = "abc",
		})
		T.assert(result[1]:find("Search:") ~= nil, "should use custom placeholder")
		T.assert(result[2]:find("Find") ~= nil, "should use custom button label")
		T.assert(result[1]:find("abc") ~= nil, "should include default value")
	end)

	-- confirm_layout
	T.run("al_formspec.confirm_layout returns {label, btn, btn}", function()
		local result = core.al_formspec.confirm_layout(0, 0, 6, "Are you sure?", "yes_btn", "no_btn")
		T.assert(type(result) == "table", "should be a table")
		T.assert_eq(#result, 3, "should have 3 elements")
		T.assert(result[1]:find("^label%[") ~= nil, "first should be label")
		T.assert(result[2]:find("no_btn") ~= nil, "second should be no button")
		T.assert(result[3]:find("yes_btn") ~= nil, "third should be yes button")
	end)

	T.run("al_formspec.confirm_layout custom labels", function()
		local result = core.al_formspec.confirm_layout(0, 0, 6, "text", "ok", "cancel",
			{ yes_label = "OK", no_label = "Cancel" })
		T.assert(result[2]:find("Cancel") ~= nil, "custom no label")
		T.assert(result[3]:find("OK") ~= nil, "custom yes label")
	end)

	-- confirm_dialog
	T.run("al_formspec.confirm_dialog returns complete formspec", function()
		local result = core.al_formspec.confirm_dialog("Delete this?", "do_delete", "cancel")
		T.assert(type(result) == "string", "should be a string")
		T.assert(result:find("bgcolor") ~= nil, "should include bgcolor")
		T.assert(result:find("do_delete") ~= nil, "should include yes button id")
		T.assert(result:find("Delete this?") ~= nil, "should include confirmation text")
	end)

	T.run("al_formspec.confirm_dialog custom opts", function()
		local result = core.al_formspec.confirm_dialog("Go?", "yes", "no", { yes_label = "Sure" })
		T.assert(result:find("Sure") ~= nil, "should use custom yes label")
		T.assert(result:find("no") ~= nil, "should use custom no id")
	end)

	-- progress_bar
	T.run("al_formspec.progress_bar returns {box, box, label}", function()
		local result = core.al_formspec.progress_bar(0, 0, 5, 0.5, "prog", 5, 10)
		T.assert(type(result) == "table", "should be a table")
		T.assert_eq(#result, 3, "should have 3 elements")
		T.assert(result[1]:find("^box%[") ~= nil, "first should be box (bg)")
		T.assert(result[2]:find("^box%[") ~= nil, "second should be box (fill)")
		T.assert(result[3]:find("^label%[") ~= nil, "third should be label")
	end)

	T.run("al_formspec.progress_bar at 0%, 50%, 100%", function()
		local empty = core.al_formspec.progress_bar(0, 0, 5, 0.5, "p", 0, 10)
		T.assert(empty[3]:find("0%%") ~= nil, "0% label")
		local half = core.al_formspec.progress_bar(0, 0, 5, 0.5, "p", 5, 10)
		T.assert(half[3]:find("50%%") ~= nil, "50% label")
		local full = core.al_formspec.progress_bar(0, 0, 5, 0.5, "p", 10, 10)
		T.assert(full[3]:find("100%%") ~= nil, "100% label")
	end)

	T.run("al_formspec.progress_bar clamps values", function()
		local under = core.al_formspec.progress_bar(0, 0, 5, 0.5, "p", -1, 10)
		T.assert(under[3]:find("0%%") ~= nil, "negative clamps to 0%")
		local over = core.al_formspec.progress_bar(0, 0, 5, 0.5, "p", 20, 10)
		T.assert(over[3]:find("100%%") ~= nil, "over clamps to 100%")
	end)

	T.run("al_formspec.progress_bar accepts custom fill_color", function()
		local result = core.al_formspec.progress_bar(0, 0, 5, 0.5, "p", 5, 10, { fill_color = "#ff0000" })
		T.assert(result[2]:find("#ff0000") ~= nil, "fill box should use custom color")
	end)

	-- tabheader
		T.run("al_formspec.tabheader produces correct format", function()
		local result = core.al_formspec.tabheader(0, 0, "inv_tabs", {"A", "B"}, 2)
		T.assert_eq(result, "tabheader[0,0;inv_tabs;A,B;2]", "tabheader format")
		local default = core.al_formspec.tabheader(0, 0, "tabs", {"X"})
		T.assert(default:match(";1%]") ~= nil, "defaults to selected_idx 1")
	end)

	-- box
	T.run("al_formspec.box produces correct format", function()
		local result = core.al_formspec.box(0, 0, 5, 0.5, "#fff")
		T.assert_eq(result, "box[0,0;5,0.5;#fff]", "box format with color")
		local default = core.al_formspec.box(0, 0, 5, 0.5)
		T.assert(default:find("^box%[") ~= nil, "box without color should still work")
	end)

	-- scroll_container
	T.run("al_formspec.scroll_container produces correct format", function()
		local vert = core.al_formspec.scroll_container(0, 1, 9, 9, "mscroll")
		T.assert_eq(vert, "scroll_container[0,1;9,9;mscroll;vertical]", "vertical scroll container")
		local horiz = core.al_formspec.scroll_container(0, 1, 9, 9, "mscroll", "horizontal")
		T.assert_eq(horiz, "scroll_container[0,1;9,9;mscroll;horizontal]", "horizontal scroll container")
	end)

	T.run("al_formspec.scroll_container_end", function()
		T.assert_eq(core.al_formspec.scroll_container_end(), "scroll_container_end[]", "scroll_container_end")
	end)
end
