#!/usr/bin/env bash
# Round 25 Lane G engine probe (ruling 24): with a probe-faked active housing
# claim in Moonfall Wood at night, no hostile mob spawns inside it while
# spawns continue outside; then the same claim unfuelled (informational).
#
# Boots one isolated headless server through tools/luanti_headless.sh (run
# directory /tmp/grudgelands-headless.r25-lane-g-*, removed afterwards) with
# the disposable probe mod and the Round 24 probe-player shim staged (never
# shipped). Copies the server log and the probe lines to OUT_DIR and exits 0
# only on "RESULT PASS".
#
# Usage: tools/r25_spawn_guard/run.sh OUT_DIR [TIMEOUT_SECONDS]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-300}"
mkdir -p "$out"
root="$(mktemp -d /tmp/grudgelands-headless.r25-lane-g-XXXXXX)"
trap 'rm -rf "$root"' EXIT
set +e
SEED=4242424242 ROOT="$root" PROBE="$here/grug_probe_r25_spawn_guard" \
	GAME_PATCH="$repo/tools/r24_density_xp/probe_player_shim.patch" \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
cp "$root"/server*.log "$out/" 2>/dev/null || true
cat "$out/headless.txt"
grep -h '\[r25_spawn_guard_probe\]' "$out/server.log" 2>/dev/null |
	tee "$out/probe.txt" || true
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r25 spawn guard probe: PASS"
	exit 0
fi
echo "r25 spawn guard probe: FAIL (boot status $boot)"
exit 1
