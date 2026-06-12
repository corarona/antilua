#!/bin/bash -e
# Test the Client Lua Pipe (named pipe IPC for client-side Lua execution)
# Requires xvfb-run or Xvfb for headless display.
#
# Usage:
#   ./util/ci/test_pipe_lua.sh

PIPE_PATH="/tmp/antilua_lua_test"
RESP_FILE="/tmp/antilua_lua_test_resp"
CONFIG_FILE=$(mktemp)

cleanup() {
	kill $GAME_PID 2>/dev/null || true
	wait $GAME_PID 2>/dev/null || true
	rm -f "$PIPE_PATH" "$RESP_FILE" "$CONFIG_FILE"
}
trap cleanup EXIT

# Create config with pipe enabled
cat > "$CONFIG_FILE" << 'ENDCONF'
pipe_lua_enable = true
pipe_lua_path = /tmp/antilua_lua_test
ENDCONF

echo "=== Client Lua Pipe Test ==="

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

# Start game in background with 30s timeout
$VIRT_DISPLAY timeout 30 ./bin/antilua --info --world "worlds/test_df" --go \
	--config "$CONFIG_FILE" 2>/dev/null &
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

PASS_COUNT=0
FAIL_COUNT=0

check() {
	local name="$1"
	local expected="$2"
	local actual="$3"
	if [ "$actual" = "$expected" ]; then
		echo "  PASS: $name"
		PASS_COUNT=$((PASS_COUNT + 1))
	else
		echo "  FAIL: $name"
		echo "    expected: $expected"
		echo "    got:      $actual"
		FAIL_COUNT=$((FAIL_COUNT + 1))
	fi
}

# Test 1: simple arithmetic expression
echo '{"code":"return 1+1","file":"'$RESP_FILE'"}' > "$PIPE_PATH"
sleep 0.5
RESULT=$(cat "$RESP_FILE" 2>/dev/null || echo "timeout")
check "simple expression" "$(printf "ok\n2")" "$RESULT"

# Test 2: error handling
echo '{"code":"error(\"test error\")","file":"'$RESP_FILE'"}' > "$PIPE_PATH"
sleep 0.5
RESULT=$(cat "$RESP_FILE" 2>/dev/null || echo "timeout")
if echo "$RESULT" | head -1 | grep -q '^error$'; then
	echo "  PASS: error handling"
	PASS_COUNT=$((PASS_COUNT + 1))
else
	echo "  FAIL: error handling"
	echo "    expected: error/..."
	echo "    got:      $RESULT"
	FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Test 3: string result
echo '{"code":"return \"hello\"","file":"'$RESP_FILE'"}' > "$PIPE_PATH"
sleep 0.5
RESULT=$(cat "$RESP_FILE" 2>/dev/null || echo "timeout")
check "string result" "$(printf "ok\nhello")" "$RESULT"

# Test 4: boolean results
echo '{"code":"return true, false","file":"'$RESP_FILE'"}' > "$PIPE_PATH"
sleep 0.5
RESULT=$(cat "$RESP_FILE" 2>/dev/null || echo "timeout")
check "boolean results" "$(printf "ok\ntrue\nfalse")" "$RESULT"

# Test 5: nil result
echo '{"code":"return nil","file":"'$RESP_FILE'"}' > "$PIPE_PATH"
sleep 0.5
RESULT=$(cat "$RESP_FILE" 2>/dev/null || echo "timeout")
check "nil result" "$(printf "ok\nnil")" "$RESULT"

# Test 6: no return value
echo '{"code":"local x = 1","file":"'$RESP_FILE'"}' > "$PIPE_PATH"
sleep 0.5
RESULT=$(cat "$RESP_FILE" 2>/dev/null || echo "timeout")
check "no return value" "$(printf "ok")" "$RESULT"

# Test 7: table serialization via tostring
echo '{"code":"return {1,2,3}","file":"'$RESP_FILE'"}' > "$PIPE_PATH"
sleep 0.5
RESULT=$(cat "$RESP_FILE" 2>/dev/null || echo "timeout")
FIRST_LINE=$(echo "$RESULT" | head -1)
if [ "$FIRST_LINE" = "ok" ]; then
	echo "  PASS: table result"
	PASS_COUNT=$((PASS_COUNT + 1))
else
	echo "  FAIL: table result"
	echo "    got: $RESULT"
	FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo ""
echo "=== Results: $PASS_COUNT passed, $FAIL_COUNT failed ==="
[ "$FAIL_COUNT" -eq 0 ]
