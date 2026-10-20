#!/usr/bin/env bash
# Round 53 lane INTEG: the test of the migration step 0.53.0. First the step's
# unit tests (tools/r53_ms/test_step.py) in the platform runner's
# environment, then the end-to-end test (tools/r53_ms/e2e.py: a 0.52.1
# world built by the 0.52.1 game, the tool in the container, boots and
# joins of this checkout's game). The runner image is Round 43 IT's
# (tools/r43_it/Containerfile), built once. The join part's fixture is
# tools/r53_ms/portable_test.lua (tools/run_fixtures.sh).
#
# Usage: tools/r53_ms/run.sh [EVIDENCE_DIR]
#   Start it through the round's process queue (one slot). KEEP=1 keeps the
#   run directory; GUI_WORLD=<dir> keeps a copy of the 0.52.1 world there for
#   the GUI test (e2e.py). Exit 0 only when every test passed.
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
		python3 -m unittest discover -s tools/r53_ms -p "test_*.py" -v'
exec python3 "$here/e2e.py" "${1:-$here/evidence}"
