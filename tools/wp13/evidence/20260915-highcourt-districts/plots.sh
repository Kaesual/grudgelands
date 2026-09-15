#!/usr/bin/env bash
# Where the 36 lots of the four quadrants may stand, verified against the real
# terrain of BOTH gate seeds, and re-derived from the authored layout so the
# committed table in `wp13/highcourt_quadrants.lua` is reproducible rather than
# remembered.
#
# The two field dumps are `tools/wp13/run_highcourt.sh <out> field <seed>`:
# one headless boot each, about twenty seconds, no mapchunk emerged. They are
# committed beside this script so the predicate can be re-run without an
# engine at all.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
here="$repo/tools/wp13/evidence/20260915-highcourt-districts"
cd "$repo"
luajit tools/wp13/highcourt_plots.lua "$repo" \
	"$here/highcourt/field-531802985935182545.tsv" \
	"$here/highcourt/field-8675309.tsv"
echo
luajit tools/wp13/highcourt_plots.lua "$repo" \
	"$here/highcourt/field-531802985935182545.tsv" \
	"$here/highcourt/field-8675309.tsv" --derive
