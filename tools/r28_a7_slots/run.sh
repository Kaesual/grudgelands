#!/usr/bin/env bash
# Round 28 Lane A7 engine probe: class hand-slot rules, ability slots, arrows
# and the removed quiver item over the real registry, on a headless boot.
#
# The portable proof is portable_test.lua next to this file (LuaJIT).
#
# Usage: tools/r28_a7_slots/run.sh OUT_DIR [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-120}"
mkdir -p "$out"
set +e
PROBE="$here/grug_probe_r28_slots" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r28_slots_probe\]' "$out/server.log" 2>/dev/null |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r28 slots probe: PASS"
	exit 0
fi
echo "r28 slots probe: FAIL (boot status $boot)"
exit 1
