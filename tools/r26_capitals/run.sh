#!/usr/bin/env bash
# Round 26 Lane W: before/after images of the six capitals on three seeds.
#
#   tools/r26_capitals/run.sh <before_repo> <after_repo> [out_root] [seedtag ...]
#
# <before_repo> / <after_repo>: trees whose mapgen is planned (e.g. an export
# of main: `git archive main mods tools | tar -x -C DIR`, and this worktree).
# Seed tags: s1 s42 s8675309 (the Round 22 prototype's seeds). Runs one
# idle-priority LuaJIT process per (variant, seed), at most JOBS (default 3)
# at once, then renders with render.py:
#   <out_root>/{before,after}/<tag>/<capital>.png   one plan per capital
#   <out_root>/compare/<tag>_<capital>.png          before | after
#   <out_root>/<tag>_overview.png                   the six pairs of a seed
# out_root defaults to tools/r26_capitals/out. About 30 s CPU per process.
#
# Also here: stats.py (one before/after table), check_protection.lua (the
# protected city on the planned layouts; each render leaves layouts.txt, which
# tools/wp13/capital_walls_probe.lua also reads). The named-drop evidence in
# results/ comes from the Round 25 Lane H harness:
#   tools/r25_capital_plots/fleet.sh <repo> tools/r25_capital_plots/results/sample200.txt OUT.tsv 4
#   tools/r25_capital_plots/compare.py OUT.tsv tools/r25_capital_plots/results/sample-branch.tsv
# (sample-branch.tsv is main's Round 25 planner; results/hard14.txt holds the
# five seeds that failed the load before Round 25 plus the seeds that dropped a
# named plot in earlier Round 26 iterations).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
before="$(cd "${1:?usage: run.sh BEFORE_REPO AFTER_REPO [OUT_ROOT] [SEEDTAG ...]}" && pwd -P)"
after="$(cd "${2:?usage: run.sh BEFORE_REPO AFTER_REPO [OUT_ROOT] [SEEDTAG ...]}" && pwd -P)"
out="${3:-$here/out}"
shift 3 || shift $#
tags=("$@")
[ ${#tags[@]} -gt 0 ] || tags=(s1 s42 s8675309)
declare -A SEEDS=([s1]=15140735923413111218 [s42]=42 [s8675309]=8675309)
jobs_max="${JOBS:-3}"
mkdir -p "$out"
for tag in "${tags[@]}"; do
	seed="${SEEDS[$tag]:-${tag#s}}"
	for variant in before after; do
		repo="$before"
		[ "$variant" = after ] && repo="$after"
		if [ "${SKIP_BEFORE:-0}" = 1 ] && [ "$variant" = before ] && [ -f "$out/before/$tag/highcourt.json" ]; then
			continue
		fi
		while [ "$(jobs -rp | wc -l)" -ge "$jobs_max" ]; do sleep 1; done
		mkdir -p "$out/$variant/$tag"
		chrt --idle 0 ionice -c3 luajit "$here/render.lua" "$repo" "$seed" "$out/$variant/$tag" \
			> "$out/$variant/$tag/log.txt" 2>&1 &
	done
done
wait
for tag in "${tags[@]}"; do
	python3 "$here/render.py" "$out" "$tag" > /dev/null
	echo "$out/${tag}_overview.png"
done
