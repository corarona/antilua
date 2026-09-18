# Antilua
# SPDX-License-Identifier: LGPL-2.1-or-later

"""End-to-end MCP smoke test: starts the server over stdio, lists tools, and
calls a few (get_player_pos, get_inventory, screenshot). Requires a running
game client reachable via ANTILUA_PIPE_PATH. Run via util/mcp/test_mcp.sh.
"""

import asyncio
import os
import sys

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

SERVER_DIR = os.path.dirname(os.path.abspath(__file__))


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
			names = sorted(t.name for t in tools.tools)
			print("tools (%d): %s" % (len(names), ", ".join(names)))
			assert "get_player_pos" in names
			assert "get_inventory" in names
			assert "screenshot" in names
			assert "run_lua" in names

			res = await session.call_tool("get_player_pos", {})
			text = res.content[0].text
			print("get_player_pos:", text)
			assert '"x"' in text, text

			res = await session.call_tool("get_inventory", {})
			text = res.content[0].text
			print("get_inventory: ok (lists=%s)" % ", ".join(
				key for key in ("main", "craft", "craftresult") if key in text))
			assert "main" in text

			res = await session.call_tool("run_lua", {"code": "return 1+1"})
			text = res.content[0].text
			print("run_lua(1+1):", text)
			assert "2" in text

			res = await session.call_tool("screenshot", {})
			kinds = [c.type for c in res.content]
			print("screenshot content types:", kinds)
			assert "image" in kinds, kinds
			print("MCP SMOKE TEST PASSED")


if __name__ == "__main__":
	asyncio.run(main())