#!/usr/bin/env bash
# Round 25 Lane A2 engine probe: claim distance to settlements (ruling 27)
# and a road through a claim, on merged main with every housing mod. Boots
# one isolated headless server through tools/luanti_headless.sh (seed
# 4242424242) with the disposable probe mod staged (never shipped), copies
# the server log to OUT_DIR, removes the run directory and exits 0 only on a
# clean boot with "RESULT PASS".
#
# The portable side is tools/r25_claim_core/fixture.lua (LuaJIT).
#
# Usage: tools/r25_claim_distance/run.sh OUT_DIR [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-240}"
mkdir -p "$out"
set +e
SEED="${SEED:-4242424242}" PROBE="$here/grug_probe_claim_distance" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r25_distance_probe\]\|\[grug_housing\]' \
	"$out/server.log" 2>/dev/null | tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r25 claim distance probe: PASS"
	exit 0
fi
echo "r25 claim distance probe: FAIL (boot status $boot)"
exit 1
