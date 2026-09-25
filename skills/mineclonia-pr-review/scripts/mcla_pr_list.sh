#!/bin/bash
# List open Mineclonia PRs with metadata, optional filters.
#
# Usage:
#   mcla_pr_list.sh                       # all open, non-draft
#   mcla_pr_list.sh --small               # small diffs (<=3 files, <=50 lines)
#   mcla_pr_list.sh --draft               # include draft/WIP PRs
#   mcla_pr_list.sh --author NAME         # filter by author login
#   mcla_pr_list.sh --keyword WORD        # match title
#   mcla_pr_list.sh --min-rows N          # ignore PRs older than N rows (default 100)
#
# Output: <number>\t<title>\t<author>\t<files>\t<+/->\t<draft>
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./mcla_lib.sh
. "$SCRIPT_DIR/mcla_lib.sh"

SMALL=false
DRAFT=false
AUTHOR=""
KEYWORD=""
MIN_ROWS=100

while [ $# -gt 0 ]; do
	case "$1" in
		--small) SMALL=true ;;
		--draft) DRAFT=true ;;
		--author) AUTHOR="$2"; shift ;;
		--keyword) KEYWORD="$2"; shift ;;
		--min-rows) MIN_ROWS="$2"; shift ;;
		*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
	shift
done

# Fetch up to 2 pages of open PRs
curl -s "$API/pulls?state=open&limit=100&page=1" > /tmp/mcla_prs_p1.json
curl -s "$API/pulls?state=open&limit=100&page=2" > /tmp/mcla_prs_p2.json

jq -s 'add' /tmp/mcla_prs_p1.json /tmp/mcla_prs_p2.json |
	jq -r --argjson small "$SMALL" --argjson draft "$DRAFT" \
		--arg author "$AUTHOR" --arg kw "$KEYWORD" --argjson rows "$MIN_ROWS" '
		.[:$rows][]
		| select($draft or (.draft|not))
		| select($author == "" or .user.login == $author)
		| select($kw == "" or (.title | ascii_downcase | contains($kw | ascii_downcase)))
		| select($small == 0 or (.changed_files <= 3 and (.additions + .deletions) <= 50))
		| [.number, .title, .user.login, .changed_files, ("+" + (.additions|tostring) + "/-" + (.deletions|tostring)), (if .draft then "DRAFT" else "" end)]
		| @tsv'

rm -f /tmp/mcla_prs_p1.json /tmp/mcla_prs_p2.json