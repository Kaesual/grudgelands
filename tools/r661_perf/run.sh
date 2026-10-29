#!/usr/bin/env bash
# 0.66.1 lane PERF measuring run (grug_probe_r661_perf, staged into a
# throwaway game copy, never shipped): one engine boot that keeps the first
# identity's capital active (seed 42 by default), observes OBS seconds of
# server steps and reads the luanti process's and its Server thread's CPU
# time (/proc, clock ticks) at the probe's WINDOW START and WINDOW END lines.
# PROFILER=1 boots with profiler.load, instrument.profiler and
# grug_perf_profile_minutes = 1 (the periodic save every minute).
#
# Usage (any directory; through the Lua queue, one slot):
#   tools/r661_perf/run.sh OUT_DIR LABEL 0|1 [TIMEOUT]
#   ROOT=<dir>   re-use the run directory of an earlier KEEPROOT=1 run (the
#                same world, warm: the capital is generated already)
#   KEEPROOT=1   keep the run directory for the next run (path printed)
#   OBS=<s> observation (default 120); SEED (default 42);
#   TARGET=capital|start (default capital)
# Writes to OUT_DIR: headless.txt, the server log(s), r661_results.json,
# cpu.txt (start/end: wall seconds, process ticks, Server thread ticks, the
# clock tick rate), probe.txt ([r661] lines), perf.txt ([GRUG-PERF] lines)
# and the saved profile-*.json files. Exits 0 only when the probe finished.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR LABEL 0|1 [TIMEOUT]}"
label="${2:?label}"
profiler="${3:?0 or 1}"
timeout_s="${4:-300}"
[[ "$profiler" == 0 || "$profiler" == 1 ]] || { echo "PROFILER must be 0 or 1" >&2; exit 2; }
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
if [[ -n "${ROOT:-}" ]]; then
	root="$(realpath -e -- "$ROOT")"
	[[ "$root" == /tmp/grudgelands-headless.r661-* ]] || { echo "ROOT must be a r661 run dir" >&2; exit 2; }
else
	root="$(mktemp -d /tmp/grudgelands-headless.r661-XXXXXX)"
fi
patchdir="$(mktemp -d)"
mkdir -p "$patchdir/a" "$patchdir/b"
cp "$repo/minetest.conf" "$patchdir/a/minetest.conf"
cp "$repo/minetest.conf" "$patchdir/b/minetest.conf"
{
	echo ""
	echo "# 0.66.1 PERF probe ($label)"
	echo "max_forceloaded_blocks = 6000"
	echo "grug_r661_target = ${TARGET:-capital}"
	echo "grug_r661_obs = ${OBS:-120}"
	if [[ "$profiler" == 1 ]]; then
		echo "profiler.load = true"
		echo "instrument.profiler = true"
		echo "grug_perf_profile_minutes = 1"
	fi
} >>"$patchdir/b/minetest.conf"
(cd "$patchdir" && diff -u a/minetest.conf b/minetest.conf >"$patchdir/probe.patch") || true

# The log this boot will write (the launcher's own naming).
log="$root/server.log"; index=2
while [[ -e "$log" ]]; do log="$root/server.$index.log"; index=$((index + 1)); done
cpu="$out/cpu.txt"
: >"$cpu"
ticks() { # pid -> "process_ticks server_thread_ticks"
	local pid="$1" total thread="" t
	total="$(awk '{print $14 + $15}' "/proc/$pid/stat")"
	for t in /proc/"$pid"/task/*; do
		if [[ "$(cat "$t/comm" 2>/dev/null)" == Server ]]; then
			thread="$(awk '{print $14 + $15}' "$t/stat")"
		fi
	done
	echo "$total ${thread:-NA}"
}
(
	pid=""; started=0
	for _ in $(seq 1 4000); do
		if [[ -z "$pid" ]]; then
			pid="$(pgrep -f "^luanti.bin --server --gameid grudgelands --world $root/" | head -1 || true)"
		fi
		if [[ -n "$pid" && -f "$log" ]]; then
			if [[ $started -eq 0 ]] && grep -q '\[r661\] WINDOW START' "$log"; then
				echo "start $(date +%s.%N) $(ticks "$pid") $(getconf CLK_TCK)" >>"$cpu"
				started=1
			fi
			if [[ $started -eq 1 ]] && grep -q '\[r661\] WINDOW END' "$log"; then
				echo "end $(date +%s.%N) $(ticks "$pid") $(getconf CLK_TCK)" >>"$cpu"
				break
			fi
		fi
		sleep 0.2
	done
) &
sampler=$!
set +e
(cd "$repo" && SEED="${SEED:-42}" PROBE="$here/grug_probe_r661_perf" \
	GAME_PATCH="$patchdir/probe.patch" ROOT="$root" "$repo/tools/luanti_headless.sh" "$timeout_s") \
	>"$out/headless.txt" 2>&1
code=$?
set -e
kill "$sampler" 2>/dev/null || true
wait "$sampler" 2>/dev/null || true
rm -rf "$patchdir"
cat "$out/headless.txt"
cp "$log" "$out/server.log" 2>/dev/null || true
cp "$root/world/r661_results.json" "$out/" 2>/dev/null || true
cp "$root"/world/profile-*.json "$out/" 2>/dev/null || true
rm -f "$root"/world/profile-*.json "$root/world/r661_results.json"
if [[ "${KEEPROOT:-0}" == 1 ]]; then
	echo "kept: $root"
else
	rm -rf "$root"
fi
grep -a '\[r661\]' "$out/server.log" >"$out/probe.txt" 2>/dev/null || true
grep -a '\[GRUG-PERF\]' "$out/server.log" >"$out/perf.txt" 2>/dev/null || true
cat "$cpu"
if [[ $code -eq 0 ]] && grep -q 'RESULT DONE' "$out/probe.txt"; then
	echo "r661 probe: PASS ($out)"
	exit 0
fi
echo "r661 probe: FAIL (boot status $code)"
exit 1
