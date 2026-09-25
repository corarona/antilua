#!/bin/bash
# Create (idempotently) the per-PR test world: worlds/mcla_test_pr_<PR>_<head.label>
#
# Usage: mcla_world_create.sh <PR>
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/mcla_lib.sh"

PR="$1"
W="$(world_path "$PR")"
NAME="$(world_name "$PR")"

if [ -f "$W/world.mt" ]; then
	echo "world exists: $W"
	exit 0
fi

mkdir -p "$W"
cat > "$W/world.mt" << EOF
enable_damage = false
creative_mode = false
mod_storage_backend = sqlite3
auth_backend = sqlite3
player_backend = sqlite3
backend = sqlite3
gameid = mineclonia
world_name = $NAME
default_privs = interact, shout, give, settime, teleport, fast, fly, noclip
EOF
echo "created test world: $W"
echo "note: the map is generated on first launch"