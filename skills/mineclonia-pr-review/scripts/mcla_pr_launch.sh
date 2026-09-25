#!/bin/bash
# Launch the game INTERACTIVELY on the PR branch for manual testing.
# - checks out pr/<PR> (safe: uses mcla_pr_checkout.sh),
# - creates worlds/mcla_test_pr_<PR>_<head.label> if missing,
# - starts ./bin/antilua --go on the user's display with the MCP Lua pipe enabled.
#
# Usage: mcla_pr_launch.sh <PR> [--workspace N] [--headless]
#   --workspace N  also move the window to i3 workspace N (default: leave where it opens)
#   --headless     run via xvfb instead of the real display (screenshot/MCP without a window)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/mcla_lib.sh"

PR="$1"; shift
WS=""
HEADLESS=0
while [ $# -gt 0 ]; do
	case "$1" in
		--workspace) WS="$2"; shift ;;
		--headless) HEADLESS=1 ;;
		*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
	shift
done

"$SCRIPT_DIR/mcla_pr_fetch.sh" "$PR"
"$SCRIPT_DIR/mcla_pr_checkout.sh" "$PR"
"$SCRIPT_DIR/mcla_world_create.sh" "$PR"
W="$(world_path "$PR")"

CONFIG="$(mktemp /tmp/mcla_pipe_XXXX.conf)"
review_config "$CONFIG"

kill_clients

cd "$REPO_ROOT"
echo "branch:    pr/$PR ($(cd "$GAME_DIR" && git log --oneline -1 pr/$PR | cut -c1-60))"
echo "world:     $W"
echo "url:       $PR_URL_BASE/$PR"
echo "pipe:      $PIPE_PATH (ANTILUA_PIPE_PATH)"
echo "config:    $CONFIG"

if [ "$HEADLESS" = 1 ]; then
	setsid xvfb-run -a ./bin/antilua --go --world "$W" --config "$CONFIG" \
		>/tmp/mcla_pr_${PR}_launch.log 2>&1 < /dev/null &
	echo "headless client started (log: /tmp/mcla_pr_${PR}_launch.log)"
else
	setsid ./bin/antilua --go --world "$W" --config "$CONFIG" \
		>/tmp/mcla_pr_${PR}_launch.log 2>&1 < /dev/null &
	echo "interactive client started (log: /tmp/mcla_pr_${PR}_launch.log)"
fi

if [ -n "$WS" ] && command -v i3-msg &>/dev/null; then
	(
		sleep 4
		i3-msg "[class=\"(?i)antilua|luanti\"] move container to workspace $WS"
	) >/dev/null 2>&1 &
fi

echo "Restore the working tree with:  mcla_pr_restore.sh"