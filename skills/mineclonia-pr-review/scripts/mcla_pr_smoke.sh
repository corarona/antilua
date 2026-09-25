#!/bin/bash
# Server smoke tests (random mod load order) + luacheck of changed files.
# Expects the PR branch to already be checked out (mcla_pr_checkout.sh).
#
# Usage: mcla_pr_smoke.sh <PR> [N]     # N = number of smokes (default 3)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/mcla_lib.sh"

PR="$1"
N="${2:-3}"

cd "$REPO_ROOT"
if [ ! -x ./bin/antilua ]; then
	echo "ERROR: no ./bin/antilua build — build first (cmake --build build -j3)" >&2
	exit 1
fi
if [ ! -d "$DUMMY_WORLD" ]; then
	echo "ERROR: dummy world not found: $DUMMY_WORLD (set MCLA_DUMMY_WORLD)" >&2
	exit 1
fi

pass=0
for i in $(seq 1 "$N"); do
	out=$(timeout 120 ./bin/antilua --server --world "$DUMMY_WORLD" 2>&1 || true)
	if echo "$out" | grep -q "SERVER SUCCESSFULLY STARTED"; then
		echo "smoke $i/$N: PASS"
		pass=$((pass + 1))
	else
		echo "smoke $i/$N: FAIL"
		echo "$out" | grep -E "ModError|LuaError|attempt to index|ERROR\[|stack traceback" | head -3
	fi
done
echo "smoke: $pass/$N passed (any FAIL under random load order = Critical, flaky = broken)"

echo "--- luacheck changed files ---"
cd "$GAME_DIR"
files=$(git diff main...pr/$PR --name-only -- '*.lua' || true)
if [ -n "$files" ]; then
	luacheck -q $files 2>&1 | tail -2 || true
else
	echo "no .lua files changed"
fi