#!/bin/bash -e
# Launch a windowed (or headless) Antilua client connected to a server with
# the Lua pipe enabled, ready for MCP-driven agent play.
#
# Usage:
#   scripts/agent_play.sh [--server HOST:PORT] [--name NAME] [--password PW]
#                         [--password-file FILE] [--headless] [--world W]
#                         [--fresh] [--sound]
#
# Defaults: oy.edgy1.net:30420 (oysterity anarchy), name "hamlet".
# Fresh agents use Shakespearean character names (hamlet, ophelia, horatio,
# falstaff, ...); `--name` overrides. `--fresh` wipes the agent's per-server
# client data dir (mod storage) first.
#
# The script exits as soon as the Lua pipe answers (the client keeps running).

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$REPO_ROOT/bin/antilua"

SERVER="oy.edgy1.net:30420"
NAME="hamlet"
PASSWORD=""
PASSWORD_FILE=""
HEADLESS=0
WORLD=""
FRESH=0
SOUND=0
PIPE_PATH="/tmp/antilua_lua"

usage() { grep '^#' "$0" | head -16; exit 0; }
[ "$1" = "-h" ] || [ "$1" = "--help" ] && usage

while [ $# -gt 0 ]; do
	case "$1" in
	--server) SERVER="$2"; shift 2 ;;
	--name) NAME="$2"; shift 2 ;;
	--password) PASSWORD="$2"; shift 2 ;;
	--password-file) PASSWORD_FILE="$2"; shift 2 ;;
	--headless) HEADLESS=1; shift ;;
	--world) WORLD="$2"; shift 2 ;;
	--fresh) FRESH=1; shift ;;
	--sound) SOUND=1; shift ;;
	--pipe) PIPE_PATH="$2"; shift 2 ;;
	*) echo "Unknown option: $1"; usage ;;
	esac
done

if [ ! -x "$BIN" ]; then
	echo "ERROR: $BIN not found — build first (cmake -B build && cmake --build build -j3)"
	exit 1
fi

# Only one client may hold the pipe
if [ -p "$PIPE_PATH" ] && pgrep -x antilua >/dev/null 2>&1; then
	echo "ERROR: an antilua process is already running and would conflict on $PIPE_PATH"
	pgrep -ax antilua
	exit 1
fi

HOST="${SERVER%%:*}"
PORT="${SERVER##*:}"

CONF=$(mktemp /tmp/antilua_agent_conf.XXXXXX)
cat > "$CONF" << ENDCONF
name = $NAME
pipe_lua_enable = true
pipe_lua_path = $PIPE_PATH
address = $HOST
remote_port = $PORT
enable_minimap = true
autorespawn = true
auto_reconnect = true
auto_reconnect_delay = 3.0
mute_sound = $([ $SOUND -eq 1 ] && echo false || echo true)
ENDCONF

ARGS=(--go --config "$CONF" --logfile /tmp/antilua_agent_debug.txt --name "$NAME")
[ -n "$PASSWORD" ] && ARGS+=(--password "$PASSWORD")
[ -n "$PASSWORD_FILE" ] && ARGS+=(--password-file "$PASSWORD_FILE")

if [ -n "$WORLD" ]; then
	ARGS+=(--world "$WORLD")   # local game; address is ignored
elif [ "$HOST" != "" ]; then
	ARGS+=(--address "$HOST" --port "$PORT")
fi

rm -f "$PIPE_PATH" /tmp/antilua_agent_probe

if [ $FRESH -eq 1 ]; then
	DIR="$HOME/.local/share/antilua/data/server/${HOST}_${PORT}"
	[ -d "$DIR" ] && rm -rf "$DIR" && echo "Cleared $DIR"
fi

echo "=== agent_play: $NAME -> $SERVER (pipe: $PIPE_PATH) ==="

if [ $HEADLESS -eq 1 ]; then
	if ! command -v xvfb-run >/dev/null 2>&1; then
		echo "ERROR: --headless needs xvfb-run (package xvfb)"
		exit 1
	fi
	setsid xvfb-run -a "$BIN" "${ARGS[@]}" >/tmp/antilua_agent_out.txt 2>&1 < /dev/null &
else
	setsid "$BIN" "${ARGS[@]}" >/tmp/antilua_agent_out.txt 2>&1 < /dev/null &
fi

# Wait for the pipe to appear and answer
echo -n "Waiting for the Lua pipe "
for i in $(seq 1 180); do
	if [ -p "$PIPE_PATH" ]; then
		printf '{"code":"return 1","file":"/tmp/antilua_agent_probe"}\n' > "$PIPE_PATH" 2>/dev/null && break
	fi
	echo -n "."
	sleep 0.5
done
echo

if [ ! -p "$PIPE_PATH" ]; then
	echo "FAIL: pipe never appeared — see /tmp/antilua_agent_debug.txt"
	exit 1
fi

for i in $(seq 1 120); do
	if [ -f /tmp/antilua_agent_probe ]; then
		echo "pipe responds: $(cat /tmp/antilua_agent_probe)"
		break
	fi
	sleep 0.5
done

echo "Client running (windowed). Join status: tail -f /tmp/antilua_agent_debug.txt"
echo "MCP tools are live. Disconnect-safe: use the 'antilua' MCP server tools."
