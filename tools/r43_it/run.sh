#!/usr/bin/env bash
# Round 43 lane IT: the world-migration path end to end (tool, start guard,
# online work, map reset, PostgreSQL). The entry script: builds the runner
# image once (tools/r43_it/Containerfile: Debian trixie's python3, psycopg,
# zstandard and PostgreSQL; network for apt only then), then runs it.py,
# which prints the PASS/FAIL table and writes it with the trimmed evidence
# to EVIDENCE_DIR (default tools/r43_it/evidence). Engine boots go through
# tools/luanti_headless.sh, one at a time; the tool and the PostgreSQL test
# run in the container, one at a time and never beside a boot.
#
# Usage: tools/r43_it/run.sh [EVIDENCE_DIR]
#   Start it through the round's process queue (one slot). KEEP=1 keeps the
#   run directory. Exit 0 only when every check passed.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
image=localhost/grudgelands-r43-it:trixie
if ! podman image exists "$image"; then
	podman build -q -t "$image" -f "$here/Containerfile" "$here"
fi
exec python3 "$here/it.py" "${1:-$here/evidence}"
