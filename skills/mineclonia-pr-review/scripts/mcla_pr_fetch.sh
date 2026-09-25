#!/bin/bash
# Refresh origin/main and fetch PR head refs into games/mineclonia.
#
# Usage: mcla_pr_fetch.sh <PR> [<PR> ...]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/mcla_lib.sh"

cd "$GAME_DIR"
git fetch origin main:main
for pr in "$@"; do
	# + forces the update and --update-head-ok allows it when pr/<N> is
	# the checked-out branch (review flow checks it out)
	git fetch --update-head-ok origin "+refs/pull/$pr/head:pr/$pr"
	echo "fetched pr/$pr -> $(git log --oneline -1 pr/$pr | cut -c1-60)"
done