#!/bin/bash
# Shared helpers for the Mineclonia PR review scripts (source me).
# Override paths via env: ANTILUA_ROOT, MCLA_STATE_DIR.

set -euo pipefail

REPO_ROOT="${ANTILUA_ROOT:-/home/flyc0r/var/src/MT/antilua}"
GAME_DIR="$REPO_ROOT/games/mineclonia"
WORLDS_DIR="$REPO_ROOT/worlds"
DUMMY_WORLD="${MCLA_DUMMY_WORLD:-$HOME/var/src/MT/minetest/worlds/dummy_autoquit}"
API="https://codeberg.org/api/v1/repos/mineclonia/mineclonia"
PR_URL_BASE="https://codeberg.org/mineclonia/mineclonia/pulls"
PIPE_PATH="${ANTILUA_PIPE_PATH:-/tmp/antilua_lua}"
STATE_DIR="${MCLA_STATE_DIR:-/tmp/mcla_state}"

pr_json()   { curl -s "$API/pulls/$1"; }
pr_head_ref()   { pr_json "$1" | jq -r '.head.ref   // "refs/pull/'"$1"'/head"'; }
pr_head_label() { pr_json "$1" | jq -r '.head.label // "pr'"$1"'"'; }
pr_title()      { pr_json "$1" | jq -r '.title      // "PR '"$1"'"'; }
pr_draft()      { pr_json "$1" | jq -r '.draft // false'; }

sanitize() { printf '%s' "$1" | tr -c 'A-Za-z0-9_-' '_'; }
world_name() { printf 'mcla_test_pr_%s_%s' "$1" "$(sanitize "$(pr_head_label "$1")")"; }
world_path() { printf '%s/%s' "$WORLDS_DIR" "$(world_name "$1")"; }

ensure_state_dir() { mkdir -p "$STATE_DIR"; }
state_put() { ensure_state_dir; printf '%s\n' "$2" > "$STATE_DIR/$1"; }
state_get() { [ -f "$STATE_DIR/$1" ] && cat "$STATE_DIR/$1" || true; }

# Kill any running antilua clients (shared FIFO -> only one at a time).
kill_clients() {
	pkill -9 -f "bin/antilua" 2>/dev/null || true
	sleep 1
	rm -f "$PIPE_PATH"
}

is_pr_checked_out() {
	[ "$(git -C "$GAME_DIR" rev-parse --abbrev-ref HEAD)" = "pr/$1" ]
}

review_config() {
	# $1 = output config file path
	cat > "$1" << EOF
pipe_lua_enable = true
pipe_lua_path = $PIPE_PATH
random_mod_load_order = false
enable_minimap = true
EOF
}