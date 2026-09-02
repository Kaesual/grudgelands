#!/usr/bin/env bash
set -euo pipefail

# WP40 T2 census contention probe (plan section 6.5, the 2026-08-18 CPU gate).
#
#   tools/wp40/run_t2_census_probe.sh
#
# Measures what the run-cost gate spends: five census worker seeds scanned
# solo, the same five scanned again while one busy loop per logical CPU keeps
# the host saturated, and the worst CPU inflation between the two passes as the
# contention margin.  It writes tools/wp40/results/census-cpu-gate.conf, which
# a full-`W` start reads and refuses to run without.
#
# Since the v6 tiers (contracts 9.5) the solo pass is also the probe protocol's
# own measurement: each seed is split into its v5 tiers, its Scan-3b marginal
# and its Scan-4 marginal, and the split criterion's inputs are printed and
# written into the conf beside the budget they were measured with.
#
# Neither pass is idle-scheduled.  The fleet is (section 6.5), but a probe at
# SCHED_IDLE against sixteen busy loops would be starved rather than contended
# and would measure how long the kernel makes it wait, not how much more CPU
# the same work costs when the cores are shared.
#
# Deliberately short: this is measurement, not a soak.  Five solo seeds plus
# five loaded ones is roughly twelve minutes on the M4 host under the v6 tiers,
# and the load processes carry a hard lifetime of their own so that even a
# killed probe cannot leave the machine spinning.

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

# Contracts 9.5's probe seeds, in `W` order.  Four are Scan-4 members with
# pinned KAT behaviour -- seed 0 as the control, the two F10 face-simplicity
# witnesses whose face tier fails and whose Whole tier is therefore skipped,
# and the R19-heavy winner, the one seed here that pays a green Whole tier and
# so the expensive shape the anchor has to come from.  The fifth,
# 14069824983701673, is the first non-member in `W` order: it pays Scan-3b and
# no Scan-4, which is the marginal the 1,062 non-members of `W` will pay.
# Pinned matters for the four -- a seed that started stage-rejecting would make
# the anchor a measurement of a cheap seed, and the probe refuses that rather
# than writing it -- and the v5 full pass measured no stage reject anywhere in
# `W`, which is why the fifth can be picked by position at all.
seeds=(0 2147483648 14069824983701673 1959553668008863006
	16178445837170081103)

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
# abort no trap can catch -- still cannot leave the host saturated.  Twenty
# minutes is well past the pass it exists for: the v6 loaded pass over five
# seeds projects to roughly seven, and a deadline the pass can reach would
# silently end the contention it is supposed to measure.
load_started=$SECONDS
for _ in $(seq 1 "$(nproc)"); do
	bash -c 'deadline=$((SECONDS + 1200)); while (( SECONDS < deadline )); do :; done' &
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
