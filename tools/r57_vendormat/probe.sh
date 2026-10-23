#!/usr/bin/env bash
# Round 57 VENDORMAT: one isolated headless boot with the disposable probe
# mod grug_probe_r57_vendormat staged (never shipped). Prints the probe lines
# and the server's ERROR/WARNING lines, removes the run directory and exits
# 0 only on "RESULT PASS" and a clean boot.
#
# Usage: LC_ALL=C tools/r57_vendormat/probe.sh [OUT_DIR] [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:-$(mktemp -d)}"
timeout_s="${2:-120}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
set +e
PROBE="$here/grug_probe_r57_vendormat" KEEP=1 \
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
grep -h '\[r57_vendormat_probe\]' "$out/server.log" 2>/dev/null |
	sed 's/^.*\[r57_vendormat_probe\] //' | tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r57 vendormat probe: PASS"
	exit 0
fi
echo "r57 vendormat probe: FAIL (boot status $boot)"
exit 1
