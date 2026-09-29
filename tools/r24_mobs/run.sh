#!/usr/bin/env bash
# Round 24 Lane D engine probe: start-zone spawn levels on the installed zone
# authority, calm roaming versus 4.0 combat speed of the ranged families, and
# the idle wander leash, on the real mobs_redo AI.
#
# Boots one isolated headless server through tools/luanti_headless.sh with the
# disposable probe mod staged (never shipped), copies the server log to
# OUT_DIR, removes the run directory and exits 0 only on "RESULT PASS".
#
# Usage: tools/r24_mobs/run.sh OUT_DIR [TIMEOUT_SECONDS]
#   SEED=<unsigned decimal> is forwarded (4242424242 matches the portable
#   levels fixture's first seed).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-300}"
mkdir -p "$out"
set +e
PROBE="$here/grug_probe_r24_mobs" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r24_mobs_probe\]' "$out/server.log" 2>/dev/null |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r24 mobs probe: PASS"
	exit 0
fi
echo "r24 mobs probe: FAIL (boot status $boot)"
exit 1
