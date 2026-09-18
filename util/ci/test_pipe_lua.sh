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
	rm -f "$PIPE_PATH" "$RESP_FILE" /tmp/antilua_lua_test_resp_* "$CONFIG_FILE"
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

# Start game in background with 90s timeout
$VIRT_DISPLAY timeout 90 ./bin/antilua --info --world "worlds/test_df" --go \
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

# Write a JSON request to the pipe with a unique response file, then poll for
# the response (up to 10s) to avoid races with the client still initializing.
TEST_NUM=0
send() {
	local code="$1"
	local serialize="$2"
	TEST_NUM=$((TEST_NUM + 1))
	local resp="/tmp/antilua_lua_test_resp_$TEST_NUM"
	rm -f "$resp"
	local json
	if [ -n "$serialize" ]; then
		json="{\"code\":$code,\"file\":\"$resp\",\"serialize\":true}"
	else
		json="{\"code\":$code,\"file\":\"$resp\"}"
	fi
	echo "$json" > "$PIPE_PATH"
	for i in $(seq 1 40); do
		[ -s "$resp" ] && break
		sleep 0.25
	done
	cat "$resp" 2>/dev/null || echo "timeout"
}

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
RESULT=$(send '"return 1+1"')
check "simple expression" "$(printf "ok\n2")" "$RESULT"

# Test 2: error handling
RESULT=$(send '"error(\"test error\")"')
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
RESULT=$(send '"return \"hello\""')
check "string result" "$(printf "ok\nhello")" "$RESULT"

# Test 4: boolean results
RESULT=$(send '"return true, false"')
check "boolean results" "$(printf "ok\ntrue\nfalse")" "$RESULT"

# Test 5: nil result
RESULT=$(send '"return nil"')
check "nil result" "$(printf "ok\nnil")" "$RESULT"

# Test 6: no return value
RESULT=$(send '"local x = 1"')
check "no return value" "$(printf "ok")" "$RESULT"

# Test 7: table serialization via tostring
RESULT=$(send '"return {1,2,3}"')
FIRST_LINE=$(echo "$RESULT" | head -1)
if [ "$FIRST_LINE" = "ok" ]; then
	echo "  PASS: table result"
	PASS_COUNT=$((PASS_COUNT + 1))
else
	echo "  FAIL: table result"
	echo "    got: $RESULT"
	FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Test 8: serialize object
RESULT=$(send '"return {a=1, b=\"x\", c=true}"' serialize)
check "serialize object" "$(printf 'ok\n{"a":1,"b":"x","c":true}')" "$RESULT"

# Test 9: serialize array
RESULT=$(send '"return {1,2,3}"' serialize)
check "serialize array" "$(printf 'ok\n[1,2,3]')" "$RESULT"

# Test 10: serialize nested table
RESULT=$(send '"return {pos={x=1,y=2,z=3}, name=\"test\"}"' serialize)
check "serialize nested" "$(printf 'ok\n{"name":"test","pos":{"x":1,"y":2,"z":3}}')" "$RESULT"

# Test 11: serialize multiple return values -> JSON array
RESULT=$(send '"return 1, \"two\""' serialize)
check "serialize multi-return" "$(printf 'ok\n[1,"two"]')" "$RESULT"

# Test 12: serialize cyclic table -> circular reference becomes null
RESULT=$(send '"local t={}; t.self=t; return t"' serialize)
check "serialize cyclic" "$(printf 'ok\n{"self":null}')" "$RESULT"

# Test 13: serialize keeps error handling
RESULT=$(send '"error(\"boom\")"' serialize)
if echo "$RESULT" | head -1 | grep -q '^error$'; then
	echo "  PASS: serialize error handling"
	PASS_COUNT=$((PASS_COUNT + 1))
else
	echo "  FAIL: serialize error handling"
	echo "    got: $RESULT"
	FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo ""
echo "=== Results: $PASS_COUNT passed, $FAIL_COUNT failed ==="
[ "$FAIL_COUNT" -eq 0 ]
