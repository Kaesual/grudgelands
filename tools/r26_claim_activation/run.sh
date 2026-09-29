#!/usr/bin/env bash
# Round 26 Lane S engine probe: Claim Stone drafts, activation, the 12 h
# pick-up lock, draft expiry, snow in the arrival cube, the Housing Steward
# and /claim_remove, end to end on seed 4242424242 (the eligible Accord spot
# of the Round 25 probes). Boots one isolated headless server through
# tools/luanti_headless.sh with the disposable probe mod staged (never
# shipped), copies the server log to OUT_DIR, removes the run directory and
# exits 0 only on a clean boot plus "RESULT PASS".
#
# The portable proofs are the Round 25 fixtures (tools/r25_claim_core,
# r25_interfaces, r25_home_stone, r25_interaction, r25_spawn_guard), extended
# for Round 26.
#
# Usage: tools/r26_claim_activation/run.sh OUT_DIR [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-290}"
mkdir -p "$out"
set +e
SEED="${SEED:-4242424242}" PROBE="$here/grug_probe_r26_claim_activation" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r26_claim_probe\]\|\[grug_housing\]' \
	"$out/server.log" 2>/dev/null | grep -v '^$' | tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r26 claim activation probe: PASS"
	exit 0
fi
echo "r26 claim activation probe: FAIL (boot status $boot)"
exit 1
