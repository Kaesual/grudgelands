#!/usr/bin/env bash
# Lane A playtest-fix probe: food RMB click versus hold (ground, door, chest,
# NPC, nothing, combat), engine place repeats, eating feedback and cleanup,
# the bow draw range/stance end paths and the movement stance factor.
#
# Boots one isolated headless server through tools/luanti_headless.sh with the
# disposable probe mod staged (never shipped), copies the server log to
# OUT_DIR, removes the run directory and exits 0 only on "RESULT PASS".
#
# Usage: tools/pt_fixes/lane_a/run.sh OUT_DIR [TIMEOUT_SECONDS]
#   GAME_PATCH=<file> is forwarded (e.g. a reverse patch to show the failure
#   on an unfixed build).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-240}"
mkdir -p "$out"
set +e
PROBE="$here/grug_probe_food_input" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[food_input_probe\]' "$out/server.log" 2>/dev/null |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "food input probe: PASS"
	exit 0
fi
echo "food input probe: FAIL (boot status $boot)"
exit 1
