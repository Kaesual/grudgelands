#!/usr/bin/env bash
# The offline measurements of playtest round 1's apron vegetation, both gate
# seeds. Each script builds the real WP40 horizontal (and, where it needs a
# functional surface, height) authority for one seed and reads it through the
# public query seams only.
#
#   apron_edge    per ray of all four sides of every start, the Chebyshev
#                 excess of the 128-node build envelope at which the vegetation
#                 rule first lets a host through: the jagged treeline itself,
#                 as a distribution plus the raw profile
#   ring_bands    per-start column counts by Chebyshev band -- claim exclusion,
#                 vegetation exclusion, decoration host under the claim
#                 predicate and under the vegetation one (unchanged from the
#                 round-B script, so the two rounds' numbers are comparable)
#   road_shoulder how close to the carriageway a biome decoration may host, on
#                 the gate approach and on an ordinary stretch of the same
#                 route (unchanged from the round-B script). This is the
#                 load-bearing check of this round: the apron now hosts, and
#                 the road corridor crossing it must still not.
#
# A before/after comparison needs a second, immutable source tree as the first
# argument; the numbers in README.md were taken against a `git worktree`-free
# `git archive` copy of the parent commit.
#
#   measure.sh <absent absolute output dir> [<other repo root>]
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
out="${1:?absent absolute output directory required}"
tree="${2:-$repo}"
[[ "$out" == /* && ! -e "$out" ]] || exit 2
mkdir -p "$out"
here="$repo/tools/wp13/evidence/20260915-apron-and-throne/measure"
for seed in 531802985935182545 8675309; do
	for probe in apron_edge ring_bands road_shoulder; do
		chrt --idle 0 ionice -c3 luajit "$here/$probe.lua" "$tree" "$seed" \
			"$out/$probe-$seed.tsv"
	done
done
sha256sum "$out"/*.tsv
