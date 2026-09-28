#!/usr/bin/env bash
# Lane B playtest-fix probe: server crosshair overlay states (hostile per skill
# range incl. a talent bonus, friendly heal, self skill, interact within and
# beyond hand reach, precedence, packets only on change, integer scale), bow
# draw time with Fletching, the draw damage curve and arrow speed on real
# releases (homing flight time, Longshot beyond 25 m), the draw ring frames
# and its removal on every end path, the shared ring's single owner (bow or
# food), and the per-pass cost.
#
# Boots one isolated headless server through tools/luanti_headless.sh with the
# disposable probe mod staged (never shipped), copies the server log to
# OUT_DIR, removes the run directory and exits 0 only on "RESULT PASS".
#
# Usage: tools/pt_fixes/lane_b/run.sh OUT_DIR [TIMEOUT_SECONDS]
#   GAME_PATCH=<file> is forwarded.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-240}"
mkdir -p "$out"
set +e
PROBE="$here/grug_probe_crosshair" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[crosshair_probe\]' "$out/server.log" 2>/dev/null |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "crosshair probe: PASS"
	exit 0
fi
echo "crosshair probe: FAIL (boot status $boot)"
exit 1
