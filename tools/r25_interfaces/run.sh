#!/usr/bin/env bash
# Round 25 Lane C engine probe: end to end with the real claim core (Lane A)
# and home stone (Lane D) on seed 4242424242 (Lane A's eligible spot): the
# Manager sockets of the six capitals, stone issued at level 20, placed,
# fuelled through the stone form, a permission added, Set as home, the
# Character status line, pick up.
#
# The portable proof is portable_test.lua next to this file (LuaJIT).
#
# Usage: tools/r25_interfaces/run.sh OUT_DIR [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-290}"
mkdir -p "$out"
set +e
SEED="${SEED:-4242424242}" PROBE="$here/grug_probe_r25_interfaces" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r25_interfaces_probe\]\|\[grug_housing\]' \
	"$out/server.log" 2>/dev/null | grep -v '^$' | tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r25 interfaces probe: PASS"
	exit 0
fi
echo "r25 interfaces probe: FAIL (boot status $boot)"
exit 1
