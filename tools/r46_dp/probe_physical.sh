#!/usr/bin/env bash
# Round 46 lane DP, step 1: the physical-flyer engine probe. Boots one isolated
# headless server through tools/luanti_headless.sh with the disposable probe
# mod grug_probe_r46_dp and prints its lines. Exit 0 on "RESULT DONE".
# Usage: tools/r46_dp/probe_physical.sh [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="$(PROBE="$here/grug_probe_r46_dp" KEEP=1 "$repo/tools/luanti_headless.sh" "${1:-120}" 2>&1 || true)"
echo "$out" | tail -n 5
root="$(echo "$out" | sed -n 's/^kept: //p' | tail -n 1)"
status=1
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	grep -h '\[r46_dp_probe\]' "$root"/server*.log || true
	grep -q 'RESULT DONE' "$root"/server*.log && status=0
	rm -rf "$root"
fi
exit "$status"
