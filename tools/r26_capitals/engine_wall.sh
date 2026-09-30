#!/usr/bin/env bash
# Round 27 wall-fix engine probe (grug_probe_r27w3_wall): the Gor Drazhak
# playtest spot and every gatehouse's towers on seed 7522774488337609340. Boots one
# isolated headless server through tools/luanti_headless.sh with the
# disposable probe mod staged (never shipped), copies the server log to
# OUT_DIR, removes the run directory and exits 0 only on a clean boot with
# "RESULT PASS". The portable side is gate_gaps.lua.
#
# Usage: tools/r26_capitals/engine_wall.sh OUT_DIR [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine_wall.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-280}"
mkdir -p "$out"
root="$(mktemp -d /tmp/grudgelands-headless.r27w3-XXXXXX)"
set +e
SEED="${SEED:-7522774488337609340}" PROBE="$here/grug_probe_r27w3_wall" ROOT="$root" \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.r27w3-?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r27w3_wall_probe\]\|ERROR' "$out"/server*.log 2>/dev/null | tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r27w3 wall probe: PASS"
	exit 0
fi
echo "r27w3 wall probe: FAIL (boot status $boot)"
exit 1
