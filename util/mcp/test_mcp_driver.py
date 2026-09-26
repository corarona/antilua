# Antilua
# SPDX-License-Identifier: LGPL-2.1-or-later

"""End-to-end MCP smoke test: starts the server over stdio, lists tools, and
exercises every MCP tool against a running client reachable via
ANTILUA_PIPE_PATH. Run via util/mcp/test_mcp.sh (which boots a fresh world).

The driver uses a fresh world (terrain varies per run) and builds its own test
surface, so the world-interaction assertions are terrain-independent.
"""

import asyncio
import json
import math
import os
import sys

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

SERVER_DIR = os.path.dirname(os.path.abspath(__file__))

EXPECTED_TOOLS = {
	"run_lua", "get_player_pos", "get_player_look", "teleport", "set_look",
	"get_node", "dig_node", "place_node", "find_nodes_near",
	"find_nodes_near_under_air", "get_pointed_thing", "get_inventory",
	"get_node_meta", "set_node_meta", "interact", "get_objects_near",
	"move_item", "craft", "take_craft_result", "move_items",
	"wield_item", "give_and_wield", "run_server_chatcommand", "get_chat_log",
	"wait_until", "get_client_status", "send_chat", "get_server_info",
	"get_player_names", "get_privilege_list", "set_time", "set_setting",
	"toggle_cheat", "screenshot",
}


async def call(session, name, args):
	"""Call a tool; returns the text of the first content block, or None if
	the tool produced no content (nil result). Transient transport errors
	(e.g. the client busy emerging after a teleport) are retried a few times."""
	for attempt in range(5):
		res = await session.call_tool(name, args)
		if not res.isError:
			return res.content[0].text if res.content else None
		text = res.content[0].text if res.content else ""
		transient = ("empty response from client" in text
			or "no response from client" in text)
		if not transient or attempt == 4:
			raise AssertionError("%s failed: %s" % (name, text))
		await asyncio.sleep(1.0)
	return None


async def call_lenient(session, name, args):
	"""Like call() but tolerates transient tool errors (e.g. the client being
	busy with map emerge after a long teleport). Returns (text, error)."""
	try:
		return await call(session, name, args), None
	except AssertionError as exc:
		return None, str(exc)


async def call_json(session, name, args):
	text = await call(session, name, args)
	assert text, "%s returned no content (nil?)" % name
	return json.loads(text)


async def wait_for(session, name, args, pred, tries=60, delay=0.5):
	for _ in range(tries):
		val = await call_json(session, name, args)
		if pred(val):
			return val
		await asyncio.sleep(delay)
	raise AssertionError("%s(%s) never satisfied predicate; last=%r"
			% (name, args, val))


async def wait_for_landed(session, tries=120, delay=0.5):
	"""Wait until the player is effectively stationary (landed after a fall,
	or drifting down slowly in water). Tolerates transient pipe stalls (the
	client can be busy emerging after a teleport)."""
	speeds = []
	history = []
	last_error = None
	for _ in range(tries):
		text, err = await call_lenient(session, "get_player_pos", {})
		if text is None:
			last_error = err
			await asyncio.sleep(delay)
			continue
		p = json.loads(text)
		speeds.append(abs(p["y"] - history[-1]) / delay if history else 99.0)
		history.append(p["y"])
		if len(speeds) >= 3 and max(speeds[-3:]) < 0.3:
			return p
		await asyncio.sleep(delay)
	raise AssertionError("player never landed (y history=%r, last_error=%r)"
			% (history[-8:], last_error))


async def pointed_ground(session):
	"""Aim straight down; returns the raw pointed thing (nil when underwater
	or looking at sky — both legitimate)."""
	await call_json(session, "set_look", {"yaw": 0.0, "pitch": 90.0})
	text = await call(session, "get_pointed_thing", {})
	return json.loads(text) if text else {"type": "nothing"}


async def pick_build_spot(session):
	"""Pick a build spot: a solid surface with air above, at least 2 blocks
	from the player's column and within interact reach. Returns the air node
	position to build on, or None. Avoids moving the player at all."""
	player = await call_json(session, "get_player_pos", {})
	res = await call_json(session, "find_nodes_near_under_air",
		{"pos": player, "radius": 6, "except_names": [
			"air", "basenodes:water_source", "basenodes:lava_source"]})
	for p in res.get("positions", []):
		spot = {"x": p["x"], "y": p["y"] + 1, "z": p["z"]}
		if max(abs(spot["x"] - round(player["x"])),
				abs(spot["z"] - round(player["z"]))) < 2:
			continue  # would land inside the player
		dist = math.dist(
			(spot["x"] + 0.5, spot["y"] + 0.5, spot["z"] + 0.5),
			(player["x"], player["y"] + 1.0, player["z"]))
		if dist <= 7.0:
			return spot
	return None


# Hop offsets used to seek dry land when the first landing is ocean.
SEEK_OFFSETS = [(16, 0), (0, 16), (-16, 0), (0, -16), (32, 0), (0, 32),
	(-32, 0), (0, -32), (48, 0), (0, 48), (-48, 0), (0, -48)]


async def seek_build_spot(session):
	"""Teleport-hop in an expanding spiral until a land build spot is found
	(fresh-world spawn can be open ocean, where no surface has air above)."""
	p = await call_json(session, "get_player_pos", {})
	for dx, dz in SEEK_OFFSETS:
		await call_json(session, "teleport",
			{"pos": {"x": p["x"] + dx, "y": 170.5, "z": p["z"] + dz}})
		await wait_for_landed(session)
		spot = await pick_build_spot(session)
		if spot is not None:
			return spot
	return None


async def pick_build_spot(session):
	"""Pick a build spot: a solid surface with air above, at least 2 blocks
	from the player's column and within interact reach. Returns the air node
	position to build on, or None. Avoids moving the player at all."""
	player = await call_json(session, "get_player_pos", {})
	res = await call_json(session, "find_nodes_near_under_air",
		{"pos": player, "radius": 6, "except_names": [
			"air", "basenodes:water_source", "basenodes:lava_source"]})
	for p in res.get("positions", []):
		spot = {"x": p["x"], "y": p["y"] + 1, "z": p["z"]}
		if max(abs(spot["x"] - round(player["x"])),
				abs(spot["z"] - round(player["z"]))) < 2:
			continue  # would land inside the player
		dist = math.dist(
			(spot["x"] + 0.5, spot["y"] + 0.5, spot["z"] + 0.5),
			(player["x"], player["y"] + 1.0, player["z"]))
		if dist <= 7.0:
			return spot
	return None


async def main():
	params = StdioServerParameters(
		command=sys.executable,
		args=["-m", "server"],
		cwd=SERVER_DIR,
		env={**os.environ},
	)
	async with stdio_client(params) as (read, write):
		async with ClientSession(read, write) as session:
			await session.initialize()

			tools = await session.list_tools()
			names = set(t.name for t in tools.tools)
			print("tools (%d): %s" % (len(names), ", ".join(sorted(names))))
			assert EXPECTED_TOOLS <= names, "missing tools: %s" % (
				EXPECTED_TOOLS - names)

			# --- player ---
			pos = await call_json(session, "get_player_pos", {})
			print("get_player_pos:", pos)
			assert all(k in pos for k in ("x", "y", "z"))

			look = await call_json(session, "get_player_look", {})
			print("get_player_look:", look)
			assert all(k in look for k in ("yaw", "pitch", "roll"))

			# Land on the ground so the world tests run on solid terrain.
			# Teleport high (above any mapgen mountain) so the player always
			# falls onto a surface instead of embedding in a peak.
			tpos = await call_json(session, "teleport",
				{"pos": {"x": 8.5, "y": 150.5, "z": 8.5}})
			print("teleport:", tpos)
			assert abs(tpos["x"] - 8.5) < 0.01 and abs(tpos["z"] - 8.5) < 0.01
			assert abs(tpos["y"] - 150.5) < 0.5

			pos = await wait_for_landed(session)
			print("landed:", pos)

			slook = await call_json(session, "set_look",
				{"yaw": 0.0, "pitch": 90.0})
			print("set_look:", slook)
			assert all(k in slook for k in ("yaw", "pitch"))

			pt = await pointed_ground(session)
			print("get_pointed_thing:", pt)
			assert pt.get("type") in ("node", "object", "nothing"), pt

			# Build spot: find a solid surface with air above near the player
			# without moving; fresh-world spawn may be open ocean, in which
			# case hop outward until dry land is found.
			spot = await pick_build_spot(session)
			if spot is None:
				spot = await seek_build_spot(session)
			print("pick_build_spot:", spot)
			assert spot is not None, "no land build spot found nearby"

			# --- status / chat feedback / grant ---
			status = await call_json(session, "get_client_status", {})
			print("get_client_status:", status)
			assert status.get("connected") is True and status.get("joined") is True
			assert status.get("player_name") == "singleplayer"
			assert status.get("chat_buffer") is True

			grant = await call_json(session, "run_server_chatcommand",
				{"command": "grantme", "args": "all", "wait": 2.0})
			print("grantme chat: %d line(s)" % len(grant.get("chat", [])))
			assert grant.get("ok") is True, grant
			assert any("privileges" in line.get("text", "").lower()
				for line in grant.get("chat", [])), grant

			pl = await wait_for(session, "get_privilege_list", {},
				lambda p: p.get("give") is True)
			print("get_privilege_list: %d privilege(s), give=%s" % (
				len(pl), pl.get("give")))

			log = await call_json(session, "get_chat_log", {"count": 5})
			print("get_chat_log: %d line(s), last=%r" % (len(log.get("lines", [])),
				(log.get("lines") or [{}])[-1].get("text")))
			assert log.get("lines"), log

			# --- give + wield via the composite tool ---
			gw = await wait_for(session, "give_and_wield",
				{"name": "basenodes:cobble", "count": 1},
				lambda r: r.get("ok") is True, tries=10, delay=1.0)
			print("give_and_wield: slot=%s name=%s" % (
				gw.get("slot"), gw.get("name")))
			assert gw.get("name") == "basenodes:cobble", gw

			mv = await call_json(session, "move_item",
				{"from_list": "main", "from_slot": gw["slot"],
					"to_list": "main", "to_slot": 1})
			print("move_item (wield cobble):", mv.get("applied"), mv.get("error"))
			assert mv.get("applied") is True, mv

			wi = await wait_for(session, "wield_item", {"name": "cobble"},
				lambda r: r.get("ok") is True and
					r.get("name") == "basenodes:cobble")
			print("wield_item:", wi)

			pn = await wait_for(session, "place_node", {"pos": spot},
				lambda p: p.get("placed") is True
					and (p.get("node") or {}).get("name") == "basenodes:cobble",
				tries=10, delay=1.0)
			print("place_node:", pn)

			node = await wait_for(session, "get_node", {"pos": spot},
				lambda n: (n.get("node") or {}).get("name") == "basenodes:cobble")
			print("get_node:", node)

			# The placed cobble must exist near the player (within reach).
			player = await call_json(session, "get_player_pos", {})
			found = await call_json(session, "find_nodes_near",
				{"pos": player, "radius": 8,
					"node_names": ["basenodes:cobble"]})
			print("find_nodes_near: count=%d positions=%s" % (
				found.get("count"), found.get("positions")))
			assert found.get("count", 0) >= 1, found

			air = await call_json(session, "find_nodes_near",
				{"pos": spot, "radius": 3, "node_names": [
					"air", "basenodes:cobble", "basenodes:stone",
					"basenodes:dirt", "basenodes:dirt_with_grass",
					"basenodes:gravel", "basenodes:sand"]})
			print("find_nodes_near(surface): count=%d" % air.get("count", 0))
			assert air.get("count", 0) > 0, air

			# Wield the instant pick before digging so the server accepts it.
			inv = await call_json(session, "get_inventory", {})
			pick_slot = next(i["slot"] for i in inv["main"]
				if i["name"] == "basetools:pick_mese")
			await call_json(session, "move_item",
				{"from_list": "main", "from_slot": pick_slot,
					"to_list": "main", "to_slot": 1})

			dg = await call_json(session, "dig_node", {"pos": spot})
			print("dig_node:", dg)
			assert dg.get("digged") is True, dg

			gone = await wait_for(session, "get_node", {"pos": spot},
				lambda n: n.get("node") is None
					or n["node"].get("name") in ("air", "ignore"))
			print("get_node after dig:", gone)

			# --- find_nodes_near_under_air: surfaces near the spot ---
			ua = await call_json(session, "find_nodes_near_under_air",
				{"pos": spot, "radius": 5, "except_names": [
					"air", "basenodes:cobble"]})
			print("find_nodes_near_under_air: count=%d" % ua.get("count", 0))
			assert ua.get("count", 0) > 0, ua

			# --- node meta: read (nil-safe) + write path ---
			meta = await call_json(session, "get_node_meta", {"pos": spot})
			print("get_node_meta: keys=%d" % len(meta.get("meta", {})))
			assert isinstance(meta.get("meta"), dict), meta

			meta = await call_json(session, "get_node_meta",
				{"pos": spot, "keys": ["nonexistent_key"]})
			print("get_node_meta(keys):", meta.get("meta"))
			assert meta.get("meta", {}).get("nonexistent_key") == "", meta

			snm = await call_json(session, "set_node_meta",
				{"pos": spot, "fields": {"x": "y"}})
			print("set_node_meta:", snm)
			assert snm.get("sent") is True, snm

			# --- interact: right-click / air-use paths ---
			ia = await call_json(session, "interact",
				{"action": "use",
					"pointed": {"type": "node",
						"under": {"x": spot["x"], "y": spot["y"] - 1, "z": spot["z"]},
						"above": spot}})
			print("interact(use node):", ia)
			assert ia.get("ok") is True, ia

			ia = await call_json(session, "interact",
				{"action": "activate"})
			print("interact(activate nothing):", ia)
			assert ia.get("ok") is True, ia

			ia = await call_json(session, "interact", {"action": "bogus"})
			print("interact(bogus):", ia)
			assert ia.get("ok") is False, ia

			# --- objects near: spawn an entity and find it ---
			await call_json(session, "run_server_chatcommand",
				{"command": "spawnentity", "args": "basenodes:apple", "wait": 3.0})
			objs = await call_json(session, "get_objects_near",
				{"pos": spot, "radius": 12.0})
			print("get_objects_near: %d object(s)" % len(objs.get("objects", [])))
			assert objs.get("objects"), objs

			# --- wait_until: immediate, timeout, and error paths ---
			wu = await call_json(session, "wait_until",
				{"code": "return core.localplayer ~= nil",
					"timeout": 3.0, "interval": 0.2})
			print("wait_until(success):", wu.get("ok"), wu.get("value"))
			assert wu.get("ok") is True and wu.get("value") is True, wu

			wu = await call_json(session, "wait_until",
				{"code": "return nil", "timeout": 1.0, "interval": 0.3})
			print("wait_until(timeout):", wu)
			assert wu.get("ok") is False and wu.get("error") == "timeout", wu

			wu = await call_json(session, "wait_until",
				{"code": "error('nope')", "timeout": 1.0})
			print("wait_until(error):", wu)
			assert wu.get("ok") is False and "nope" in wu.get("error", ""), wu

			# --- move_items batch: two moves in one call ---
			inv = await call_json(session, "get_inventory", {})
			main = inv.get("main", [])
			src = next(i for i in main if i.get("count", 0) >= 1)
			empty = 8
			batch = await call_json(session, "move_items", {"moves": [
				{"from_list": "main", "from_slot": src["slot"],
					"to_list": "main", "to_slot": empty},
				{"from_list": "main", "from_slot": empty,
					"to_list": "main", "to_slot": src["slot"]}]})
			print("move_items: applied=%s" % [r.get("applied")
				for r in batch.get("results", [])])
			assert all(r.get("applied") is True
				for r in batch.get("results", [])), batch

			# --- inventory crafting ---
			cr = await call_json(session, "craft", {"count": 1})
			print("craft:", cr.get("applied"), cr.get("error"))
			assert cr.get("applied") is True, cr

			tc = await call_json(session, "take_craft_result", {"target_slot": 2})
			print("take_craft_result:", tc.get("applied"), tc.get("error"))
			assert tc.get("applied") is True, tc

			# --- server ---
			si = await call_json(session, "get_server_info", {})
			print("get_server_info:", si)
			assert "address" in si and "port" in si

			names = await call_json(session, "get_player_names", {})
			print("get_player_names:", names)
			assert isinstance(names.get("players"), list) and names["players"]

			pl = await call_json(session, "get_privilege_list", {})
			print("get_privilege_list (again): %d privilege(s)" % len(pl))
			assert isinstance(pl, dict) and pl

			st = await call_json(session, "run_server_chatcommand",
				{"command": "status"})
			print("run_server_chatcommand(status):", st.get("ok"),
				"chat=%d" % len(st.get("chat", [])))
			assert st.get("ok") is True, st
			assert any("uptime" in line.get("text", "").lower()
				for line in st.get("chat", [])), st

			tm = await call_json(session, "set_time", {"value": "noon"})
			print("set_time(noon): chat=%d line(s)" % len(tm.get("chat", [])))
			assert tm.get("ok") is True, tm

			sent = await call_json(session, "send_chat",
				{"message": "mcp smoke test"})
			print("send_chat:", sent)
			assert sent.get("sent") is True

			# --- settings / cheats ---
			ss = await call_json(session, "set_setting",
				{"name": "mute_sound", "value": "true"})
			print("set_setting:", ss)
			assert ss in ("true", True), ss

			tc2 = await call_json(session, "toggle_cheat",
				{"name": "jetpack", "enabled": False})
			print("toggle_cheat:", tc2)
			assert tc2 in ("false", False), tc2

			# --- raw escape hatch ---
			rl = await call_json(session, "run_lua", {"code": "return 1+1"})
			print("run_lua(1+1):", rl)
			assert rl.get("ok") is True and rl.get("value") == 2, rl

			rl = await call_json(session, "run_lua",
				{"code": "error('boom')"})
			print("run_lua(error):", rl)
			assert rl.get("ok") is False and "boom" in rl.get("error", ""), rl

			# --- screenshot ---
			for name, args in [("screenshot", {}), ("screenshot", {"pos": spot})]:
				look_before = await call_json(session, "get_player_look", {})
				res = await session.call_tool(name, args)
				kinds = [c.type for c in res.content]
				print("%s content types:" % name, kinds)
				assert not res.isError, (name, res.content[0].text
					if res.content else res)
				assert "image" in kinds, kinds
				if args.get("pos"):
					look_after = await call_json(session, "get_player_look", {})
					print("look restored: %r -> %r" % (
						(look_before.get("yaw"), look_before.get("pitch")),
						(look_after.get("yaw"), look_after.get("pitch"))))
					assert abs(look_after.get("pitch", 0)
						- look_before.get("pitch", 0)) < 0.01

					def yaw_diff(a, b):
						return abs(((a - b + 180.0) % 360.0) - 180.0)
					assert yaw_diff(look_after.get("yaw", 0),
						look_before.get("yaw", 0)) < 0.01

			print("MCP SMOKE TEST PASSED")


if __name__ == "__main__":
	asyncio.run(main())