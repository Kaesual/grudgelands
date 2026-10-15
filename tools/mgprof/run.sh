#!/usr/bin/env bash
# Lane MGPROF: one measuring boot of the per-chunk mapgen stage profile.
#
# Boots tools/luanti_headless.sh with the throwaway stage timer
# (GAME_PATCH=tools/mgprof/stages.patch, staged game copy only) and the probe
# mod grug_probe_mgprof (PROBE=, staged only), on seed 12345, keeps the run
# directory for re-use, and copies the server log, the console log (info
# level: the engine profiler windows) and the extracted lines to OUT. The
# probe logs the server's CPU seconds (os.clock) when preparation is ready and
# at the end.
#
# Usage: tools/mgprof/run.sh stages|totals OUT [ROOT]
#   stages  per-stage marks, sub-timers and counters (GRUG_MGPROF lines)
#   totals  the same patch with only the callback total taken
#           (grug_mgprof_totals_only), for the instrumentation overhead
#   ROOT    a run directory a previous boot kept: its world keeps the finished
#           preparation and caches; reset_columns.py first deletes the
#           measured chunk columns so they generate fresh.
# Environment: TIMEOUT (default 330 s); MGPROF_QUEUE=<script> runs the boot
#   through a queue wrapper that takes the launcher's arguments (the lane used
#   ~/projects/grudgelands-orchestration/r45/engine_run.sh <label>); CLEAN=1
#   removes the run directory afterwards.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
mode="${1:?usage: run.sh stages|totals OUT [ROOT]}"
out="${2:?usage: run.sh stages|totals OUT [ROOT]}"
root="${3:-}"
[[ "$mode" == stages || "$mode" == totals ]] || { echo "mode must be stages or totals" >&2; exit 2; }
mkdir -p "$out"
probe_dir="$(mktemp -d /tmp/mgprof-probe.XXXXXX)"
trap 'rm -rf "$probe_dir"' EXIT
cp -a "$here/grug_probe_mgprof" "$probe_dir/"
printf 'return {totals_only = %s}\n' "$([[ $mode == totals ]] && echo true || echo false)" \
	>"$probe_dir/grug_probe_mgprof/config.lua"
if [[ -n "$root" ]]; then
	python3 "$here/reset_columns.py" "$root" | tee "$out/reset.txt"
fi
cd "$repo"
launcher=("$repo/tools/luanti_headless.sh")
if [[ -n "${MGPROF_QUEUE:-}" ]]; then launcher=("$MGPROF_QUEUE" "mgprof-$mode"); fi
start=$(date +%s)
set +e
env GAME_PATCH="$here/stages.patch" PROBE="$probe_dir/grug_probe_mgprof" KEEP=1 \
	SEED=12345 ${root:+ROOT="$root"} \
	"${launcher[@]}" "${TIMEOUT:-330}" --info >"$out/headless.txt" 2>&1
boot=$?
set -e
echo "wall_s=$(( $(date +%s) - start ))" >>"$out/headless.txt"
kept="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
log="$(sed -n 's/^log: //p' "$out/headless.txt" | tail -n 1)"
cat "$out/headless.txt"
if [[ -n "$log" && -f "$log" ]]; then
	cp "$log" "$out/server.log"
	cp "${log%.log}.console.log" "$out/console.log" 2>/dev/null || true
fi
grep -h 'GRUG_MGPROF' "$out/server.log" >"$out/mgprof.txt" 2>/dev/null || true
grep -h 'mgprof_probe' "$out/server.log" | tee "$out/probe.txt" || true
echo "root: $kept" >>"$out/headless.txt"
if [[ "${CLEAN:-0}" == 1 && -n "$kept" && "$kept" == /tmp/grudgelands-headless.?* ]]; then
	rm -rf "$kept"
fi
if [[ $boot -eq 0 ]] && grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "mgprof run: PASS (root $kept)"
	exit 0
fi
echo "mgprof run: FAIL (boot status $boot)"
exit 1
