#!/usr/bin/env bash
# Round 25 Lane A engine probe: the Claim Stone core in a real world. Boots
# one isolated headless server through tools/luanti_headless.sh with the
# disposable probe mod staged (never shipped), then a second boot on the same
# world (persistence), copies the server logs to OUT_DIR, removes the run
# directory and exits 0 only on two clean boots with "RESULT PASS" each.
#
# Usage: tools/r25_claim_core/run.sh OUT_DIR [TIMEOUT_SECONDS]
#   The world seed is 4242424242 (SEED overrides it).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-240}"
seed="${SEED:-4242424242}"
mkdir -p "$out"
set +e
SEED="$seed" PROBE="$here/grug_probe_claims" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
boot2=1
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	set +e
	ROOT="$root" SEED="$seed" PROBE="$here/grug_probe_claims" \
		"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless2.txt" 2>&1
	boot2=$?
	set -e
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt" "$out/headless2.txt" 2>/dev/null || true
grep -h 'r25_claim_probe\|\[grug_housing\]' "$out/server.log" 2>/dev/null >"$out/probe.txt" || true
grep -h 'r25_claim_probe\|\[grug_housing\]' "$out/server.2.log" 2>/dev/null >"$out/probe2.txt" || true
cat "$out/probe.txt" "$out/probe2.txt"
if [[ $boot -eq 0 && $boot2 -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt" &&
		grep -q 'RESULT PASS' "$out/probe2.txt"; then
	echo "r25 claim probe: PASS"
	exit 0
fi
echo "r25 claim probe: FAIL (boot status $boot / $boot2)"
exit 1
