unused_args = false
allow_defined_top = true

ignore = {
	"131", -- Unused global variable
	"421", -- Shadowing a local variable
	"431", -- Shadowing an upvalue
	"432", -- Shadowing an upvalue argument
	"631", -- Line is too long
}

read_globals = {
	"ItemStack",
	"INIT",
	"PLATFORM",
	"DIR_DELIM",
	"dump", "dump2",
	"fgettext", "fgettext_ne",
	"vector",
	"vector2",
	"VoxelArea",
	"VoxelManip",
	"profiler",
	"Settings",
	"ValueNoise", "ValueNoiseMap",
	"tracy",

	string = {fields = {"split", "trim"}},
	table  = {fields = {"copy", "copy_with_metatables", "getn", "indexof", "keyof", "insert_all", "shuffle"}},
	math   = {fields = {"hypot", "round", "isfinite", "sign"}},
}

globals = {
	"core",
	"gamedata",
	os = { fields = { "tempfolder" } },
	"_",
}

stds.menu_common = {
	globals = {
		"mt_color_grey", "mt_color_blue", "mt_color_lightblue", "mt_color_green",
		"mt_color_dark_green", "mt_color_orange", "mt_color_red",
	},
}

files["builtin/client/init.lua"] = {
	globals = {
		debug = {fields={"getinfo"}},
	}
}

files["builtin/sscsm_client/init.lua"] = {
	globals = {
		debug = {fields={"getinfo"}},
	}
}

files["builtin/common/math.lua"] = {
	globals = {
		"math",
	},
}

files["builtin/common/misc_helpers.lua"] = {
	globals = {
		"dump", "dump2", "table", "math", "string",
		"fgettext", "fgettext_ne", "basic_dump", "game", -- ???
		"file_exists", "get_last_folder", "cleanup_path", -- ???
	},
}

files["builtin/common/vector.lua"] = {
	globals = { "vector", "math" },
}

files["builtin/common/vector2.lua"] = {
	globals = { "vector2", "math" },
}

files["builtin/game/voxelarea.lua"] = {
	globals = { "VoxelArea" },
}

files["builtin/game/init.lua"] = {
	globals = { "profiler" },
}

files["builtin/common/filterlist.lua"] = {
	globals = {
		"filterlist",
		"compare_worlds", "sort_worlds_alphabetic", "sort_mod_list", -- ???
	},
}

files["builtin/mainmenu"] = {
	std = "+menu_common",
	globals = {
		"gamedata",
	},
}

files["builtin/common/settings"] = {
	std = "+menu_common",
}

files["builtin/client/cheats.lua"] = {
	read_globals = { "ws" },
}

files["builtin/client/misc.lua"] = {
	read_globals = { "nlist" },
}

files["builtin/common/tests"] = {
	read_globals = {
		"describe",
		"it",
		"assert",
	},
}

stds.al_client = {
    read_globals = {
        -- Engine globals
        "core", "minetest", "dump", "vector", "ItemStack",
        "VoxelArea", "VoxelManip", "Settings",
        -- Antilua client-side globals
        "core.localplayer", "core.camera",
        "core.show_cheat_settings_form",
        "core.create_client_entity",
        "core.register_on_receiving_raw_packet",
        "core.register_on_sending_raw_packet",
        "core.send_raw_packet",
        "core.override_item",
        "core.read_schematic", "core.serialize_schematic",
        -- wasplib globals
        "ws",
        -- Other mod globals
        "nlist", "sbots", "poi", "tps_client",
        "autocraft", "invviewer", "al_formspec",
        "schembuilder", "blockexchange", "dte",
    },
}

-- schembuilder shared globals
files["clientmods/ANTILUA/schembuilder/*.lua"] = {
        globals = { "hud_id" },
}

-- Antilua client mods
files["clientmods/ANTILUA/wasplib/init.lua"] = { std = "+al_client" }
files["clientmods/ANTILUA/wasplib/*.lua"] = { std = "+al_client" }
files["clientmods/ANTILUA/**/init.lua"] = { std = "+al_client" }
files["clientmods/ANTILUA/**/*.lua"] = { std = "+al_client" }
files["clientmods/al_test/init.lua"] = { std = "+al_client" }
files["clientmods/al_test/*.lua"] = { std = "+al_client" }
