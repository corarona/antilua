-- Tests for nlist (named lists) mod

function test_nlist(T)
	T.run("nlist global exists", function()
		T.assert(nlist ~= nil, "nlist global should exist")
		T.assert(type(nlist.get) == "function", "nlist.get should be a function")
	end)

	T.run("nlist basic CRUD", function()
		nlist.set("_al_test_list", {"a", "b", "c"})
		local result = nlist.get("_al_test_list")
		T.assert(result ~= nil, "get should return a table")
		T.assert_eq(#result, 3, "list should have 3 items")
		nlist.clear("_al_test_list")
	end)

	T.run("nlist handles missing lists", function()
		local result = nlist.get("_al_nonexistent_test_list")
		T.assert(type(result) == "table", "accessing nonexistent list did not crash")
		T.assert_eq(#result, 0, "missing list is empty")
	end)

	T.run("nlist.count returns entry count", function()
		nlist.set("_al_count_list", {"a", "b"})
		T.assert_eq(nlist.count("_al_count_list"), 2, "count should be 2")
		nlist.clear("_al_count_list")
		T.assert_eq(nlist.count("_al_count_list"), 0, "cleared list count 0")
	end)

	T.run("nlist.toggle adds then removes", function()
		nlist.clear("_al_toggle_list")
		nlist.toggle("_al_toggle_list", "default:stone")
		T.assert_eq(nlist.count("_al_toggle_list"), 1, "toggle adds absent entry")
		nlist.toggle("_al_toggle_list", "default:stone")
		T.assert_eq(nlist.count("_al_toggle_list"), 0, "toggle removes present entry")
		nlist.clear("_al_toggle_list")
	end)

	T.run("nlist.add trims whitespace", function()
		nlist.clear("_al_trim_list")
		T.assert(nlist.add("_al_trim_list", "  default:stone  "), "add should succeed")
		local result = nlist.get("_al_trim_list")
		T.assert_eq(#result, 1, "one entry stored")
		T.assert_eq(result[1], "default:stone", "whitespace trimmed")
		nlist.clear("_al_trim_list")
	end)

	T.run("nlist.add rejects duplicates", function()
		nlist.clear("_al_dup_list")
		T.assert(nlist.add("_al_dup_list", "default:stone"), "first add succeeds")
		T.assert(not nlist.add("_al_dup_list", "default:stone"), "duplicate add rejected")
		T.assert_eq(nlist.count("_al_dup_list"), 1, "still one entry")
		nlist.clear("_al_dup_list")
	end)

	T.run("nlist.add/remove accept silent flag", function()
		nlist.clear("_al_silent_list")
		T.assert(nlist.add("_al_silent_list", "default:stone", true), "silent add succeeds")
		T.assert_eq(nlist.count("_al_silent_list"), 1, "silent add stored")
		T.assert(nlist.remove("_al_silent_list", "default:stone", true), "silent remove succeeds")
		T.assert_eq(nlist.count("_al_silent_list"), 0, "silent remove cleared")
		nlist.clear("_al_silent_list")
	end)

	T.run("nlist.merge unions without clobbering", function()
		nlist.set("_al_merge_src", {"a", "b"})
		nlist.set("_al_merge_dst", {"b", "c"})
		local added = nlist.merge("_al_merge_dst", "_al_merge_src")
		T.assert_eq(added, 1, "merge adds only the missing entry")
		local dst = nlist.get("_al_merge_dst")
		T.assert_eq(#dst, 3, "dst contains a, b, c")
		T.assert(table.indexof(dst, "a") ~= -1, "a merged in")
		T.assert(table.indexof(dst, "b") ~= -1, "b kept")
		T.assert(table.indexof(dst, "c") ~= -1, "c kept")
		T.assert_eq(nlist.merge("_al_merge_dst", "_al_merge_dst"), 0, "self merge is a no-op")
		nlist.clear("_al_merge_src")
		nlist.clear("_al_merge_dst")
	end)

	T.run("nlist.set_mode validates and persists", function()
		T.assert_eq(nlist.set_mode(3), 3, "toggle mode accepted")
		T.assert_eq(nlist.set_mode(2), 2, "remove mode accepted")
		T.assert_eq(nlist.set_mode(1), 1, "add mode accepted")
		T.assert_eq(nlist.set_mode(99), 1, "invalid mode keeps current")
		T.assert_eq(nlist.set_mode(2), 2, "restore remove mode")
	end)

	T.run("nlist.display resolves known items and falls back to raw name", function()
		T.assert_eq(nlist.display("_al_no_such_item_xyz"), "_al_no_such_item_xyz", "unknown name passthrough")
		local names = core.get_item_names and core.get_item_names() or {}
		for _, name in ipairs(names) do
			if name ~= "" then
				local d = nlist.display(name)
				T.assert(type(d) == "string" and d ~= "", "display returns non-empty string")
				break
			end
		end
	end)

	T.run("core.get_item_names returns a sorted table", function()
		if not core.get_item_names then
			T.assert(true, "get_item_names not available in this build")
			return
		end
		local names = core.get_item_names()
		T.assert(type(names) == "table", "returns a table")
		for i = 2, #names do
			T.assert(names[i - 1] < names[i], "names should be sorted")
		end
	end)

	T.run("chat commands exist", function()
		T.assert(core.registered_chatcommands["nl"] ~= nil, "/nl registered")
		T.assert(core.registered_chatcommands["nls"] ~= nil, "/nls registered")
		T.assert(core.registered_chatcommands["nlshow"] ~= nil, "/nlshow registered")
		T.assert(core.registered_chatcommands["nlt"] ~= nil, "/nlt registered")
	end)

	T.run("internal storage keys are hidden from get_lists", function()
		local lists = nlist.get_lists()
		for _, name in ipairs(lists) do
			T.assert(name:sub(1, 2) ~= "__", "no internal key leaks into list names")
		end
	end)

	T.run("nlist editor formspec builds without error", function()
		local def = core.cheat_defs and core.cheat_defs["nlist_edmode"]
		T.assert(def ~= nil, "nlist_edmode cheat registered")
		if def and def.get_formspec then
			local fs = def.get_formspec("nlist_edmode")
			T.assert(type(fs) == "string" and fs ~= "", "formspec string built")
			T.assert(fs:find("scroll_container") ~= nil, "formspec includes scroll list")
			T.assert(fs:find("scrollbar") ~= nil, "formspec includes scrollbar")
			T.assert(fs:find("list_select") ~= nil, "formspec includes list dropdown")
			T.assert(fs:find("fs_search") ~= nil, "formspec includes filter")
			local has_known = false
			for _, name in ipairs(nlist.get(nlist.selected)) do
				if core.get_item_def(name) then has_known = true break end
			end
			if has_known then
				T.assert(fs:find("item_image") ~= nil, "formspec includes item images")
			end
		end
	end)
end
