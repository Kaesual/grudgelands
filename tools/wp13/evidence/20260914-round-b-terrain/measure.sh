#!/usr/bin/env bash
# The four offline measurements of this round, both gate seeds. Each script
# builds the real WP40 horizontal and height authority for one seed
# (`new_runtime`, the same constructor live mapgen uses) and reads it through the
# public query seams only.
#
#   route_shape   the compiled start-route vertices near the start, with each
#                 vertex's Chebyshev radius and the heading change at it (reads
#                 the source geometry only, so it takes no seed)
#   gate_axis     the road columns on every start's gate axis, per z row
#   road_protection  every road column within 400 nodes of a start that is NOT
#                 inside a compiled claim exclusion (world.md section 2 R1)
#   road_shoulder how close to the carriageway a biome decoration may host, on
#                 the approach and on an ordinary stretch of the same route
#   ring_bands    per-start column counts by Chebyshev band: claim exclusion,
#                 vegetation exclusion, decoration host under the old and the
#                 new planner predicate
#   ring_heights  raw terrain height per column in a 281-node box per start,
#                 for a before/after column diff of the pad-edge jitter
#   pad_edge      reference/spawn height, the 128-envelope deviation count, the
#                 outer-envelope grade count and the flat-edge ray profile
#   height_digests  the frozen construction digests and metrics of the full
#                 artifact (`new`, not `new_runtime`)
#
# A before/after comparison needs a second, immutable source tree as the first
# argument; the numbers in README.md were taken against `git show`-extracted
# copies of the parent commits.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
out="${1:?absent absolute output directory required}"
[[ "$out" == /* && ! -e "$out" ]] || exit 2
mkdir -p "$out"
here="$repo/tools/wp13/evidence/20260914-round-b-terrain/measure"
chrt --idle 0 ionice -c3 luajit "$here/route_shape.lua" "$repo" \
	"$out/route_shape.tsv"
for seed in 531802985935182545 8675309; do
	for probe in gate_axis ring_bands pad_edge road_protection road_shoulder; do
		chrt --idle 0 ionice -c3 luajit "$here/$probe.lua" "$repo" "$seed" \
			"$out/$probe-$seed.tsv"
	done
	chrt --idle 0 ionice -c3 luajit "$here/ring_heights.lua" "$repo" "$seed" \
		"$out/ring_heights-$seed.tsv"
done
# The frozen construction digests. This one builds the FULL artifact (about
# three minutes per seed), so it runs for the user seed only.
chrt --idle 0 ionice -c3 luajit "$here/height_digests.lua" "$repo" \
	531802985935182545 "$out/height_digests-531802985935182545.tsv"
sha256sum "$out"/*.tsv
