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
rm -rf "$SHOT_DIR"
mkdir -p "$SHOT_DIR"

cleanup() {
	kill $GAME_PID 2>/dev/null || true
	wait $GAME_PID 2>/dev/null || true
	rm -f "$PIPE_PATH" "$CONFIG_FILE"
	rm -rf "$SHOT_DIR"
}
trap cleanup EXIT

cat > "$CONFIG_FILE" << ENDCONF
pipe_lua_enable = true
pipe_lua_path = /tmp/antilua_mcp_test
ENDCONF

echo "=== Antilua MCP Server Smoke Test ==="

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
$VIRT_DISPLAY timeout 90 ./bin/antilua --info --world "worlds/test_df" --go \
	--config "$CONFIG_FILE" </dev/null >/dev/null 2>&1 &
GAME_PID=$!

# Wait for the pipe to appear (up to 20 seconds)
for i in $(seq 1 40); do
	if [ -p "$PIPE_PATH" ]; then
		break
	fi
	sleep 0.5
done

if [ ! -p "$PIPE_PATH" ]; then
	echo "FAIL: Pipe was not created within 20 seconds"
	exit 1
fi

export ANTILUA_PIPE_PATH="$PIPE_PATH"
export ANTILUA_TIMEOUT=15
export ANTILUA_SCREENSHOT_DIR="$SHOT_DIR"

# Run the MCP driver (uses uv if available, else a python3 with mcp<2)
if command -v uv &>/dev/null; then
	uv run --project util/mcp python util/mcp/test_mcp_driver.py
else
	python3 util/mcp/test_mcp_driver.py
fi