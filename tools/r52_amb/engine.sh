#!/usr/bin/env bash
# Round 52 lane AMB engine probe (grug_probe_r52_amb, staged into a throwaway
# game copy through tools/luanti_headless.sh, never shipped).
#
# Usage: tools/r52_amb/engine.sh MODE OUT_DIR [TIMEOUT_SECONDS]
#   MODE  walk   the passes on a scripted walk: surface, mine, tower, flight
#         calib  the cave-probe calibration and the peak heights
#         coast  (0.52.1) inland and across a coast, the share profile, the
#                water query's cost, the beach and lake survey
#   SEED=<unsigned decimal> is forwarded (default 12345).
#   LAUNCHER="<command> [args]" replaces tools/luanti_headless.sh, e.g. the
#   round's measuring-run semaphore with its label.
#   REPO=<dir> runs a different tree (e.g. a copy of the commit before the
#   change, for the "before" numbers of `walk`) with this probe.
# Copies the server log to OUT_DIR, removes the run directory and exits 0
# only on a clean boot whose probe finished ("RESULT DONE").
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="${REPO:-$(cd "$here/../.." && pwd -P)}"
mode="${1:?usage: engine.sh MODE OUT_DIR [TIMEOUT_SECONDS]}"
out="${2:?usage: engine.sh MODE OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${3:-330}"
[[ "$mode" == walk || "$mode" == calib || "$mode" == coast ]] || { echo "MODE must be walk, calib or coast" >&2; exit 2; }
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
root="$(mktemp -d /tmp/grudgelands-headless.r52-amb-XXXXXX)"
stage="$(mktemp -d /tmp/grudgelands-probe.r52-amb-XXXXXX)"
cp -a "$here/grug_probe_r52_amb" "$stage/"
printf 'return "%s"\n' "$mode" >"$stage/grug_probe_r52_amb/mode.lua"
# No real player keeps the probe's map loaded, so the staged game's
# minetest.conf keeps unused blocks for an hour (the walk reads the mine's
# nodes minutes after digging it) and spawns no mobs.
mkdir -p "$stage/a" "$stage/b"
cp "$repo/minetest.conf" "$stage/a/minetest.conf"
cp "$repo/minetest.conf" "$stage/b/minetest.conf"
printf '\n# Round 52 AMB probe\nserver_unload_unused_data_timeout = 3600\nmobs_spawn = false\n' \
	>>"$stage/b/minetest.conf"
(cd "$stage" && diff -u a/minetest.conf b/minetest.conf >"$stage/probe.patch") || true
read -r -a launcher <<<"${LAUNCHER:-$repo/tools/luanti_headless.sh}"
set +e
(cd "$repo" && SEED="${SEED:-12345}" PROBE="$stage/grug_probe_r52_amb" \
	GAME_PATCH="$stage/probe.patch" ROOT="$root" "${launcher[@]}" "$timeout_s") >"$out/headless.txt" 2>&1
code=$?
set -e
cat "$out/headless.txt"
if [[ "$root" == /tmp/grudgelands-headless.r52-amb-?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
[[ "$stage" == /tmp/grudgelands-probe.r52-amb-?* ]] && rm -rf "$stage"
grep -h '\[r52amb\]' "$out/server.log" 2>/dev/null | tee "$out/probe.txt" || true
if [[ $code -eq 0 ]] && grep -q 'RESULT DONE' "$out/probe.txt"; then
	echo "r52 amb probe ($mode): PASS"
	exit 0
fi
echo "r52 amb probe ($mode): FAIL (boot status $code)"
exit 1
