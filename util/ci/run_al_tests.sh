#!/bin/bash -e
# Run Antilua integration tests headlessly
# Requires xvfb-run (from xvfb package) or Xephyr
#
# Usage:
#   ./util/ci/run_al_tests.sh               # run with default world
#   ./util/ci/run_al_tests.sh --world NAME   # use specific world

WORLD="${2:-test_df}"

# Find virtual display tool
if command -v xvfb-run &>/dev/null; then
	VIRT_DISPLAY="xvfb-run --auto-servernum"
elif command -v Xvfb &>/dev/null; then
	VIRT_DISPLAY="Xvfb :99 -screen 0 1024x768x24 &"
	export DISPLAY=:99
	cleanup() { kill %1 2>/dev/null || true; }
	trap cleanup EXIT
else
	echo "ERROR: Need xvfb-run or Xvfb for headless testing"
	exit 1
fi

echo "=== Antilua Integration Tests ==="
echo "World: $WORLD"

# Create/ensure the world exists with devtest game
if [ ! -d "worlds/$WORLD" ]; then
	./bin/antilua --info --world "worlds/$WORLD" --gamename devtest 2>&1 &
	sleep 2
	kill %1 2>/dev/null || true
	wait 2>/dev/null || true
fi

# Run the client with the test world and capture output
# The client exits on ESC or window close; we give it 60 seconds.
OUTFILE=$(mktemp)
CONFIG_FILE=$(mktemp)
cleanup() {
	rm -f "$OUTFILE" "$CONFIG_FILE"
}
trap cleanup EXIT

# Enable the integration tests (disabled by default during normal play)
cat > "$CONFIG_FILE" << 'ENDCONF'
al_test_enable = true
ENDCONF

echo "Output: $OUTFILE"

if command -v xvfb-run &>/dev/null; then
	xvfb-run --auto-servernum \
		timeout 60 \
		./bin/antilua --info --world "worlds/$WORLD" \
		--go --config "$CONFIG_FILE" 2>&1 | tee "$OUTFILE" || true
else
	timeout 60 \
		./bin/antilua --info --world "worlds/$WORLD" \
		--go --config "$CONFIG_FILE" 2>&1 | tee "$OUTFILE" || true
fi

echo "=== Test Results ==="

# Parse results from log output
PASS=$(grep -c '\[AL_TEST\] PASS:' "$OUTFILE" || true)
FAIL=$(grep -c '\[AL_TEST\] FAIL:' "$OUTFILE" || true)
SKIP=$(grep -c '\[AL_TEST\] SKIP:' "$OUTFILE" || true)
KNOWN=$(grep -c '\[AL_TEST\] PASS (unexpected):' "$OUTFILE" || true)

# Fail loudly if no tests ran (e.g. al_test_enable got lost)
if [ "$PASS" -eq 0 ] && [ "$FAIL" -eq 0 ]; then
	echo "ERROR: No tests ran. Is al_test_enable=true still wired up?"
	exit 1
fi

echo "Passed: $PASS  Failed: $FAIL  Skipped (not ported): $SKIP"
echo ""

if [ "$FAIL" -gt 0 ]; then
	echo "FAILING TESTS:"
	grep '\[AL_TEST\] FAIL:' "$OUTFILE" || true
	echo ""
fi

rm -f "$OUTFILE" "$CONFIG_FILE"

# Exit with non-zero if any test failed
[ "$FAIL" -eq 0 ]
