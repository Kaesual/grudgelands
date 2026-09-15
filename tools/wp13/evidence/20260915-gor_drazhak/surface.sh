#!/usr/bin/env bash
# THE PLOT GATE. `run_capital.sh <out> gor_drazhak surface <seed>` samples every
# plot column by column at its real position with the same
# `grug_zones.terrain_height_at` the load-time `r7_settlement.audit_terrain`
# uses. This holds the 52 plots of three worlds to the plot rules of the
# capitals contract's section 2.1: dry footprint, dry margin, dry reference
# column, perimeter fall inside the foundation skirt, and rise inside the
# airspace the plot really cut.
#
# The lot predicate (`legality.sh`) reads the terrain grid at a quarter of its
# resolution and is a DERIVATION instrument; this is the measurement.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260915-gor_drazhak"
GRUG_REPO="$repo" luajit "$here/surface_check.lua" \
	"$here/surface/surface-531802985935182545.tsv" \
	"$here/surface/surface-15912857179583385436.tsv"
