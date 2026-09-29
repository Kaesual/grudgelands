#!/usr/bin/env bash
# Round 24 Lane A engine probe: dig matrix through core.get_dig_params,
# generated tier rock in three bands, the mining transaction and punch hints,
# and protection reasons. Boots one isolated headless server through
# tools/luanti_headless.sh with the disposable probe mod staged (never
# shipped), copies the server log to OUT_DIR, removes the run directory and
# exits 0 only on a clean boot plus "RESULT PASS".
#
# Usage: tools/r24_mining/run.sh OUT_DIR [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-240}"
mkdir -p "$out"
set +e
PROBE="$here/grug_probe_mining" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h 'r24_mining_probe\|\[grug_materials\]' "$out/server.log" 2>/dev/null |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r24 mining probe: PASS"
	exit 0
fi
echo "r24 mining probe: FAIL (boot status $boot)"
exit 1
