#!/usr/bin/env python3
"""Send a Lua script file to the Antilua pipe and print the response."""
import json, sys, time

lua_file = sys.argv[1]
with open(lua_file) as f:
    code = f.read()

payload = json.dumps({"code": code, "file": "/tmp/antilua_lua_response"})
with open("/tmp/antilua_lua", "w") as f:
    f.write(payload + "\n")

time.sleep(0.8)

with open("/tmp/antilua_lua_response") as f:
    print(f.read().strip())
