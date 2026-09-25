#!/bin/bash
# Safely check out pr/<PR> in games/mineclonia.
# Uncommitted tracked modifications are backed up to $MCLA_STATE_DIR/wip_backup/
# and restored by mcla_pr_restore.sh. Untracked files are left alone.
#
# Usage: mcla_pr_checkout.sh <PR>
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/mcla_lib.sh"

PR="$1"
cd "$GAME_DIR"

if is_pr_checked_out "$PR"; then
	echo "already on pr/$PR"
	exit 0
fi

CUR=$(git rev-parse --abbrev-ref HEAD)
state_put cur_branch "$CUR"
echo "current branch: $CUR"

# Back up any uncommitted tracked modifications (staged + unstaged)
DIRTY=$(git status --porcelain | grep -v '^??' || true)
if [ -n "$DIRTY" ]; then
	BACKUP="$STATE_DIR/wip_backup"
	rm -rf "$BACKUP"
	mkdir -p "$BACKUP"
	git diff --binary > "$BACKUP/diff.patch"
	git diff --cached --binary > "$BACKUP/staged.patch"
	# Record file list for verification on restore
	git status --porcelain | grep -v '^??' | sed 's/^...//' | sort -u > "$BACKUP/files.txt"
	echo "Uncommitted tracked changes backed up to $BACKUP:"
	cat "$BACKUP/files.txt"
	# Clean the tree so the checkout succeeds
	git restore --staged --worktree -- . 2>/dev/null || git checkout -- . 2>/dev/null || true
	echo "working tree cleaned for checkout"
fi

git checkout pr/"$PR"
echo "checked out pr/$PR — restore with mcla_pr_restore.sh"