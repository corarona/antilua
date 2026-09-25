#!/bin/bash
# One-command AUTOMATED review pass for a Mineclonia PR:
# fetch + safe checkout + diff + smoke (random order) + luacheck.
#
# Usage: mcla_pr_review.sh <PR> [--smokes N] [--client] [--no-checkout]
#   --smokes N    number of server smokes (default 3)
#   --client      additionally boot a headless client on the PR's test world and
#                 leave it running for MCP-driven behavioral tests
#                 (pipe at $ANTILUA_PIPE_PATH; stop with mcla_pr_restore.sh)
#   --no-checkout skip checkout (use the already-checked-out branch)
#
# Always finish with mcla_pr_restore.sh.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/mcla_lib.sh"

PR="$1"; shift
SMOKES=3
CLIENT=0
CHECKOUT=1
while [ $# -gt 0 ]; do
	case "$1" in
		--smokes) SMOKES="$2"; shift ;;
		--client) CLIENT=1 ;;
		--no-checkout) CHECKOUT=0 ;;
		*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
	shift
done

"$SCRIPT_DIR/mcla_pr_fetch.sh" "$PR"
if [ "$CHECKOUT" = 1 ]; then
	"$SCRIPT_DIR/mcla_pr_checkout.sh" "$PR"
fi

echo "=== $(pr_title "$PR") ==="
echo "url: $PR_URL_BASE/$PR"
echo "=== diff stat vs main ==="
git -C "$GAME_DIR" diff main...pr/"$PR" --stat

"$SCRIPT_DIR/mcla_pr_smoke.sh" "$PR" "$SMOKES"

if [ "$CLIENT" = 1 ]; then
	"$SCRIPT_DIR/mcla_world_create.sh" "$PR"
	W="$(world_path "$PR")"
	CONFIG="$(mktemp /tmp/mcla_pipe_XXXX.conf)"
	review_config "$CONFIG"
	kill_clients
	cd "$REPO_ROOT"
	setsid xvfb-run -a ./bin/antilua --go --world "$W" --config "$CONFIG" \
		>/tmp/mcla_pr_${PR}_client.log 2>&1 < /dev/null &
	echo "headless client started for MCP testing (log: /tmp/mcla_pr_${PR}_client.log)"
	echo "wait for the FIFO:  for i in \$(seq 1 60); do [ -p $PIPE_PATH ] && break; sleep 2; done"
	echo "then drive it via the registered antilua MCP tools (or run_lua)."
fi

echo "=== done. run mcla_pr_restore.sh when finished ==="