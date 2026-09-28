#!/usr/bin/env bash
# Lane C probe (playtest fix round): water swimmers (Reed Angelfish, Kraken)
# never occupy a non-water node near varied shores over a long run, displaced
# fish return to water or flop in place, a killed Reed Angelfish drops exactly
# one raw fish, and the fishing rod carries its first-person wield image while
# the attached third-person wield entity keeps the original image.
#
# Boots one isolated headless server through tools/luanti_headless.sh with the
# disposable probe mod staged (never shipped), copies the server log to
# OUT_DIR, removes the run directory and exits 0 only on "RESULT PASS".
#
# Usage: tools/pt_fixes/lane_c/run.sh OUT_DIR [TIMEOUT_SECONDS]
#   GAME_PATCH=<file> is forwarded (e.g. a reverse patch to show the failure
#   on an unfixed build).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-480}"
mkdir -p "$out"
set +e
PROBE="$here/grug_probe_swimmers" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[swimmer_probe\]' "$out/server.log" 2>/dev/null |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "swimmer probe: PASS"
	exit 0
fi
echo "swimmer probe: FAIL (boot status $boot)"
exit 1
