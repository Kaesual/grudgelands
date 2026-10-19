#!/usr/bin/env bash
# Round 51 follow-up lane FM: fish in land lakes and the capitals' lakes, one engine
# run with the disposable probe grug_probe_r51_lakes (its header: the
# capitals' water and its spawn gates, wild lakes, stand-in players, the
# spawns and a census per lake). Boots one isolated headless server through
# tools/luanti_headless.sh (mob spawning on, as shipped), copies the server
# log to OUT_DIR, removes the run directory and exits 0 only on
# "RESULT PASS". Run it through the shared Lua queue (one boot).
#
# Usage: tools/r51_mobs/lakes.sh OUT_DIR [TIMEOUT_SECONDS]
#   SEED (default the user's production seed 3464175725660475642)
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: lakes.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-300}"
mkdir -p "$out"
set +e
SEED="${SEED:-3464175725660475642}" PROBE="$here/grug_probe_r51_lakes" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r51lakes\]' "$out/server.log" 2>/dev/null | tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r51 lakes probe: PASS"
	exit 0
fi
echo "r51 lakes probe: FAIL (boot status $boot)"
exit 1
