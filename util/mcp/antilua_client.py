# Antilua
# SPDX-License-Identifier: LGPL-2.1-or-later

"""Transport layer for talking to a running Antilua client via its Lua pipe.

The client exposes a named FIFO (``pipe_lua_enable = true``) that accepts JSON
lines ``{"code": "...", "file": "...", "serialize": true}`` and writes the
result (first line ``ok``/``error``) to the response file. This module wraps
that protocol with a small, thread-safe API used by the MCP server.
"""

import json
import os
import tempfile
import threading
import time

DEFAULT_PIPE_PATH = "/tmp/antilua_lua"
DEFAULT_TIMEOUT = 10.0


class AntiluaError(Exception):
	"""Transport problem (no pipe, no response, empty reply, ...)."""


class LuaError(AntiluaError):
	"""The Lua code raised an error inside the client."""


def lua_str(value):
	"""Quote a string as a Lua string literal (JSON escapes are Lua-safe)."""
	return json.dumps(value, ensure_ascii=False)


def lua_pos(pos):
	"""Render a {x, y, z} dict (or [x, y, z] list) as a Lua table literal."""
	if isinstance(pos, (list, tuple)) and len(pos) == 3:
		return "{x=%r, y=%r, z=%r}" % (pos[0], pos[1], pos[2])
	return "{x=%r, y=%r, z=%r}" % (pos["x"], pos["y"], pos["z"])


class AntiluaClient:
	"""Sends Lua code to a running client and returns structured results."""

	def __init__(self, pipe_path=None, timeout=None, response_dir=None):
		self.pipe_path = pipe_path or os.environ.get(
			"ANTILUA_PIPE_PATH", DEFAULT_PIPE_PATH)
		self.timeout = float(timeout or os.environ.get(
			"ANTILUA_TIMEOUT", DEFAULT_TIMEOUT))
		self.response_dir = response_dir or tempfile.mkdtemp(
			prefix="antilua_mcp_")
		self._lock = threading.Lock()
		self._counter = 0

	def run_lua(self, code, serialize=True, timeout=None):
		"""Execute Lua code in the client and return the result.

		With ``serialize=True`` (default) the result is parsed into Python
		objects (lists/dicts/numbers/bools/null); ``serialize=False`` returns
		the raw response body text. Raises :class:`LuaError` on Lua errors and
		:class:`AntiluaError` on transport problems.
		"""
		deadline_timeout = timeout or self.timeout
		with self._lock:
			self._counter += 1
			resp_file = os.path.join(
				self.response_dir, "resp_%d_%d" % (os.getpid(), self._counter))
			request = {"code": code, "file": resp_file}
			if serialize:
				request["serialize"] = True
			line = json.dumps(request, separators=(",", ":")) + "\n"

			try:
				fd = os.open(self.pipe_path, os.O_WRONLY)
			except OSError as exc:
				raise AntiluaError(
					"cannot open Lua pipe %s (is the client running with "
					"pipe_lua_enable=true?): %s" % (self.pipe_path, exc))
			try:
				written = os.write(fd, line.encode("utf-8"))
			finally:
				os.close(fd)
			if written != len(line):
				raise AntiluaError("short write to Lua pipe")

			deadline = time.monotonic() + deadline_timeout
			while time.monotonic() < deadline:
				if os.path.exists(resp_file):
					break
				time.sleep(0.05)
			if not os.path.exists(resp_file):
				raise AntiluaError(
					"no response from client within %gs" % deadline_timeout)

			try:
				with open(resp_file, "r", encoding="utf-8", errors="replace") as fh:
					content = fh.read()
			finally:
				try:
					os.unlink(resp_file)
				except OSError:
					pass

		lines = content.splitlines()
		if not lines:
			raise AntiluaError("empty response from client")
		status = lines[0]
		body = "\n".join(lines[1:])
		if status == "error":
			raise LuaError(body or "unknown Lua error")
		if serialize and body:
			try:
				return json.loads(body)
			except json.JSONDecodeError:
				return body
		return body

	def screenshot(self, path, timeout=None):
		"""Request a scene-only screenshot saved to ``path`` and wait for it.

		The client captures on the next rendered frame, so the client must be
		rendering (not detached/hidden). Returns ``path`` once the file exists
		with non-zero size.
		"""
		deadline_timeout = timeout or self.timeout
		code = "return core.make_screenshot({scene_only=true, path=%s})" % lua_str(path)
		self.run_lua(code, serialize=False, timeout=deadline_timeout)
		deadline = time.monotonic() + deadline_timeout
		while time.monotonic() < deadline:
			try:
				if os.path.getsize(path) > 0:
					return path
			except OSError:
				pass
			time.sleep(0.1)
		raise AntiluaError(
			"screenshot was not saved within %gs (is the client rendering?)"
			% deadline_timeout)