#!/usr/bin/env python3
"""Cross-session state for the Oysterity skill.

The agent clientmod's memory dies with the client process, so everything worth
keeping between sessions (base location, stash, which greetings an account has
already used, other players' bases spotted on the saved map) lives in a small
JSON file next to this script.

Usage:
  state.py show [--name ophelia]
  state.py init  [--name ophelia]
  state.py get  KEY [--name ophelia]
  state.py set  KEY JSON [--name ophelia]      # JSON value, e.g. '{"x":1,"y":2,"z":3}'
  state.py set-base X Y Z [--note TEXT] [--name ophelia]
  state.py log  MESSAGE [--name ophelia]
  state.py log-greeting TEXT [--name ophelia]   # record a greeting as used
  state.py greet [--name ophelia] [--as ACTUAL] [--preview] [--json]
  state.py add-base OWNER X Y Z [--name ophelia]
  state.py path [--name ophelia]

`greet` prints the next unused line from greetings.json for the account
(friendly, cynically robotic, "{name}" filled in) and records it as used. The
client Lua sandbox has no io/os.getenv, so the pool and the history live here
rather than in the pipe.

Runtime state files are gitignored; only _template.json is tracked.
"""
import argparse
import json
import os
import pathlib
import secrets
import sys
import time

HERE = pathlib.Path(__file__).resolve().parent
STATE_DIR = pathlib.Path(os.environ.get("OYSTERITY_STATE_DIR", HERE.parent / "state"))
DEFAULT_NAME = os.environ.get("OYSTERITY_NAME", "ophelia")


def state_path(name):
    return STATE_DIR / f"{name}.json"


def load(name):
    path = state_path(name)
    if not path.exists():
        template = STATE_DIR / "_template.json"
        return json.loads(template.read_text()) if template.exists() else {}
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        sys.exit(f"ERROR: {path} is not valid JSON ({exc}); fix or delete it")


def save(name, state):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    state["account"] = name
    state["updated"] = time.strftime("%Y-%m-%dT%H:%M:%S")
    path = state_path(name)
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n")
    tmp.replace(path)
    return path


def ensure(name):
    state = load(name)
    if not state.get("created"):
        state["created"] = time.strftime("%Y-%m-%dT%H:%M:%S")
        save(name, state)
    return state


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("command", choices=[
        "show", "init", "get", "set", "set-base", "log", "log-greeting",
        "greet", "add-base", "path",
    ])
    ap.add_argument("args", nargs="*")
    ap.add_argument("--name", default=DEFAULT_NAME)
    ap.add_argument("--as", dest="as_name", default="",
                    help="account name substituted into the greeting")
    ap.add_argument("--note", default="")
    ap.add_argument("--preview", action="store_true",
                    help="greet: do not record the greeting as used")
    ap.add_argument("--json", action="store_true", help="greet: JSON output")
    opts = ap.parse_args()
    name = opts.name

    if opts.command == "path":
        print(state_path(name))
        return

    if opts.command == "show":
        state = ensure(name)
        print(json.dumps(state, indent=2, sort_keys=True))
        return

    if opts.command == "init":
        print(f"initialized {save(name, ensure(name))}")
        return

    if opts.command == "get":
        if not opts.args:
            sys.exit("ERROR: get needs a key")
        value = load(name)
        for part in opts.args[0].split("."):
            if not isinstance(value, dict) or part not in value:
                print("null")
                return
            value = value[part]
        print(json.dumps(value, indent=2, sort_keys=True))
        return

    if opts.command == "set":
        if len(opts.args) < 2:
            sys.exit("ERROR: set needs KEY and JSON")
        try:
            value = json.loads(opts.args[1])
        except json.JSONDecodeError as exc:
            sys.exit(f"ERROR: value is not valid JSON ({exc})")
        state = ensure(name)
        state[opts.args[0]] = value
        print(f"set {opts.args[0]} -> {json.dumps(value)}")
        save(name, state)
        return

    if opts.command == "set-base":
        if len(opts.args) < 3:
            sys.exit("ERROR: set-base needs X Y Z")
        x, y, z = (int(v) for v in opts.args[:3])
        state = ensure(name)
        state["base"] = {
            "origin": {"x": x, "y": y, "z": z},
            "note": opts.note,
            "established": time.strftime("%Y-%m-%dT%H:%M:%S"),
        }
        print(f"base -> {x},{y},{z} {opts.note}")
        save(name, state)
        return

    if opts.command == "add-base":
        if len(opts.args) < 4:
            sys.exit("ERROR: add-base needs OWNER X Y Z")
        owner, x, y, z = opts.args[0], *(int(v) for v in opts.args[1:4])
        state = ensure(name)
        bases = state.setdefault("known_bases", [])
        for base in bases:
            if base.get("owner") == owner:
                base.update({"x": x, "y": y, "z": z,
                             "seen": time.strftime("%Y-%m-%dT%H:%M:%S")})
                break
        else:
            bases.append({"owner": owner, "x": x, "y": y, "z": z,
                          "seen": time.strftime("%Y-%m-%dT%H:%M:%S")})
        save(name, state)
        print(f"known base: {owner} at {x},{y},{z}")
        return

    if opts.command == "log":
        if not opts.args:
            sys.exit("ERROR: log needs a message")
        message = " ".join(opts.args)
        state = ensure(name)
        state.setdefault("sessions", []).append(
            {"ts": time.strftime("%Y-%m-%dT%H:%M:%S"), "note": message})
        save(name, state)
        print(message)
        return

    if opts.command == "log-greeting":
        text = " ".join(opts.args) if opts.args else None
        if not text:
            sys.exit("ERROR: log-greeting needs the greeting text")
        state = ensure(name)
        used = state.setdefault("greetings_used", [])
        if text not in used:
            used.append(text)
        save(name, state)
        print(f"greeting recorded ({len(used)} used)")
        return

    if opts.command == "greet":
        pool = json.loads((HERE / "greetings.json").read_text())
        state = ensure(name)
        used = state.setdefault("greetings_used", [])
        fresh = [line for line in pool if line not in used]
        if not fresh:
            print(json.dumps({
                "ok": False,
                "error": "greeting pool exhausted for this account",
                "account": name,
                "pool_size": len(pool),
            }) if opts.json else
                f"pool exhausted for {name} ({len(pool)} used) — stay quiet")
            return
        line = secrets.choice(fresh)
        text = line.replace("{name}", opts.as_name or name)
        remaining = len(fresh) - 1
        if not opts.preview:
            used.append(line)
            save(name, state)
        if opts.json:
            print(json.dumps({
                "ok": True,
                "account": name,
                "text": text,
                "sent": not opts.preview,
                "pool_size": len(pool),
                "remaining": remaining,
            }))
        else:
            print(text)
        return


if __name__ == "__main__":
    main()
