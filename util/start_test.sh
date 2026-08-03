#!/bin/bash -e
# Start Antilua integration tests.
# - If user is idle >10 min: runs headless via xvfb-run, parses results.
# - If user is active: launches game in background on workspace 11.
#
# Requires i3 (i3-msg), xprintidle for interactive mode.
#
# Usage:
#   ./util/start_test.sh               # uses worlds/test (mineclonia)
#   ./util/start_test.sh --world NAME   # use specific world

WORLD="${2:-test}"
BIN="./bin/antilua"

# Kill any existing Antilua process first
if pgrep -x "antilua" > /dev/null 2>&1; then
	echo "Killing existing Antilua process..."
	pkill -x "antilua" 2>/dev/null || true
	sleep 1
fi

# Ensure the world exists with mineclonia game
if [ ! -d "worlds/$WORLD" ]; then
	echo "Creating world $WORLD..."
	"$BIN" --info --world "worlds/$WORLD" --gamename mineclonia 2>&1 &
	sleep 2
	kill %1 2>/dev/null || true
	wait 2>/dev/null || true
fi

# Enable the integration tests (disabled by default during normal play)
CONFIG_FILE=$(mktemp)
cat > "$CONFIG_FILE" << 'ENDCONF'
al_test_enable = true
ENDCONF

IDLE_CHECKED=false
IDLE_MS=0
if command -v xprintidle &>/dev/null; then
	IDLE_MS=$(xprintidle 2>/dev/null || echo 0)
	IDLE_CHECKED=true
fi

if [ "$IDLE_CHECKED" = true ] && [ "$IDLE_MS" -gt 600000 ]; then
	# Headless mode — user is AFK
	echo "User AFK (idle ${IDLE_MS}ms). Running headless tests..."
	OUTFILE=$(mktemp)
	if command -v xvfb-run &>/dev/null; then
		xvfb-run --auto-servernum \
			timeout 60 \
			"$BIN" --info --world "worlds/$WORLD" \
			--go --config "$CONFIG_FILE" 2>&1 | tee "$OUTFILE" || true
	else
		timeout 60 \
			"$BIN" --info --world "worlds/$WORLD" \
			--go --config "$CONFIG_FILE" 2>&1 | tee "$OUTFILE" || true
	fi

	PASS=$(grep -c '\[AL_TEST\] PASS:' "$OUTFILE" || true)
	FAIL=$(grep -c '\[AL_TEST\] FAIL:' "$OUTFILE" || true)
	SKIP=$(grep -c '\[AL_TEST\] SKIP:' "$OUTFILE" || true)
	echo "Passed: $PASS  Failed: $FAIL  Skipped (not ported): $SKIP"

	if [ "$FAIL" -gt 0 ]; then
		echo "FAILING TESTS:"
		grep '\[AL_TEST\] FAIL:' "$OUTFILE" || true
	fi

	rm -f "$OUTFILE" "$CONFIG_FILE"
	[ "$FAIL" -eq 0 ]
	exit $?
fi

# Interactive mode — launch in background, detached from shell
echo "Starting Antilua (world: $WORLD)..."
LOGFILE="antilua-debug.txt"
nohup "$BIN" --info --worldname "$WORLD" --go --name test \
	--config "$CONFIG_FILE" > "$LOGFILE" 2>&1 &
disown

# Wait for window, then move to workspace 11
for i in $(seq 1 30); do
	sleep 0.5
	WID=$(wmctrl -l 2>/dev/null | grep -i "Luanti\|antilua" | head -1 | awk '{print $1}') || true
	if [ -n "$WID" ]; then
		i3-msg "[id=$WID] move workspace 11" 2>/dev/null || true
		echo "Moved to workspace 11"
		break
	fi
done
sleep 30
cat "$LOGFILE" 2>/dev/null | grep -v "ignoring unsupported\|template\.\(pot\|txt\)" | tail -50
echo ""
echo "Done. Full log in $LOGFILE"
