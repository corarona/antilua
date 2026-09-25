#!/bin/bash
# Open the Codeberg PR page in the default browser.
#
# Usage: mcla_pr_open.sh <PR>
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/mcla_lib.sh"

URL="$PR_URL_BASE/$1"
if command -v xdg-open &>/dev/null; then
	xdg-open "$URL" >/dev/null 2>&1 &
elif command -v gio &>/dev/null; then
	gio open "$URL" >/dev/null 2>&1 &
elif command -v open &>/dev/null; then
	open "$URL" >/dev/null 2>&1 &
else
	echo "no browser opener found; URL: $URL"
	exit 1
fi
echo "opened: $URL"