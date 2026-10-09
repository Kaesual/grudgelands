#!/usr/bin/env bash
# Round 45 lane MS: the test of the migration step 0.45.0. First the step's
# unit tests (tools/r45_ms/test_step.py) in the platform runner's
# environment, then the end-to-end test (tools/r45_ms/e2e.py: a 0.44.0 world
# built by the 0.44.0 game, the shipped tool in the container, a boot and
# joins of this checkout's game). The runner image is Round 43 IT's
# (tools/r43_it/Containerfile: Debian trixie's python3 3.13, psycopg,
# zstandard), built once. The join part's fixture is
# tools/r45_ms/portable_test.lua (tools/run_fixtures.sh).
#
# Usage: tools/r45_ms/run.sh [EVIDENCE_DIR]
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
		python3 -m unittest discover -s tools/r45_ms -p "test_*.py" -v'
exec python3 "$here/e2e.py" "${1:-$here/evidence}"
