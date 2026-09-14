#!/usr/bin/env bash
# The two WP13 engine runs of the Silverleaf increment, exactly as they were
# invoked. One seed per invocation, never both at once: four lanes share this
# workstation, so the caller waits until fewer than four headless servers are
# running before each call, and the runner's own output directory lives
# OUTSIDE the repository (the launcher mounts the repository read-only) and is
# copied into the evidence afterwards.
#
#   bash tools/wp13/evidence/20260914-silverleaf/engine.sh user      531802985935182545 32600
#   bash tools/wp13/evidence/20260914-silverleaf/engine.sh boundary  8675309            32640
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
label="${1:?usage: engine.sh LABEL SEED PORT_BASE}"
seed="${2:?}"
port="${3:?}"
out="/tmp/grug-wp13-silverleaf-$label-$$"

running="$(pgrep -c -f '^luanti.bin --server' || true)"
if [ "${running:-0}" -ge 4 ]; then
	echo "engine.sh: $running headless servers already running; refusing" >&2
	exit 3
fi

WP13_SEED="$seed" WP13_PORT_BASE="$port" WP40_PROFILE_TIMEOUT=540 \
	timeout --kill-after=30 600 \
	bash tools/wp13/run_engine.sh "$out" \
	tools/wp13/evidence/20260914-silverleaf/luanti-flatpak-launcher.sh
status=$?
echo "engine.sh: $label exit $status, output $out"
exit "$status"
