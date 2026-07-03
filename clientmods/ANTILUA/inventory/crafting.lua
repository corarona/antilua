local craft_fs = table.concat({
	"formspec_version[4]",
	"size[11.75,10.425]",
	"label[2.25,0.375;Crafting]",
	ws.get_itemslot_bg_v4(2.25, 0.75, 3, 3),
	"list[current_player;craft;2.25,0.75;3,3;]",
	"image[6.125,2;1.5,1;gui_crafting_arrow.png]",
	ws.get_itemslot_bg_v4(8.2, 2, 1, 1, 0.2),
	"list[current_player;craftpreview;8.2,2;1,1;]",
	"label[0.375,4.7;Inventory]",
	ws.get_itemslot_bg_v4(0.375, 5.1, 9, 3),
	"list[current_player;main;0.375,5.1;9,3;9]",
	ws.get_itemslot_bg_v4(0.375, 9.05, 9, 1),
	"list[current_player;main;0.375,9.05;9,1;]",
	"listring[current_player;craft]",
	"listring[current_player;main]",
	"image_button[0.325,1.95;1.1,1.1;craftguide_book.png;__mcl_craftguide;]",
	"tooltip[__mcl_craftguide;Recipe book]",
})

core.register_chatcommand("craft", {
	description = "Open a crafting grid",
	func = function()
		core.show_formspec("inv_craft", craft_fs)
	end,
})

core.register_cheat("OpenCraftGrid", { category = "Inventory", description = "Open the crafting grid", func = function()
	core.show_formspec("inv_craft", craft_fs)
end })
