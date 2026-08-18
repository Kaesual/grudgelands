#!/usr/bin/env bash
set -euo pipefail

# WP40 T2 census contention probe (plan section 6.5, the 2026-08-18 CPU gate).
#
#   tools/wp40/run_t2_census_probe.sh
#
# Measures what the run-cost gate spends: three census worker seeds scanned
# solo, the same three scanned again while one busy loop per logical CPU keeps
# the host saturated, and the worst CPU inflation between the two passes as the
# contention margin.  It writes tools/wp40/results/census-cpu-gate.conf, which
# a full-`W` start reads and refuses to run without.
#
# Neither pass is idle-scheduled.  The fleet is (section 6.5), but a probe at
# SCHED_IDLE against sixteen busy loops would be starved rather than contended
# and would measure how long the kernel makes it wait, not how much more CPU
# the same work costs when the cores are shared.
#
# Deliberately short: this is measurement, not a soak.  Three solo seeds plus
# three loaded ones is roughly five minutes on the M4 host, and the load
# processes carry a hard lifetime of their own so that even a killed probe
# cannot leave the machine spinning.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"

command -v rg >/dev/null 2>&1 || {
	echo "${BASH_SOURCE[0]##*/}: ripgrep (rg) is required and was not found" >&2
	exit 1
}
"$repo/tools/bin/luac51" -p "$repo/tools/wp40/t2_census_probe_contention.lua"
if "$repo/tools/bin/luac51" -l -p \
		"$repo/tools/wp40/t2_census_probe_contention.lua" | rg -q 'SETGLOBAL'; then
	echo "WP40 T2 census probe global write in t2_census_probe_contention.lua" >&2
	exit 1
fi
bash -n "$script_dir/run_t2_census_probe.sh"

lua_bin="${WP40_LUA_BIN:-/usr/bin/luajit}"
lua_path="$(command -v "$lua_bin" 2>/dev/null || true)"
if [[ -z "$lua_path" || ! -x "$lua_path" ]]; then
	echo "WP40 T2 census probe interpreter is not executable: $lua_bin" >&2
	exit 2
fi
echo "WP40 T2 census probe interpreter: $lua_path -> $(readlink -f "$lua_path")"

# The three KAT seeds with pinned behaviour: seed 0, the Slot-29 R19 witness and
# the Slot-30 fragment witness.  Pinned matters here -- a seed that started
# stage-rejecting would make the anchor a measurement of a cheap seed, and the
# probe refuses that rather than writing it.
seeds=(0 15219119262482319357 16178445837170081103)

scratch="$(mktemp -d /tmp/grudgelands-wp40-t2-census.XXXXXXXX)"
declare -a load_pids=()
cleanup() {
	local pid
	for pid in "${load_pids[@]:-}"; do
		if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; fi
	done
	if [[ "$scratch" == /tmp/grudgelands-wp40-t2-census.* ]]; then
		rm -rf -- "$scratch"
	fi
}
# EXIT alone would leave sixteen busy loops behind on a Ctrl-C, which is the one
# abort a probe like this actually sees.
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

started=$SECONDS
echo "WP40 T2 census probe loadavg before: $(cut -d' ' -f1-3 /proc/loadavg)"

echo "== solo pass (no idle scheduling, no synthetic load) =="
"$lua_path" "$script_dir/t2_census_probe_contention.lua" "$repo" "$scratch" \
	measure "$scratch/solo.txt" "${seeds[@]}"
solo_seconds=$((SECONDS - started))

echo "== loaded pass ($(nproc) busy loops, one per logical CPU) =="
# Each loop carries its own deadline, so a probe that is SIGKILLed -- the one
# abort no trap can catch -- still cannot leave the host saturated.  Fifteen
# minutes is well past the pass it exists for.
load_started=$SECONDS
for _ in $(seq 1 "$(nproc)"); do
	bash -c 'deadline=$((SECONDS + 900)); while (( SECONDS < deadline )); do :; done' &
	load_pids+=($!)
done
# Long enough for every loop to be scheduled and counted before the measured
# pass starts; short enough not to be part of the cost.
sleep 2
echo "WP40 T2 census probe loadavg under load: $(cut -d' ' -f1-3 /proc/loadavg)"
"$lua_path" "$script_dir/t2_census_probe_contention.lua" "$repo" "$scratch" \
	measure "$scratch/loaded.txt" "${seeds[@]}"
loaded_seconds=$((SECONDS - load_started))
for pid in "${load_pids[@]}"; do kill "$pid" 2>/dev/null || true; done
wait "${load_pids[@]}" 2>/dev/null || true
load_pids=()

echo "== margin =="
"$lua_path" "$script_dir/t2_census_probe_contention.lua" "$repo" "$scratch" \
	finalize "$scratch/solo.txt" "$scratch/loaded.txt"
echo "WP40 T2 census probe done solo_wall_seconds=$solo_seconds" \
	"loaded_wall_seconds=$loaded_seconds total_wall_seconds=$((SECONDS - started))"
