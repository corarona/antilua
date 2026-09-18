# Antilua
# SPDX-License-Identifier: LGPL-2.1-or-later

"""MCP server exposing a running Antilua client to agents.

Talks to the client through the Lua pipe (``pipe_lua_enable = true``). Run it
with ``uv run`` or ``python -m`` (see util/mcp/README notes in AGENTS.md).

Environment:
  ANTILUA_PIPE_PATH       pipe FIFO path (default /tmp/antilua_lua)
  ANTILUA_TIMEOUT         per-request timeout in seconds (default 10)
  ANTILUA_SCREENSHOT_DIR  directory for screenshots (default: system temp)
"""

import os
import tempfile
import time

from mcp.server.fastmcp import FastMCP, Image

from antilua_client import AntiluaClient, AntiluaError, LuaError, lua_pos, lua_str

mcp = FastMCP(
	"antilua",
	instructions=(
		"You are connected to a running Antilua (Luanti) game client. "
		"Use the player/world/inventory tools to inspect and interact with the "
		"game. start with get_player_pos() to orient yourself and screenshot() "
		"to see the world. Use run_lua(code) for anything not covered by the "
		"curated tools. Coordinates are node-aligned floats {x, y, z}."
	),
)

client = AntiluaClient()


def _shot_dir():
	env = os.environ.get("ANTILUA_SCREENSHOT_DIR")
	if env:
		return env
	return tempfile.gettempdir()


_INVENTORY_SNIPPET = (
	'local inv = core.get_inventory("current_player"); '
	"if not inv then return {error=\"no current_player inventory\"} end; "
	"local out = {}; "
	"for name, list in pairs(inv) do "
	"	local arr = {}; "
	"	for i, item in ipairs(list) do "
	"		if item and not item:is_empty() then "
	"			arr[#arr + 1] = {slot=i, name=item:get_name(), count=item:get_count()}; "
	"		end "
	"	end; "
	"	out[name] = arr; "
	"end; "
	"return out"
)


def _with_inventory(code):
	return code + " ; return {applied=true, inventory=(" + _INVENTORY_SNIPPET + ")}"


# ---------------------------------------------------------------------------
# Raw escape hatch
# ---------------------------------------------------------------------------

@mcp.tool()
def run_lua(code: str) -> dict:
	"""Execute arbitrary Lua code in the client scripting state.

	Return values are JSON-serialized (tables become arrays/objects; circular
	references become null). Use for anything not covered by the curated tools,
	e.g. core.get_node_or_nil, core.find_nodes_near, ws.* helpers. Raises an
	error if the Lua code fails.
	"""
	return client.run_lua(code)


# ---------------------------------------------------------------------------
# Player
# ---------------------------------------------------------------------------

@mcp.tool()
def get_player_pos() -> dict:
	"""Get the local player's position as {x, y, z} (node coordinates)."""
	return client.run_lua("return core.localplayer:get_pos()")


@mcp.tool()
def get_player_look() -> dict:
	"""Get the local player's camera orientation.

	Returns {yaw, pitch} in degrees and {roll} in radians.
	"""
	return client.run_lua(
		"return {yaw=core.localplayer:get_yaw(), "
		"pitch=core.localplayer:get_pitch(), "
		"roll=core.localplayer:get_roll()}"
	)


@mcp.tool()
def teleport(pos: dict) -> dict:
	"""Teleport the local player to {x, y, z}. Returns the new position."""
	return client.run_lua(
		"core.localplayer:set_pos(%s); return core.localplayer:get_pos()"
		% lua_pos(pos)
	)


@mcp.tool()
def set_look(yaw: float, pitch: float) -> dict:
	"""Set the camera yaw and pitch in degrees. Returns the resulting angles."""
	return client.run_lua(
		"core.localplayer:set_yaw(%r); core.localplayer:set_pitch(%r); "
		"return {yaw=core.localplayer:get_yaw(), "
		"pitch=core.localplayer:get_pitch()}" % (yaw, pitch)
	)


# ---------------------------------------------------------------------------
# World
# ---------------------------------------------------------------------------

@mcp.tool()
def get_node(pos: dict) -> dict:
	"""Get the node at {x, y, z} as {name, param1, param2} or null."""
	return client.run_lua("return core.get_node_or_nil(%s)" % lua_pos(pos))


@mcp.tool()
def dig_node(pos: dict) -> dict:
	"""Dig the node at {x, y, z}. Returns {digged: true/false}."""
	return client.run_lua(
		"return {digged=(core.dig_node(%s) == true)}" % lua_pos(pos)
	)


@mcp.tool()
def place_node(pos: dict) -> dict:
	"""Place the wielded item as a node at {x, y, z}."""
	return client.run_lua("return {placed=core.place_node(%s) == true}" % lua_pos(pos))


@mcp.tool()
def find_nodes_near(pos: dict, radius: int, node_names: list[str]) -> dict:
	"""Find nodes with the given names within a radius of {x, y, z}.

	Returns a list of {x, y, z} positions.
	"""
	names = ", ".join(lua_str(name) for name in node_names)
	return client.run_lua(
		"return core.find_nodes_near(%s, %d, {%s})"
		% (lua_pos(pos), radius, names)
	)


@mcp.tool()
def get_pointed_thing() -> dict:
	"""Raycast result of what the player is currently looking at.

	Returns {type: "node"|"object"|"nothing", under, above, ...}. Object refs
	are userdata and come back as their tostring form.
	"""
	return client.run_lua("return core.get_pointed_thing()")


# ---------------------------------------------------------------------------
# Inventory
# ---------------------------------------------------------------------------

@mcp.tool()
def get_inventory() -> dict:
	"""Get the player's inventory.

	Returns a map of list name -> array of non-empty stacks
	{slot, name, count} (e.g. main, craft, craftpreview, craftresult).
	"""
	return client.run_lua(_INVENTORY_SNIPPET)


@mcp.tool()
def move_item(
	from_list: str,
	from_slot: int,
	to_list: str,
	to_slot: int,
	count: int = 0,
) -> dict:
	"""Move items between inventory lists. count 0 (default) moves the whole
	stack. Lists are e.g. "main" (36 slots), "craft" (9), "craftresult" (1).
	Returns the updated inventory."""
	code = (
		'local a = InventoryAction("move"); '
		"a:from(\"current_player\", %s, %d); "
		"a:to(\"current_player\", %s, %d); "
		"a:set_count(%d); "
		"a:apply()"
	) % (lua_str(from_list), from_slot, lua_str(to_list), to_slot, count)
	return client.run_lua(_with_inventory(code))


@mcp.tool()
def craft(count: int = 1) -> dict:
	"""Craft the currently shown recipe `count` times. Returns the updated
	inventory (use take_craft_result to collect the output)."""
	code = (
		'local a = InventoryAction("craft"); '
		'a:craft("current_player"); '
		"a:set_count(%d); "
		"a:apply()"
	) % count
	return client.run_lua(_with_inventory(code))


@mcp.tool()
def take_craft_result(target_slot: int) -> dict:
	"""Move the craft output into a main inventory slot. Returns the updated
	inventory."""
	code = (
		'local a = InventoryAction("move"); '
		'a:from("current_player", "craftresult", 1); '
		'a:to("current_player", "main", %d); '
		"a:set_count(0); "
		"a:apply()"
	) % target_slot
	return client.run_lua(_with_inventory(code))


# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------

@mcp.tool()
def run_server_chatcommand(command: str, args: str = "") -> dict:
	"""Run a server chat command (/command). Returns {ok, returned, message}
	or {ok: false, error} if the command fails."""
	try:
		result = client.run_lua(
			"return core.run_server_chatcommand(%s, %s)"
			% (lua_str(command), lua_str(args))
		)
		return {"ok": True, "returned": result}
	except LuaError as exc:
		return {"ok": False, "error": str(exc)}


@mcp.tool()
def send_chat(message: str) -> dict:
	"""Send a chat message as the local player."""
	client.run_lua("return core.send_chat_message(%s)" % lua_str(message))
	return {"sent": True}


@mcp.tool()
def get_server_info() -> dict:
	"""Get server connection info {address, ip, port, protocol_version}."""
	return client.run_lua("return core.get_server_info()")


@mcp.tool()
def get_player_names() -> dict:
	"""List of online player names."""
	return client.run_lua("return core.get_player_names()")


@mcp.tool()
def get_privilege_list() -> dict:
	"""Map of privilege name -> granted bool for the local player."""
	return client.run_lua("return core.get_privilege_list()")


# ---------------------------------------------------------------------------
# Settings / cheats
# ---------------------------------------------------------------------------

@mcp.tool()
def set_setting(name: str, value: str) -> dict:
	"""Set a client setting (e.g. cheats like jetpack, fullbright, fastdig,
	autojump to "true"/"false"). Returns the stored value."""
	return client.run_lua(
		"core.settings:set(%s, %s); return core.settings:get(%s)"
		% (lua_str(name), lua_str(value), lua_str(name))
	)


@mcp.tool()
def toggle_cheat(name: str, enabled: bool) -> dict:
	"""Enable or disable a cheat setting (jetpack, fullbright, fastdig,
	autojump, ...)."""
	return set_setting(name, "true" if enabled else "false")


# ---------------------------------------------------------------------------
# Screenshot
# ---------------------------------------------------------------------------

@mcp.tool()
def screenshot() -> tuple:
	"""Capture a scene-only screenshot of the current view (no HUD/overlays).

	Requires a client that is rendering (not detached/hidden). Returns the
	image plus the saved file path."""
	path = os.path.join(_shot_dir(), "antilua_shot_%d.png" % time.time_ns())
	client.screenshot(path)
	with open(path, "rb") as fh:
		data = fh.read()
	return "Screenshot saved to %s" % path, Image(data=data, format="png")


def main():
	"""Entry point for the console script / `python -m`."""
	mcp.run()


if __name__ == "__main__":
	main()