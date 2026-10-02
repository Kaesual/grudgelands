#!/usr/bin/env bash
# Round 30 Lane P3: the region-map cache test (portable_test.lua) on seeds
# 12345 and 42, one LuaJIT process per seed in parallel under idle scheduling.
#   tools/r30_p3/run.sh [SEED ...]
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$here/../.."
seeds=("$@")
[ ${#seeds[@]} -gt 0 ] || seeds=(12345 42)
idle=()
command -v chrt >/dev/null && idle=(chrt --idle 0)
work="$(mktemp -d /tmp/r30_p3_run.XXXXXX)"
pids=()
for seed in "${seeds[@]}"; do
	mkdir "$work/world_$seed"
	"${idle[@]}" luajit tools/r30_p3/portable_test.lua "$seed" "$work/world_$seed" \
		>"$work/$seed.log" 2>&1 &
	pids+=($!)
done
status=0
for i in "${!pids[@]}"; do
	wait "${pids[$i]}" || status=1
	cat "$work/${seeds[$i]}.log"
done
rm -rf "$work"
exit "$status"
