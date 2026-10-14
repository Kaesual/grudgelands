#!/usr/bin/env bash
# Round 48 lane BAGS: the test of the migration step 0.48.0. First the step's
# unit tests (tools/r48_bags/test_step.py) in the platform runner's
# environment, then the end-to-end test (tools/r48_bags/e2e.py: a 0.47.0
# world built by the 0.47.0 game, the tool in the container, boots and
# joins of this checkout's game). The runner image is Round 43 IT's
# (tools/r43_it/Containerfile), built once. The join part's fixture is
# tools/r48_bags/portable_test.lua (tools/run_fixtures.sh).
#
# Usage: tools/r48_bags/run.sh [EVIDENCE_DIR]
#   Start it through the round's process queue (one slot). KEEP=1 keeps the
#   run directory. Exit 0 only when every test passed.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
image=localhost/grudgelands-r43-it:trixie
if ! podman image exists "$image"; then
	podman build -q -t "$image" -f "$repo/tools/r43_it/Containerfile" "$repo/tools/r43_it"
fi
podman run --rm --network=none --security-opt label=disable -e PYTHONDONTWRITEBYTECODE=1 \
	-v "$repo:$repo:ro" -w "$repo" "$image" sh -euc '
		python3 --version
		python3 -m unittest discover -s tools/r48_bags -p "test_*.py" -v'
exec python3 "$here/e2e.py" "${1:-$here/evidence}"
