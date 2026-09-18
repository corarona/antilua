#!/bin/bash -e
# Run Antilua integration tests headlessly
# Requires xvfb-run (from xvfb package) or Xephyr
#
# Usage:
#   ./util/ci/run_al_tests.sh               # devtest full suite + mineclonia railbot pass
#   ./util/ci/run_al_tests.sh --world NAME  # use specific devtest world
#   AL_TEST_SKIP_MCL=1                      # skip the mineclonia pass

WORLD="${2:-test_df}"
MCL_WORLD="test_mcl"
MCL_TIMEOUT=420

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

OUT_DEV=$(mktemp)
OUT_MCL=$(mktemp)
cleanup() {
	rm -f "$OUT_DEV" "$OUT_MCL"
}
trap cleanup EXIT

# Run one client pass and capture the log.
# run_client <world> <gameid> <timeout> <extra config line> <outfile>
run_client() {
	local world="$1" gameid="$2" timeout_s="$3" extra_conf="$4" outfile="$5"

	# Create the world if it does not exist yet (the client does not take a
	# --gameid for world creation; a world.mt with the gameid is enough —
	# the engine creates the rest on first run).
	if [ ! -f "worlds/$world/world.mt" ]; then
		mkdir -p "worlds/$world"
		{
			echo "enable_damage = true"
			echo "creative_mode = false"
			echo "mod_storage_backend = sqlite3"
			echo "auth_backend = sqlite3"
			echo "player_backend = sqlite3"
			echo "backend = sqlite3"
			echo "gameid = $gameid"
			echo "world_name = $world"
			echo "default_privs = interact, shout, give, settime, teleport, fast, fly, noclip"
		} > "worlds/$world/world.mt"
	fi

	local conf
	conf=$(mktemp)
	{
		echo "al_test_enable = true"
		[ -n "$extra_conf" ] && echo "$extra_conf"
	} > "$conf"

	if command -v xvfb-run &>/dev/null; then
		xvfb-run --auto-servernum \
			timeout "$timeout_s" \
			./bin/antilua --info --world "worlds/$world" \
			--go --config "$conf" 2>&1 | tee "$outfile" || true
	else
		timeout "$timeout_s" \
			./bin/antilua --info --world "worlds/$world" \
			--go --config "$conf" 2>&1 | tee "$outfile" || true
	fi
	rm -f "$conf"
}

# Parse one pass's log; echoes the summary, exits non-zero on failure.
parse_results() {
	local pass fail skip
	pass=$(grep -c '\[AL_TEST\] PASS:' "$1" || true)
	fail=$(grep -c '\[AL_TEST\] FAIL:' "$1" || true)
	skip=$(grep -c '\[AL_TEST\] SKIP:' "$1" || true)

	if [ "$pass" -eq 0 ] && [ "$fail" -eq 0 ]; then
		echo "ERROR: No tests ran (is al_test_enable still wired up?)"
		exit 1
	fi

	echo "Passed: $pass  Failed: $fail  Skipped (not ported): $skip"
	if [ "$fail" -gt 0 ]; then
		echo "FAILING TESTS:"
		grep '\[AL_TEST\] FAIL:' "$1" || true
		echo ""
		return 1
	fi
	return 0
}

echo "=== Antilua Integration Tests ==="

echo ""
echo "--- Pass 1: devtest (full suite, world: $WORLD) ---"
run_client "$WORLD" devtest 60 "" "$OUT_DEV"
DEV_FAIL=0
parse_results "$OUT_DEV" || DEV_FAIL=1

MCL_FAIL=0
if [ "${AL_TEST_SKIP_MCL:-0}" != "1" ]; then
	echo ""
	echo "--- Pass 2: mineclonia (railbot group, world: $MCL_WORLD) ---"
	run_client "$MCL_WORLD" mineclonia "$MCL_TIMEOUT" \
		"al_test_group = railbot" "$OUT_MCL"
	parse_results "$OUT_MCL" || MCL_FAIL=1
else
	echo ""
	echo "--- Pass 2 (mineclonia) skipped via AL_TEST_SKIP_MCL=1 ---"
fi

# Non-zero if either pass failed
[ "$DEV_FAIL" -eq 0 ] && [ "$MCL_FAIL" -eq 0 ]
