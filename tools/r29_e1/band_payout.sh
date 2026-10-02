#!/usr/bin/env bash
# Round 29 Lane E1: per-band median kill payout (economy-vendor-plan.md §3.2)
# from the real resolved vendor payouts, plus a short payout list.
#
# Boots one isolated headless server through tools/luanti_headless.sh with
# the disposable probe mod grug_probe_r29_e1 staged (never shipped), prints
# the probe lines and the server's ERROR/WARNING lines, removes the run
# directory and exits 0 only on "RESULT PASS" and a clean boot.
#
# Usage: LC_ALL=C tools/r29_e1/band_payout.sh [OUT_DIR] [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:-$(mktemp -d)}"
timeout_s="${2:-120}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
set +e
PROBE="$here/grug_probe_r29_e1" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h 'ERROR\|WARNING' "$out"/server*.log 2>/dev/null | sort -u || true
grep -h '\[r29_e1_probe\]' "$out/server.log" 2>/dev/null | sed 's/^.*\[r29_e1_probe\] //' |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r29 e1 band payout: PASS"
	exit 0
fi
echo "r29 e1 band payout: FAIL (boot status $boot)"
exit 1
