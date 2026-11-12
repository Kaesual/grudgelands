#!/usr/bin/env bash
# Round 78 lane TAGS engine run (grug_probe_r78_tags, staged into a throwaway
# game copy, never shipped; its header says what it asks): one isolated
# headless boot through tools/luanti_headless.sh that is also the lane's smoke
# boot, the probe's lines copied to OUT_DIR, the run directory removed. Exits
# 0 only on a clean boot and "RESULT PASS". Run it through the shared Lua
# queue (one boot).
#
# Usage: tools/r78_tags/run.sh OUT_DIR [TIMEOUT_SECONDS]
#   SEED (default 42).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-240}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
set +e
SEED="${SEED:-42}" PROBE="$here/grug_probe_r78_tags" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r78tags\]' "$out/server.log" 2>/dev/null | tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r78 tags probe: PASS"
	exit 0
fi
echo "r78 tags probe: FAIL (boot status $boot)"
exit 1
