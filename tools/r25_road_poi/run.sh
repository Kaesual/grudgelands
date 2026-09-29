#!/usr/bin/env bash
# Round 25 Lane E engine probe (rulings 15-17): digging and placing across a
# real road corridor, at its +-5 limits, on a bridge and at a village core's
# faces, with the hint lines. Boots one isolated headless server through
# tools/luanti_headless.sh with the disposable probe mod staged (never
# shipped), copies the server log to OUT_DIR, removes the run directory and
# exits 0 only on a clean boot plus "RESULT PASS".
#
# Usage: tools/r25_road_poi/run.sh OUT_DIR [TIMEOUT_SECONDS]
#   SEED=<unsigned decimal> is forwarded to the launcher.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-300}"
mkdir -p "$out"
# The run directory carries this lane's prefix (the launcher requires the
# /tmp/grudgelands-headless.* form for a supplied ROOT).
root="$(mktemp -d /tmp/grudgelands-headless.r25-lane-e-XXXXXX)"
set +e
PROBE="$here/grug_probe_road_poi" ROOT="$root" \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h 'r25_road_poi_probe' "$out/server.log" 2>/dev/null |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r25 road poi probe: PASS"
	exit 0
fi
echo "r25 road poi probe: FAIL (boot status $boot)"
exit 1
