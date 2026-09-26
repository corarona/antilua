#!/bin/bash -e
# Smoke-test the Antilua MCP server against a headless game instance.
# Requires xvfb-run or Xvfb and uv (or a python3 with the mcp<2 package).
#
# Usage:
#   ./util/mcp/test_mcp.sh

cd "$(dirname "$0")/../.."

PIPE_PATH="/tmp/antilua_mcp_test"
SHOT_DIR="/tmp/antilua_mcp_shots"
CONFIG_FILE=$(mktemp)
WORLD="worlds/test_df"
rm -f "$PIPE_PATH"
rm -rf "$SHOT_DIR"
mkdir -p "$SHOT_DIR"

cleanup() {
	# The game runs under "timeout" beneath xvfb-run; killing only $GAME_PID
	# orphans the antilua process (it holds the world + pipe open), so kill
	# the whole tree by matching the world path, then any leftover Xvfb.
	pkill -f "$WORLD" 2>/dev/null || true
	kill $GAME_PID 2>/dev/null || true
	wait $GAME_PID 2>/dev/null || true
	pkill Xvfb 2>/dev/null || true
	rm -f "$PIPE_PATH" "$CONFIG_FILE"
	rm -rf "$SHOT_DIR"
}
trap cleanup EXIT

cat > "$CONFIG_FILE" << ENDCONF
pipe_lua_enable = true
pipe_lua_path = /tmp/antilua_mcp_test
ENDCONF

echo "=== Antilua MCP Server Smoke Test ==="

# Use a fresh world each run: earlier runs leave debris, entities and inventory
# behind that make the tool assertions non-deterministic. Keep world.mt (it
# sets the game to devtest) but wipe the data and force damage off so the
# teleport-and-fall steps can't kill the player.
if [ -f "$WORLD/world.mt" ]; then
	find "$WORLD" -mindepth 1 -maxdepth 1 ! -name world.mt -exec rm -rf {} +
	if grep -q '^enable_damage' "$WORLD/world.mt"; then
		sed -i 's/^enable_damage.*/enable_damage = false/' "$WORLD/world.mt"
	else
		printf 'enable_damage = false\n' >> "$WORLD/world.mt"
	fi
else
	mkdir -p "$WORLD"
	printf 'gameid = devtest\nenable_damage = false\n' > "$WORLD/world.mt"
fi

# Find virtual display tool
if command -v xvfb-run &>/dev/null; then
	VIRT_DISPLAY="xvfb-run --auto-servernum"
elif command -v Xvfb &>/dev/null; then
	Xvfb :99 -screen 0 1024x768x24 &
	export DISPLAY=:99
else
	echo "SKIP: Need xvfb-run or Xvfb for headless testing"
	exit 0
fi

# Start game in background
$VIRT_DISPLAY timeout 120 ./bin/antilua --info --world "$WORLD" --go \
	--config "$CONFIG_FILE" </dev/null >/dev/null 2>&1 &
GAME_PID=$!

# Wait for the pipe to appear (up to 40 seconds; a fresh world takes longer)
for i in $(seq 1 80); do
	if [ -p "$PIPE_PATH" ]; then
		break
	fi
	sleep 0.5
done

if [ ! -p "$PIPE_PATH" ]; then
	echo "FAIL: Pipe was not created within 40 seconds"
	exit 1
fi

export ANTILUA_PIPE_PATH="$PIPE_PATH"
export ANTILUA_TIMEOUT=30
export ANTILUA_SCREENSHOT_DIR="$SHOT_DIR"

# Run the MCP driver (uses uv if available, else a python3 with mcp<2)
if command -v uv &>/dev/null; then
	uv run --project util/mcp python util/mcp/test_mcp_driver.py
else
	python3 util/mcp/test_mcp_driver.py
fi