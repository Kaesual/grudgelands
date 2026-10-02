#!/usr/bin/env bash
# Round 28 Lane S1: render a zone's spawn regions for several seeds.
#
#   tools/r28_regions/run.sh [ZONE] [OUT_DIR] [SEED ...]
#
# Defaults: elandor_dawnmere_fields, docs/planning/round28/regions/dawnmere,
# seeds 42 7 1234 2026 99999 314159. One LuaJIT process per seed
# (regions.lua: the analytic world, the zone's shipped recipe and the game's
# own spawn_regions_core.lua), at most six at once under idle scheduling,
# then render.py per seed: seed_<seed>.png and seed_<seed>.md. The dumps go
# to a scratch directory (WORK, default a fresh mktemp dir). Thin lines are
# drawn only between different kinds (render.py --kind-borders); BORDERS=regions
# draws every region border instead.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
zone="${1:-elandor_dawnmere_fields}"
out="${2:-$repo/docs/planning/round28/regions/dawnmere}"
shift $(( $# > 2 ? 2 : $# )) || true
seeds=("$@")
[ ${#seeds[@]} -gt 0 ] || seeds=(42 7 1234 2026 99999 314159)
work="${WORK:-$(mktemp -d /tmp/r28_regions.XXXXXX)}"
render_args=(--kind-borders)
[ "${BORDERS:-kinds}" = regions ] && render_args=()
mkdir -p "$work" "$out"
idle=()
command -v chrt >/dev/null && idle=(chrt --idle 0)
pids=()
for seed in "${seeds[@]}"; do
	"${idle[@]}" luajit "$here/regions.lua" "$repo" "$seed" "$zone" "$work" \
		2> "$work/$seed.log" &
	pids+=($!)
done
status=0
for i in "${!pids[@]}"; do
	if ! wait "${pids[$i]}"; then
		echo "seed ${seeds[$i]} FAILED:" >&2
		cat "$work/${seeds[$i]}.log" >&2
		status=1
	else
		cat "$work/${seeds[$i]}.log" >&2
	fi
done
for seed in "${seeds[@]}"; do
	[ -f "$work/${zone}_${seed}.json" ] || continue
	python3 "$here/render.py" --dump "$work" --zone "$zone" --seed "$seed" --out "$out" "${render_args[@]}"
done
echo "images and stats written to $out (dumps in $work)"
exit "$status"
