#!/usr/bin/env bash
# Round 49 lane CACHE: one shell-order probe boot. Boots
# tools/luanti_headless.sh on a fresh world of seed 12345 with the stage timer
# (tools/mgprof/stages.patch) plus this lane's cache counters
# (tools/r49_cache/counters.patch), both on the staged game copy only, and
# the probe grug_probe_r49cache (chunks in player-shell order), then copies
# the server log to OUT and summarizes it (tools/r49_cache/analyze.py).
#
# Usage: tools/r49_cache/run_probe.sh OUT
# Environment: TIMEOUT (default 300 s); QUEUE=<script> runs the boot through
#   a queue wrapper that takes a label and then the launcher's arguments (the
#   lane used ~/projects/grudgelands-orchestration/r45/engine_run.sh).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run_probe.sh OUT}"
mkdir -p "$out"
work="$(mktemp -d /tmp/r49cache-probe.XXXXXX)"
trap 'rm -rf "$work"' EXIT
cat "$repo/tools/mgprof/stages.patch" "$here/counters.patch" >"$work/probe.patch"
cd "$repo"
launcher=("$repo/tools/luanti_headless.sh")
if [[ -n "${QUEUE:-}" ]]; then launcher=("$QUEUE" "r49-cache-probe"); fi
set +e
env GAME_PATCH="$work/probe.patch" PROBE="$here/probe/grug_probe_r49cache" SEED=12345 KEEP=1 \
	"${launcher[@]}" "${TIMEOUT:-300}" >"$out/headless.txt" 2>&1
boot=$?
set -e
cat "$out/headless.txt"
log="$(sed -n 's/^log: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$log" && -f "$log" ]]; then cp "$log" "$out/server.log"; fi
# The kept run directory (the log is copied): removed, never a glob.
kept="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$kept" && "$kept" == /tmp/grudgelands-headless.?* && -d "$kept" ]]; then
	rm -rf "$kept"
fi
python3 -I "$here/analyze.py" "$out/server.log" | tee "$out/summary.txt" || true
if [[ $boot -eq 0 ]] && grep -q '\[r49cache\] RESULT PASS' "$out/server.log"; then
	echo "r49 cache probe: PASS"
	exit 0
fi
echo "r49 cache probe: FAIL (boot status $boot)"
exit 1
