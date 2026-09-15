#!/usr/bin/env bash
# The two offline terrain predicates of the Gor Drazhak package, against the
# terrain the engine measured on three worlds.
#
#   * `capital_wall.lua` -- is the real ground under the four rampart lines the
#     kind of ground the rampart's rules were written for? It loads its
#     constants from `wall.lua`, which is why `gor_drazhak_kat.lua` section 4
#     asserts `orc_palisade.lua`'s five equal to them.
#   * `gor_drazhak_lots.lua` -- may every district lot and every fill lot carry
#     any district's plot, on every world?
#
# The terrain dumps come from `run_capital.sh <out> gor_drazhak terrain <seed>`
# and are copied into `terrain/` beside this script as the probe summaries; the
# grid TSVs themselves are 700 kB each and are not committed, so this script
# takes their directory as an argument.
#
#     legality.sh /tmp/grug-w2-gor-terrain
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
prefix="${1:-/tmp/grug-w2-gor-terrain}"
a="$prefix-531802985935182545"
b="$prefix-8675309"
c="$prefix-15912857179583385436"

echo "== the ground under the four rampart lines, two gate seeds =="
luajit tools/wp13/capital_wall.lua . gor_drazhak \
	"$a/gor_drazhak-wall.tsv" "$b/gor_drazhak-wall.tsv"

echo
echo "== the 36 district lots and the 16 fill lots, three worlds =="
luajit tools/wp13/gor_drazhak_lots.lua . \
	"$a/gor_drazhak-grid.tsv" "$b/gor_drazhak-grid.tsv" \
	"$c/gor_drazhak-grid.tsv"
