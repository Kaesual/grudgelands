#!/usr/bin/env bash
# Round 89 lane REWRITE: the test of the migration step 0.89.0 and the
# two-boot proof of the arena halls' box rewrite (tools/r89_rewrite/e2e.py).
# "Old" is the game at a commit (OLD, default the round's base at 0.88.0),
# "new" a copy of this working tree; TEST_TEMPLATES=1 swaps test-only hall
# templates into that copy (before the real ones exist). The runner image is
# Round 43 IT's (tools/r43_it/Containerfile), built once. The job's fixture
# is tools/r89_rewrite/portable_test.lua.
#
# Usage: [OLD=<commit>] [TEST_TEMPLATES=1] tools/r89_rewrite/run.sh [EVIDENCE_DIR]
#   Start it through the round's process queue (one slot). KEEP=1 keeps the
#   run directory. Exit 0 only when every check passed.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
image=localhost/grudgelands-r43-it:trixie
if ! podman image exists "$image"; then
	podman build -q -t "$image" -f "$repo/tools/r43_it/Containerfile" "$repo/tools/r43_it"
fi
exec python3 "$here/e2e.py" "${1:-$here/evidence}"
