#!/usr/bin/env bash
# Round 69 lane CAMP: the test of the migration step 0.69.0 and the two-boot
# proof of the camp box rewrite (tools/r69_camp/e2e.py). The runner image is
# Round 43 IT's (tools/r43_it/Containerfile), built once; the step's own unit
# test runs in it first. The job's fixture is tools/r69_camp/portable_test.lua.
#
# Usage: tools/r69_camp/run.sh [EVIDENCE_DIR]
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
