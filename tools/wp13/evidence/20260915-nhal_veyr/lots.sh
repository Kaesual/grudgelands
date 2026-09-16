#!/usr/bin/env bash
# The lot predicate over ALL NINE seeds of `tools/wp13/capital_anchor_fixture.lua`.
#
#     lots.sh <terrain-out-root> [--repair]
#
# `<terrain-out-root>` is what `terrain_all.sh` wrote: one `terrain-<seed>/`
# directory per seed, each with the capital probe's 4-node envelope grid in it.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
root="${1:?usage: lots.sh TERRAIN_OUT_ROOT [--repair]}"
shift || true
grids=()
for seed in 531802985935182545 8675309 15912857179583385436 0 1 2 42 12345 \
		999999999; do
	grids+=("$root/terrain-$seed/nhal_veyr-grid.tsv")
done
exec luajit tools/wp13/nhal_veyr_plots.lua . "${grids[@]}" "$@"
