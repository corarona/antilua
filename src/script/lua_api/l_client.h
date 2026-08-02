/*
Minetest
Copyright (C) 2013 celeron55, Perttu Ahola <celeron55@gmail.com>
Copyright (C) 2017 nerzhul, Loic Blot <loic.blot@unix-experience.fr>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

#pragma once

#include "lua_api/l_base.h"
#include "itemdef.h"
#include "tool.h"

class ModApiClient : public ModApiBase
{
private:
	// get_current_modname()
	static int l_get_current_modname(lua_State *L);

	// get_modpath(modname)
	static int l_get_modpath(lua_State *L);

	// print(text)
	static int l_print(lua_State *L);

	// display_chat_message(message)
	static int l_display_chat_message(lua_State *L);

	// show_toast(text, type)
	static int l_show_toast(lua_State *L);

	// send_chat_message(message)
	static int l_send_chat_message(lua_State *L);

	// clear_out_chat_queue()
	static int l_clear_out_chat_queue(lua_State *L);

	// get_player_names()
	static int l_get_player_names(lua_State *L);

	// show_formspec(name, formspec)
	static int l_show_formspec(lua_State *L);

	// send_respawn()
	static int l_send_respawn(lua_State *L);

	// disconnect()
	static int l_disconnect(lua_State *L);

	// gettext(text)
	static int l_gettext(lua_State *L);

	// get_last_run_mod(n)
	static int l_get_last_run_mod(lua_State *L);

	// set_last_run_mod(modname)
	static int l_set_last_run_mod(lua_State *L);

	// get_node(pos)
	static int l_get_node_or_nil(lua_State *L);

	// find_nodes_near(pos, radius, nodenames, search_center)
	static int l_find_nodes_near(lua_State *L);

	// find_nodes_near_under_air_except(pos, radius, except_nodenames, search_center)
	static int l_find_nodes_near_under_air_except(lua_State *L);

	// get_language()
	static int l_get_language(lua_State *L);

	// get_wielded_item()
	static int l_get_wielded_item(lua_State *L);

	// get_meta(pos)
	static int l_get_meta(lua_State *L);

	// sound_play(spec, parameters)
	static int l_sound_play(lua_State *L);

	// sound_stop(handle)
	static int l_sound_stop(lua_State *L);

	// sound_fade(handle, step, gain)
	static int l_sound_fade(lua_State *L);

	// get_server_info()
	static int l_get_server_info(lua_State *L);

	// get_item_def(itemstring)
	static int l_get_item_def(lua_State *L);

	// get_node_def(nodename)
	static int l_get_node_def(lua_State *L);

	// get_privilege_list()
	static int l_get_privilege_list(lua_State *L);

	// get_builtin_path()
	static int l_get_builtin_path(lua_State *L);

	// get_csm_restrictions()
	static int l_get_csm_restrictions(lua_State *L);

	// send_damage(damage)
	static int l_send_damage(lua_State *L);

	// place_node(pos)
	static int l_place_node(lua_State *L);

	// dig_node(pos)
	static int l_dig_node(lua_State *L);

	// get_inventory(location)
	static int l_get_inventory(lua_State *L);

	// set_keypress(key_setting, pressed)
	static int l_set_keypress(lua_State *L);

	// drop_selected_item()
	static int l_drop_selected_item(lua_State *L);

	// get_objects_inside_radius(pos, radius)
	static int l_get_objects_inside_radius(lua_State *L);

	// make_screenshot()
	static int l_make_screenshot(lua_State *L);

	// interact(action, pointed_thing)
	static int l_interact(lua_State *L);

	// send_inventory_fields(formname, fields)
	static int l_send_inventory_fields(lua_State *L);

	// send_nodemeta_fields(position, formname, fields)
	static int l_send_nodemeta_fields(lua_State *L);

	// send_raw_packet(command, raw_payload)
	static int l_send_raw_packet(lua_State *L);

	// send_raw_mtp_packet(payload)
	static int l_send_raw_mtp_packet(lua_State *L);

	// get_peer_id()
	static int l_get_peer_id(lua_State *L);

	// read_schematic(schematic, options)
	static int l_read_schematic(lua_State *L);

	// serialize_schematic(schematic, format, options)
	static int l_serialize_schematic(lua_State *L);

	// read_file(path)
	static int l_read_file(lua_State *L);

	// decode_image(data) — decode PNG bytes to {width, height, data}
	static int l_decode_image(lua_State *L);

	// write_file(path, data) — write data to a file on disk
	static int l_write_file(lua_State *L);

	// get_dir_list(path, is_dir)
	static int l_get_dir_list(lua_State *L);

	// get_modpath_real(modname) — resolves virtual modpath to real filesystem path
	static int l_get_modpath_real(lua_State *L);

	// create_client_entity(pos, properties)
	static int l_create_client_entity(lua_State *L);

	// detach()
	static int l_detach(lua_State *L);

	// reattach()
	static int l_reattach(lua_State *L);

	// cheat_menu_set_visible(visible)
	static int l_cheat_menu_set_visible(lua_State *L);

	// get_quick_menu_entries() / activate_quick_menu_entry(index)
	static int l_get_quick_menu_entries(lua_State *L);
	static int l_activate_quick_menu_entry(lua_State *L);

	// open_inventory()
	static int l_open_inventory(lua_State *L);

	// get_data_path()
	static int l_get_data_path(lua_State *L);

	// get_serverdata_path()
	static int l_get_serverdata_path(lua_State *L);

	// append_file(path, data)
	static int l_append_file(lua_State *L);

	// --- Extended API from DevClient ---

	// start_dig(pos) — start digging without completing
	static int l_start_dig(lua_State *L);

	// get_item_damage_against(slot_index, object_id) — calculate wielded item damage vs entity
	static int l_get_item_damage_against(lua_State *L);
	static int l_get_inv_item_damage(lua_State *L) { return l_get_item_damage_against(L); }

	// get_item_dig_time(slot_index, nodepos) — calculate dig time for an item vs a node
	static int l_get_item_dig_time(lua_State *L);
	static int l_get_inv_item_break(lua_State *L) { return l_get_item_dig_time(L); }

	// set_fast_speed(speed)
	static int l_set_fast_speed(lua_State *L);

	// set_node_esp_list({names}) — set node names for Node ESP
	static int l_set_node_esp_list(lua_State *L);

	// get_all_objects() — return all active objects (no radius filter)
	static int l_get_all_objects(lua_State *L);

	// get_active_object_by_id(id) — get object by numeric ID
	static int l_get_active_object_by_id(lua_State *L);
	static int l_get_active_object(lua_State *L) { return l_get_active_object_by_id(L); }

	// all_loaded_nodes() — iterator over all loaded nodes
	static int l_all_loaded_nodes(lua_State *L);

	// nodes_at_block_pos(pos) — iterator over nodes in a block
	static int l_nodes_at_block_pos(lua_State *L);

	// can_attack(object_id) — check if player can attack entity
	static int l_can_attack(lua_State *L);

	// get_server_url() — return "address:port" or nil
	static int l_get_server_url(lua_State *L);

	// get_node_name(pos) — convenience: get node name string at pos
	static int l_get_node_name(lua_State *L);

	// add_task_node(pos, color) — persistent colored wireframe box marker
	static int l_add_task_node(lua_State *L);

	// clear_task_node(pos)
	static int l_clear_task_node(lua_State *L);

	// add_task_tracer(start_pos, end_pos, color) — persistent colored line
	static int l_add_task_tracer(lua_State *L);

	// clear_task_tracer(start_pos, end_pos)
	static int l_clear_task_tracer(lua_State *L);

	// update_infotexts() — refresh all infotext displays
	static int l_update_infotexts(lua_State *L);

	// get_description() — get description string
	static int l_get_description(lua_State *L);

	// find_path(start_pos, end_pos) — A* pathfinding, returns {pos,...}
	static int l_find_path(lua_State *L);

	// load_media(filename) — load custom media file
	static int l_load_media(lua_State *L);

	// reload_mod(modname) — re-scan mod files from disk and re-execute init.lua
	static int l_reload_mod(lua_State *L);

public:
	static void Initialize(lua_State *L, int top);
	static void InitializeSSCSM(lua_State *L, int top);
};
