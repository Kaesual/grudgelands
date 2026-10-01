#!/usr/bin/env bash
# Round 28 Lane B1 engine probe: a sample spawn-areas file for Dawnmere Fields
# (existing mobs only, grug_probe_r28_b1/elandor_dawnmere_fields.spawns.json)
# observed by day and night at four stationary probe points, plus the cost of
# the protection query, the policy in a fallback zone and one area attempt.
#
# Boots one isolated headless server through tools/luanti_headless.sh with the
# disposable probe mod staged (never shipped) and the Round 24 probe-player
# shim (tools/r24_density_xp/probe_player_shim.patch) as a disposable game
# patch, so mobs_redo counts the probe points as players in range.
# The portable proof is portable_test.lua next to this file (LuaJIT).
#
# Usage: tools/r28_b1/run.sh OUT_DIR [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-290}"
mkdir -p "$out"
set +e
SEED=4242424242 PROBE="$here/grug_probe_r28_b1" \
	GAME_PATCH="$repo/tools/r24_density_xp/probe_player_shim.patch" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r28_b1_probe\]' "$out/server.log" 2>/dev/null >"$out/probe.txt" || true
cat "$out/probe.txt"
if grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r28 b1 probe: PASS (boot status $boot)"
	exit 0
fi
echo "r28 b1 probe: FAIL (boot status $boot)"
exit 1
