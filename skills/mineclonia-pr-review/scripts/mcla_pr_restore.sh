#!/bin/bash
# Restore the pre-review state: kill any running client, return to the branch
# that was active before checkout, and restore backed-up WIP changes.
#
# Usage: mcla_pr_restore.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/mcla_lib.sh"

kill_clients

cd "$GAME_DIR"
CUR=$(state_get cur_branch)
if [ -n "$CUR" ] && [ "$(git rev-parse --abbrev-ref HEAD)" != "$CUR" ]; then
	git checkout "$CUR"
	echo "restored branch: $CUR"
fi

BACKUP="$STATE_DIR/wip_backup"
if [ -d "$BACKUP" ]; then
	if [ -s "$BACKUP/staged.patch" ]; then
		git apply --cached "$BACKUP/staged.patch" && echo "restored staged changes" || echo "WARN: staged.patch did not apply cleanly"
	fi
	if [ -s "$BACKUP/diff.patch" ]; then
		git apply "$BACKUP/diff.patch" && echo "restored working-tree changes" || echo "WARN: diff.patch did not apply cleanly"
	fi
	rm -rf "$BACKUP"
fi

git status --porcelain | grep -v '^??' | sed 's/^/  /' || echo "working tree clean"
echo "restore complete"