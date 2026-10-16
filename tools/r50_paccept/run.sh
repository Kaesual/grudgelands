#!/usr/bin/env bash
# Round 50 lane PACCEPT: the map-reset packing end to end (tools/r50_paccept/
# e2e.py, its header): a world built by the real 0.48.1 game, packed by this
# checkout's tool on SQLite and on PostgreSQL in the platform runner's image
# (tools/r43_it/Containerfile, built once), the map emptied and
# grug_reset_world raised as the platform does, then two boots of this
# checkout's 0.50.0 game per backend with joins.
#
# Usage: tools/r50_paccept/run.sh [EVIDENCE_DIR]   (default tools/r50_paccept/evidence)
#   OLD_GAME=<dir>  a checkout of 0.48.1 (1ef11b5e); default: the sibling
#                   worktree r50-v0481. Only its game and launcher are used.
#   FIXTURE=<dir>   also package the 0.48.1 world for the platform there.
#   KEEP=1          keep the run directory.
#   Start it through the round's process queue (one slot): every boot and
#   container run goes one after the other. Exit 0 only when every check passed.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
image=localhost/grudgelands-r43-it:trixie
if ! podman image exists "$image"; then
	podman build -q -t "$image" -f "$repo/tools/r43_it/Containerfile" "$repo/tools/r43_it"
fi
exec python3 "$here/e2e.py" "${1:-$here/evidence}"
