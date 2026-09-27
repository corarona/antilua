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


def _truthy(value):
	"""What wait_until treats as success."""
	return value is not None and value is not False and value != "" \
		and value != 0 and value != {} and value != []


def _last_chat_id():
	try:
		lines = client.run_lua("return mcp_chat and mcp_chat.recent(1) or {}")
		return (lines[-1]["id"] if lines else 0) if isinstance(lines, list) else 0
	except AntiluaError:
		return 0


def _new_chat_lines(since_id):
	try:
		return client.run_lua(
			"return mcp_chat and mcp_chat.since(%d) or {}" % since_id)
	except AntiluaError:
		return []


_INVENTORY_STATEMENTS = (
	'local inv = core.get_inventory("current_player"); '
	"local out = {}; "
	"if not inv then "
	'	out = {error="no current_player inventory"}; '
	"else "
	"	for name, list in pairs(inv) do "
	"		local arr = {}; "
	"		for i, item in ipairs(list) do "
	"			if item and not item:is_empty() then "
	"				arr[#arr + 1] = {slot=i, name=item:get_name(), count=item:get_count()}; "
	"			end "
	"		end; "
	"		out[name] = arr; "
	"	end; "
	"end"
)

_INVENTORY_SNIPPET = _INVENTORY_STATEMENTS + " ; return out"


def _with_inventory(action_statements):
	"""Wrap inventory-mutating action statements with a pcall and a fresh
	inventory snapshot. Produces valid Lua (the InventoryAction methods
	return nil, so they cannot be chained)."""
	return (
		"local ok, err = pcall(function() " + action_statements + " end); "
		+ _INVENTORY_STATEMENTS
		+ " ; return {applied=ok, error=err, inventory=out}"
	)


# ---------------------------------------------------------------------------
# Raw escape hatch
# ---------------------------------------------------------------------------

@mcp.tool()
def run_lua(code: str) -> dict:
	"""Execute arbitrary Lua code in the client scripting state.

	Returns {ok: true, value} where value is the JSON-serialized result
	(null when the chunk returns nothing), or {ok: false, error} if the Lua
	code raises. Tables become arrays/objects; circular references become
	null. Use for anything not covered by the curated tools, e.g.
	core.get_node_or_nil, core.find_nodes_near, ws.* helpers.
	"""
	try:
		return {"ok": True, "value": client.run_lua(code)}
	except LuaError as exc:
		return {"ok": False, "error": str(exc)}


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
	"""Get the node at {x, y, z}. Returns {node: {name, param1, param2}} or
	{node: null} if the position is unknown/unloaded."""
	return {"node": client.run_lua("return core.get_node_or_nil(%s)" % lua_pos(pos))}


@mcp.tool()
def dig_node(pos: dict) -> dict:
	"""Dig the node at {x, y, z}. Returns {digged: true/false}."""
	return client.run_lua(
		"local ok, err = pcall(core.dig_node, %s); "
		"return {digged=ok, error=err}" % lua_pos(pos)
	)


@mcp.tool()
def place_node(pos: dict) -> dict:
	"""Place the wielded item as a node at {x, y, z}. Returns {placed, node}
	with node being the resulting node (or null)."""
	return client.run_lua(
		"local p = %s; "
		"local ok, err = pcall(core.place_node, p); "
		"return {placed=ok, node=ok and core.get_node_or_nil(p) or nil, error=err}"
		% lua_pos(pos)
	)


@mcp.tool()
def find_nodes_near(pos: dict, radius: int, node_names: list[str]) -> dict:
	"""Find nodes with the given names within a radius of {x, y, z}.

	Returns {count, positions} where positions is a list of {x, y, z}.
	"""
	names = ", ".join(lua_str(name) for name in node_names)
	positions = client.run_lua(
		"return core.find_nodes_near(%s, %d, {%s})"
		% (lua_pos(pos), radius, names)
	)
	return {"count": len(positions), "positions": positions}


@mcp.tool()
def get_pointed_thing() -> dict:
	"""Raycast result of what the player is currently looking at.

	Returns {type: "node"|"object"|"nothing", under, above, ...}. Object refs
	are userdata and come back as their tostring form.
	"""
	result = client.run_lua("return core.get_pointed_thing()")
	if result is None:
		return {"type": "nothing"}
	return result


@mcp.tool()
def find_nodes_near_under_air(
	pos: dict, radius: int, except_names: list[str] = [],
) -> dict:
	"""Find nodes near `pos` that stand under air, excluding `except_names`.
	Useful for finding placement surfaces. Returns {count, positions}."""
	names = ", ".join(lua_str(name) for name in except_names)
	positions = client.run_lua(
		"return core.find_nodes_near_under_air_except(%s, %d, {%s})"
		% (lua_pos(pos), radius, names))
	return {"count": len(positions), "positions": positions}


@mcp.tool()
def get_node_meta(pos: dict, keys: list[str] | None = None) -> dict:
	"""Read node metadata at {x, y, z}.

	Returns {meta: {key: value}} for all keys, or only `keys` when given.
	meta is empty when the node has no (synced) metadata.
	"""
	if keys:
		key_list = ", ".join(lua_str(k) for k in keys)
		code = (
			"local ok, out = pcall(function() "
			"local meta = core.get_meta(%s); local t = {}; "
			"for _, k in ipairs({%s}) do t[k] = tostring(meta:get_string(k)) end; "
			"return t end); "
			"return ok and out or {}" % (lua_pos(pos), key_list))
	else:
		code = (
			"local ok, out = pcall(function() "
			"local meta = core.get_meta(%s); local t = {}; "
			"for k, v in pairs(meta:to_table().fields) do "
			"t[k] = tostring(v) end; return t end); "
			"return ok and out or {}" % lua_pos(pos))
	result = client.run_lua(code)
	return {"meta": result if isinstance(result, dict) else {}}


@mcp.tool()
def set_node_meta(pos: dict, fields: dict) -> dict:
	"""Submit fields to a node's formspec handler (like editing a formspec
	field and pressing submit).

	NOTE: the server only applies these if it showed this node's formspec to
	the player first (e.g. via right-click/interact('use')); otherwise it
	silently rejects them. Verify with get_node_meta / the node's state.
	Returns {sent: true} or {ok: false, error} on client-side failure."""
	pairs = ", ".join("%s=%s" % (k, lua_str(v)) for k, v in fields.items())
	code = (
		"local ok, err = pcall(core.send_nodemeta_fields, %s, '', {%s}); "
		"if not ok then return {ok=false, error=err} end; "
		"return {sent=true}" % (lua_pos(pos), pairs))
	return client.run_lua(code)


@mcp.tool()
def interact(action: str, pointed: dict | None = None) -> dict:
	"""Send a real interact action: "place", "use" (right-click), "activate"
	(right-click air) or "dig".

	`pointed` is {type: "node", under: {x,y,z}, above: {x,y,z}} (use
	get_pointed_thing for values), {type: "object", id: <int>} or omitted /
	{type:"nothing"} for "activate". Unlike place_node/dig_node this follows
	the node's on_rightclick (opens formspecs). Returns {sent: true} or
	{ok: false, error}."""
	actions = {
		"place": "place", "use": "use", "activate": "activate",
		"dig": "dig",
	}
	if action not in actions:
		return {"ok": False, "error": "action must be one of: %s"
			% ", ".join(sorted(actions))}
	pt = dict(pointed or {})
	pt.setdefault("type", "nothing")
	if pt["type"] == "object" and isinstance(pt.get("id"), int):
		code = (
			"local obj = core.get_active_object_by_id(%d); "
			"if not obj then return {ok=false, error='no object'} end; "
			"local ok, res = pcall(core.interact, %s, "
			'{type="object", ref=obj}); '
			"if not ok then return {ok=false, error=res} end; "
			"return {ok=true}" % (pt["id"], lua_str(action)))
	elif pt["type"] == "node":
		under, above = pt.get("under"), pt.get("above")
		if not under or not above:
			return {"ok": False, "error": "node pointed needs under+above"}
		code = (
			"local ok, res = pcall(core.interact, %s, "
			'{type="node", under=%s, above=%s}); '
			"if not ok then return {ok=false, error=res} end; "
			"return {ok=true}"
			% (lua_str(action), lua_pos(under), lua_pos(above)))
	else:
		code = (
			"local ok, res = pcall(core.interact, %s, {type='nothing'}); "
			"if not ok then return {ok=false, error=res} end; "
			"return {ok=true}" % lua_str(action))
	return client.run_lua(code)


@mcp.tool()
def get_objects_near(pos: dict, radius: float) -> dict:
	"""Active objects within `radius` of {x, y, z}:
	{objects: [{id, pos, name, is_player}, ...]} (name is empty for unknown
	types)."""
	code = (
		"local out = {}; "
		"for _, obj in ipairs(core.get_objects_inside_radius(%s, %r)) do "
		"local ok, opos = pcall(function() return obj:get_pos() end); "
		"local ok2, oname = pcall(function() return obj:get_name() end); "
		"local ok3, ispl = pcall(function() return obj:is_player() end); "
		"local ok4, oid = pcall(function() return obj:get_id() end); "
		"out[#out + 1] = {id=(ok4 and oid or nil), pos=opos, "
		"name=(ok2 and oname or ''), is_player=(ok3 and ispl) or false}; "
		"end; return out" % (lua_pos(pos), radius))
	return {"objects": client.run_lua(code)}


# ---------------------------------------------------------------------------
# Inventory
# ---------------------------------------------------------------------------

@mcp.tool()
def get_inventory(location: str = "current_player") -> dict:
	"""Get an inventory. location is "current_player" (default),
	"player:<name>", "nodemeta:x,y,z" or "detached:<name>".

	Returns a map of list name -> array of non-empty stacks
	{slot, name, count} (e.g. main, craft, craftpreview, craftresult).
	"""
	statements = _INVENTORY_STATEMENTS.replace(
		'core.get_inventory("current_player")',
		"core.get_inventory(%s)" % lua_str(location))
	return client.run_lua(statements + " ; return out")


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


@mcp.tool()
def move_items(moves: list) -> dict:
	"""Move several stacks in one round trip. `moves` is a list of
	{from_list, from_slot, to_list, to_slot, count?} (count 0 = whole stack).

	Returns {results: [{applied, error}, ...] in order, inventory}.
	"""
	statements = []
	for idx, move in enumerate(moves):
		statements.append(
			"local ok%d, err%d = pcall(function() "
			'local a = InventoryAction("move"); '
			'a:from("current_player", %s, %d); '
			'a:to("current_player", %s, %d); '
			"a:set_count(%d); "
			"a:apply() end)"
			% (idx, idx,
				lua_str(move["from_list"]), move["from_slot"],
				lua_str(move["to_list"]), move["to_slot"],
				move.get("count", 0)))
	# Lua 5.1 has no goto-free way to build this list dynamically; assemble
	# the results table with string keys instead.
	parts = ", ".join(
		"[%d]={applied=ok%d, error=err%d}" % (i + 1, i, i)
		for i in range(len(moves)))
	code = " ; ".join(statements) + " ; " + _INVENTORY_STATEMENTS \
		+ " ; return {results={%s}, inventory=out}" % parts
	return client.run_lua(code)


@mcp.tool()
def wield_item(name: str) -> dict:
	"""Wield the first inventory stack whose name contains `name`.
	Returns {ok, slot, name} or {ok: false, error}."""
	return client.run_lua(
		"local lp = core.localplayer; "
		"if not lp then return {ok=false, error='no localplayer'} end; "
		"local inv = core.get_inventory('current_player'); "
		"if not inv or not inv.main then "
			"return {ok=false, error='no main list'} end; "
		"for i, item in ipairs(inv.main) do "
			"if item and not item:is_empty() and "
					"string.find(item:get_name(), %s, 1, true) then "
				"lp:set_wield_index(i); "
				"return {ok=true, slot=i, name=item:get_name()} "
			"end "
		"end; "
		"return {ok=false, error='not found'}" % lua_str(name))


@mcp.tool()
def give_and_wield(name: str, count: int = 1) -> dict:
	"""Give an item via /giveme (if not already held) and wield it.

	Polls the client inventory until the item shows up, moves the stack into
	the first free hotbar slot (else slot 1) and wields it. Returns
	{ok, slot, name, inventory} or {ok: false, error}.
	"""
	try:
		client.run_lua(
			"core.run_server_chatcommand('giveme', %s)" % lua_str(
				"%s %d" % (name, count)))
		deadline = time.monotonic() + 15.0
		slot = None
		while time.monotonic() < deadline:
			inv = client.run_lua(_INVENTORY_SNIPPET)
			stacks = inv.get("main", []) if isinstance(inv, dict) else []
			matching = [s for s in stacks if s.get("name", "") == name]
			if matching:
				# Prefer a stack with enough items; fall back to any match.
				for cand in matching:
					if cand.get("count", 0) >= count:
						slot = cand["slot"]
						break
				if slot is None:
					slot = matching[0]["slot"]
				break
			time.sleep(0.5)
		if slot is None:
			return {"ok": False, "error": "item never appeared in inventory"}
		result = client.run_lua(
			"local lp = core.localplayer; "
			"local inv = core.get_inventory('current_player'); "
			"if not inv or not inv.main then "
				"return {ok=false, error='no main list'} end; "
			"local target; "
			"for i = 1, 8 do "
				"local it = inv.main[i]; "
				"if not it or it:is_empty() then target = i break end; "
			"end; "
			"target = target or 1; "
			"local a = InventoryAction('move'); "
			"a:from('current_player', 'main', %d); "
			"a:to('current_player', 'main', target); "
			"a:set_count(0); "
			"a:apply(); "
			"lp:set_wield_index(target); "
			"return {ok=true, slot=target}" % slot)
		inv = client.run_lua(_INVENTORY_SNIPPET)
		result["inventory"] = inv
		stacks = inv.get("main", [])
		wielded = next((s for s in stacks if s.get("slot") == result["slot"]),
			None)
		result["name"] = wielded.get("name") if wielded else None
		return result
	except (AntiluaError, LuaError) as exc:
		return {"ok": False, "error": str(exc)}


# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------

@mcp.tool()
def run_server_chatcommand(command: str, args: str = "", wait: float = 2.0) -> dict:
	"""Send a server chat command (/command) as a chat message and collect the
	server's chat response.

	Returns {ok, returned, chat} where chat holds the new chat lines (the
	command's response) and returned is always null (the client API only
	queues the message). ok is true when the message was queued.
	"""
	mark = _last_chat_id()
	try:
		client.run_lua(
			"core.run_server_chatcommand(%s, %s)"
			% (lua_str(command), lua_str(args))
		)
		time.sleep(max(0.0, wait))
		return {"ok": True, "returned": None, "chat": _new_chat_lines(mark)}
	except LuaError as exc:
		return {"ok": False, "error": str(exc), "chat": []}


@mcp.tool()
def get_chat_log(count: int = 20) -> dict:
	"""Last `count` received chat lines (from the mcp_chat clientmod):
	[{id, ts, text}, ...]."""
	return {"lines": client.run_lua(
		"return mcp_chat and mcp_chat.recent(%d) or {}" % count)}


@mcp.tool()
def wait_until(code: str, timeout: float = 10.0, interval: float = 0.5) -> dict:
	"""Poll Lua `code` until it returns a truthy value.

	Truthy means not nil/false/0/""/empty table. Returns {ok: true, value}
	when satisfied, {ok: false, error: "timeout", value} with the last value
	on timeout, or {ok: false, error} immediately when the Lua errors.
	"""
	deadline = time.monotonic() + max(0.0, timeout)
	interval = max(0.05, interval)
	last = None
	while True:
		try:
			result = client.run_lua(
				"return %s" % code if not code.lstrip().startswith(
					("return", "local")) else code)
			last = result
			if _truthy(result):
				return {"ok": True, "value": result}
		except LuaError as exc:
			return {"ok": False, "error": str(exc)}
		if time.monotonic() >= deadline:
			return {"ok": False, "error": "timeout", "value": last}
		time.sleep(interval)


@mcp.tool()
def get_client_status() -> dict:
	"""Diagnostic snapshot: {joined, player_name, server, chat_buffer}.
	Useful to see why other tools fail (e.g. not joined to a world yet)."""
	try:
		state = client.run_lua(
			"local lp = core.localplayer; "
			"return {joined=lp ~= nil, "
			"player_name=lp and lp:get_name() or nil, "
			"chat_buffer=mcp_chat ~= nil}")
		return {"connected": True, **state}
	except (AntiluaError, LuaError) as exc:
		return {"connected": False, "error": str(exc)}


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
	"""List of online player names. Returns {players: [...]}."""
	return {"players": client.run_lua("return core.get_player_names()")}


@mcp.tool()
def get_privilege_list() -> dict:
	"""Map of privilege name -> granted bool for the local player."""
	return client.run_lua("return core.get_privilege_list()")


@mcp.tool()
def set_time(value: str) -> dict:
	"""Set the server time of day via the /time command (e.g. "6", "noon",
	"midnight", "5000"). Returns the chat response lines."""
	return run_server_chatcommand("time", value, wait=1.5)


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
def screenshot(pos: dict | None = None) -> tuple:
	"""Capture a scene-only screenshot of the current view (no HUD/overlays).

	With `pos`, first aims the camera toward that world position (yaw/pitch
	only — the player does not move) and restores the previous look
	afterwards. Requires a client that is rendering (not detached/hidden).
	Returns the image plus the saved file path."""
	path = os.path.join(_shot_dir(), "antilua_shot_%d.png" % time.time_ns())
	if pos is not None:
		client.run_lua(
			"__mcp_prev_look = {yaw=core.localplayer:get_yaw(), "
			"pitch=core.localplayer:get_pitch()}; "
			"local eye = core.camera:get_pos(); "
			"local d = vector.direction(eye, vector.new(%r, %r, %r)); "
			"core.localplayer:set_yaw(math.atan2(-d.x, d.z)); "
			"core.localplayer:set_pitch("
			"-math.asin(math.max(-1, math.min(1, d.y))) * 180 / math.pi)"
			% (pos["x"], pos["y"], pos["z"]))
	try:
		client.screenshot(path)
	finally:
		if pos is not None:
			try:
				client.run_lua(
					"core.localplayer:set_yaw(__mcp_prev_look.yaw); "
					"core.localplayer:set_pitch(-__mcp_prev_look.pitch); "
					"__mcp_prev_look = nil")
			except AntiluaError:
				pass
	with open(path, "rb") as fh:
		data = fh.read()
	return "Screenshot saved to %s" % path, Image(data=data, format="png")


# ---------------------------------------------------------------------------
# Agent (clientmods/ANTILUA/agent): events, context, movement, verified actions
# ---------------------------------------------------------------------------

def _agent_available():
	try:
		return bool(client.run_lua("return agent ~= nil"))
	except (AntiluaError, LuaError):
		return False


def _poll_state(code, done, timeout, interval=0.5):
	"""Poll a Lua expression until `done(state)` holds. Returns the last
	state; {ok: False, error: "timeout", state: ...} when the deadline is hit."""
	deadline = time.monotonic() + max(0.0, timeout)
	state = None
	while True:
		try:
			state = client.run_lua(code)
		except LuaError as exc:
			return {"ok": False, "error": str(exc), "state": state}
		if state is not None and done(state):
			return {"ok": True, **state}
		if time.monotonic() >= deadline:
			return {"ok": False, "error": "timeout", "state": state}
		time.sleep(interval)


@mcp.tool()
def agent_ctx(radius: float = 16.0) -> dict:
	"""One-shot orientation snapshot: position/look, hp/breath/dead flags,
	player state flags, wielded item, inventory summary, movement state,
	last chat id, last formspec, server info, ping/tps, pointed thing and
	nearby objects (sorted by distance, within `radius`)."""
	if not _agent_available():
		return {"ok": False, "error": "agent clientmod not loaded"}
	return client.run_lua("return agent.ctx(%r)" % radius)


@mcp.tool()
def agent_events(since: int = 0, types: list[str] | None = None) -> dict:
	"""Gameplay events newer than `since` (cursor id): chat, death, damage,
	hp, dig/place/node_add/node_remove, object add/hp, inventory changes,
	formspec opens, movement status, survival toggles.
	Returns {events: [{id, ts, type, data}], cursor, dropped}."""
	if not _agent_available():
		return {"ok": False, "error": "agent clientmod not loaded"}
	lua_types = ", ".join(lua_str(t) for t in types or [])
	return client.run_lua("return agent.events(%d, {%s})" % (since, lua_types))


@mcp.tool()
def wait_event(type: str, timeout: float = 10.0, since: int = 0) -> dict:
	"""Block until a gameplay event of `type` occurs (or timeout). Event types:
	chat, death, damage, hp, dignode, placenode, node_add, node_remove,
	object_add, object_hp, inventory, inventory_action, detached_inv,
	formspec, connect, disconnect, move, action, eat, survival."""
	result = _poll_state(
		"return agent.events(%d, {%s})" % (since, lua_str(type)),
		lambda evs: isinstance(evs, dict) and bool(evs.get("events")),
		timeout, interval=0.3)
	if result.get("ok") and isinstance(result.get("events"), list) \
			and result["events"]:
		events = result["events"]
		return {"ok": True, "event": events[0], "cursor": events[-1]["id"]}
	return {"ok": False, "error": result.get("error", "timeout"),
		"cursor": result.get("cursor", since)}


@mcp.tool()
def goto(pos: dict, mode: str = "walk", timeout: float | None = None) -> dict:
	"""Move the agent to {x, y, z}. Modes: "walk" (default; A* pathfinding +
	lua-controlled walking, works on legit servers), "sprint", "fly"
	(velocity-driven flight via free_move/priv_bypass; enable the noclip
	setting yourself if the path may cross terrain), "rtp" (rhythmtp
	burst teleports), "tp" (instant client teleport).
	Returns the final move state {ok, state, dist, ...}."""
	if not _agent_available():
		return {"ok": False, "error": "agent clientmod not loaded"}
	opts = "{timeout=%r}" % timeout if timeout else ""
	res = client.run_lua(
		"return agent.go_to(%s, %s%s)" % (lua_pos(pos), lua_str(mode),
			(", " + opts) if opts else ""))
	if not isinstance(res, dict):
		return {"ok": False, "error": "go_to failed", "result": res}
	if res.get("ok") is False:
		return {"ok": False, "error": res.get("error", "go_to failed")}
	if res.get("state") == "done" or res.get("active") is False:
		return {"ok": True, **res}
	poll_timeout = (timeout + 15) if timeout else 120.0
	return _poll_state("return agent.mstate()",
		lambda s: not s.get("active"), poll_timeout)


@mcp.tool()
def move_state() -> dict:
	"""Current movement controller state: {active, mode, state, target, dist,
	started, deadline} or {active: false, state: "idle"}."""
	if not _agent_available():
		return {"ok": False, "error": "agent clientmod not loaded"}
	return client.run_lua("return agent.mstate()")


@mcp.tool()
def stop_move() -> dict:
	"""Stop the agent's movement controller."""
	if not _agent_available():
		return {"ok": False, "error": "agent clientmod not loaded"}
	return client.run_lua("return agent.stop()")


def _await_action(start_result, extra_timeout=5.0):
	if not start_result or not start_result.get("ok"):
		return {"ok": False, "error": (start_result or {}).get("error",
			"action failed"), **(start_result or {})}
	key = start_result.get("key")
	timeout = start_result.get("timeout", 10) + extra_timeout
	return _poll_state("return agent.action(%s)" % lua_str(key),
		lambda a: not a or a.get("state") != "pending", timeout)


@mcp.tool()
def dig_at(pos: dict, max_time: float = 0, autotool: bool = True,
		timeout: float = 5.0) -> dict:
	"""Dig the node at {x, y, z} with real hold-to-dig timing, auto tool
	selection and server-side verification (watches for the node removal).
	Returns {ok, state: "done"|"timeout", result, node, ...}."""
	if not _agent_available():
		return {"ok": False, "error": "agent clientmod not loaded"}
	opts = "{max_time=%r, autotool=%s, timeout=%r}" % (max_time,
		"true" if autotool else "false", timeout)
	start = client.run_lua("return agent.dig(%s, %s)" % (lua_pos(pos), opts))
	result = _await_action(start)
	result.setdefault("digtime", start.get("digtime") if start else None)
	result.setdefault("node", start.get("node") if start else None)
	return result


@mcp.tool()
def place_at(pos: dict, item: str = "", timeout: float = 5.0) -> dict:
	"""Place `item` (wields it first; empty string = currently wielded) as a
	node at {x, y, z}. Verified against the server's node add.
	Returns {ok, state, result: node_name, ...}."""
	if not _agent_available():
		return {"ok": False, "error": "agent clientmod not loaded"}
	start = client.run_lua(
		"return agent.place(%s, %s, {timeout=%r})"
		% (lua_pos(pos), lua_str(item), timeout))
	result = _await_action(start)
	if result.get("ok") and isinstance(result.get("result"), str):
		result["placed_node"] = result["result"]
	return result


@mcp.tool()
def use_node(pos: dict, timeout: float = 4.0) -> dict:
	"""Right-click the node at {x, y, z} (opens chests/doors/furnaces).
	Returns {ok, state, result: formname} — the formspec that opened, or
	timeout when the node had no right-click handler."""
	if not _agent_available():
		return {"ok": False, "error": "agent clientmod not loaded"}
	start = client.run_lua(
		"return agent.use(%s, {timeout=%r})" % (lua_pos(pos), timeout))
	return _await_action(start)


@mcp.tool()
def punch_object(object_id: int) -> dict:
	"""Aim at and punch the active object (entity/player) with the given id.
	Object ids come from get_objects_near / agent_ctx."""
	if not _agent_available():
		return {"ok": False, "error": "agent clientmod not loaded"}
	return client.run_lua("return agent.punch(%d)" % object_id)


@mcp.tool()
def aim_at(pos: dict, velocity: float = 0, gravity: float = 9.81) -> dict:
	"""Aim the camera at a world position. With `velocity` > 0, applies a
	gravity-compensated ballistic pitch for projectiles (gravity in
	nodes/s²). Returns the resulting look angles."""
	if not _agent_available():
		return {"ok": False, "error": "agent clientmod not loaded"}
	return client.run_lua("return agent.aim(%s, %r, %r)"
		% (lua_pos(pos), velocity, gravity))


@mcp.tool()
def jump() -> dict:
	"""Trigger a single jump."""
	if not _agent_available():
		return {"ok": False, "error": "agent clientmod not loaded"}
	return client.run_lua("return agent.jump()")


@mcp.tool()
def eat() -> dict:
	"""Eat the best available food (uses the autoeat clientmod).
	Verify success via agent_events type "eat"."""
	if not _agent_available():
		return {"ok": False, "error": "agent clientmod not loaded"}
	return client.run_lua("return agent.eat()")


@mcp.tool()
def respawn() -> dict:
	"""Respawn when dead (hp 0)."""
	if not _agent_available():
		return {"ok": False, "error": "agent clientmod not loaded"}
	return client.run_lua("return agent.respawn()")


@mcp.tool()
def survival(enabled: bool = True) -> dict:
	"""Toggle the survival preset: autoeat, autototem, autojump, autorespawn
	and autotool on/off. Returns {applied: {setting: value}}."""
	if not _agent_available():
		return {"ok": False, "error": "agent clientmod not loaded"}
	return client.run_lua("return agent.survival(%s)"
		% ("true" if enabled else "false"))


@mcp.tool()
def agent_mem(key: str, value: str | None = None) -> dict:
	"""Read/write the agent's persistent memory (survives restarts).
	With `value` omitted, returns {key: value}; tables/numbers round-trip."""
	if not _agent_available():
		return {"ok": False, "error": "agent clientmod not loaded"}
	if value is None:
		v = client.run_lua("return agent.mem(%s)" % lua_str(key))
		return {key: v}
	client.run_lua("return agent.mem(%s, %s)"
		% (lua_str(key), lua_str(value)))
	return {"ok": True, "key": key, "value": value}


# ---------------------------------------------------------------------------
# Perception helpers
# ---------------------------------------------------------------------------

@mcp.tool()
def raycast(from_pos: dict, to_pos: dict, objects: bool = True,
		liquids: bool = False, max_points: int = 20) -> dict:
	"""Cast a ray and return hit points {type: "node"|"object", under, above,
	box_id, ...} up to `max_points` (default stops at the first hit; pass a
	larger max_points to see through)."""
	code = (
		"local out = {}; "
		"for pt in core.raycast(%s, %s, %s, %s) do "
		"pt.box_id = nil; out[#out + 1] = pt; "
		"if #out >= %d then break end; "
		"end; return out"
		% (lua_pos(from_pos), lua_pos(to_pos),
			"true" if objects else "false",
			"true" if liquids else "false", max(1, max_points)))
	return client.run_lua(code)


@mcp.tool()
def find_nodes_in_area(min_pos: dict, max_pos: dict,
		node_names: list[str] | None = None) -> dict:
	"""Find nodes inside the box (client-loaded area only). With `node_names`
	filtering; returns {count, positions} (positions capped at 400)."""
	if node_names:
		names = ", ".join(lua_str(n) for n in node_names)
		name_part = ", {%s}" % names
	else:
		name_part = ""
	positions = client.run_lua(
		"local pts = core.find_nodes_in_area(%s, %s%s); "
		"local capped = {}; "
		"for i = 1, math.min(#pts, 400) do capped[i] = pts[i] end; "
		"return {count=#pts, positions=capped}"
		% (lua_pos(min_pos), lua_pos(max_pos), name_part))
	return positions


@mcp.tool()
def line_of_sight(from_pos: dict, to_pos: dict) -> dict:
	"""True when no loaded node blocks the straight line."""
	visible = client.run_lua(
		"return core.line_of_sight(%s, %s)" % (lua_pos(from_pos),
			lua_pos(to_pos)))
	return {"visible": bool(visible)}


@mcp.tool()
def bigmap_pixel(x: int, z: int) -> dict:
	"""Topmost node of a map column from the client-persisted big map:
	{node, param2, height, air_count} or {known: false}."""
	result = client.run_lua(
		"local p = core.al_bigmap:get_pixel(%d, %d); "
		"return p and p or {known=false}" % (x, z))
	return result


@mcp.tool()
def bigmap_coverage() -> dict:
	"""Big map data coverage: {count, bounds} of saved 16x16 blocks."""
	return client.run_lua("return core.al_bigmap:get_coverage()")


@mcp.tool()
def bigmap_section(min_pos: dict, max_pos: dict) -> dict:
	"""Render a section of the saved big map (node columns) to a PNG and
	return its texture path (usable in formspecs; also readable as an image
	file). min_pos/max_pos are {x, z} node column bounds."""
	code = (
		"local tex = core.al_bigmap:render_section("
		"{min={x=%d, z=%d}, max={x=%d, z=%d}}); "
		"return tex and {texture=tex} or {ok=false}"
		% (min_pos["x"], min_pos["z"], max_pos["x"], max_pos["z"]))
	return client.run_lua(code)


@mcp.tool()
def detach() -> dict:
	"""Detach the client (hide window, keep running; screenshots stop working
	until reattach). The session stays addressable via the Lua pipe."""
	return client.run_lua("return core.detach()") or {"ok": True}


@mcp.tool()
def reattach() -> dict:
	"""Reattach a detached client (show its window again)."""
	return client.run_lua("return core.reattach()") or {"ok": True}


def main():
	"""Entry point for the console script / `python -m`."""
	mcp.run()


if __name__ == "__main__":
	main()