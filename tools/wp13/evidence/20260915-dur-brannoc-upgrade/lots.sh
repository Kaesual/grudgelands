#!/usr/bin/env bash
# Where Dur Brannoc's 36 district lots and 16 fill lots may stand, on ALL NINE
# worlds of `tools/wp13/capital_anchor_fixture.lua` at once.
#
#   lots.sh                verify the committed grids
#   lots.sh --derive       re-derive the 36 district lots
#   lots.sh --derive-fill  re-derive the 16 fill lots
#   lots.sh --repair       the smallest edit a terrain change needs
#
# The field dumps come from `tools/wp13/run_capital.sh <out> dur_brannoc field
# <seed>`, one boot per seed, about 35 s and 1.1 MB each. Point WP13_FIELDS at
# the directory that holds them, laid out as <seed>/dur_brannoc-field.tsv.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
fields_root="${WP13_FIELDS:-/tmp/grug-w2-durbrannoc-fields}"
fields=()
for seed in 531802985935182545 8675309 15912857179583385436 0 1 2 42 12345 \
		999999999; do
	path="$fields_root/$seed/dur_brannoc-field.tsv"
	[[ -f "$path" ]] || {
		echo "missing field dump for seed $seed: $path" >&2
		echo "run: tools/wp13/run_capital.sh $fields_root/$seed dur_brannoc field $seed" >&2
		exit 2
	}
	fields+=("$path")
done
exec luajit tools/wp13/capital_lots.lua "$repo" dur_brannoc "${fields[@]}" "$@"
