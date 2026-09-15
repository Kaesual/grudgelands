#!/usr/bin/env bash
# The crossings as a WALK, read straight out of the map dumps: the topmost
# road node of every column along each crossing's centre line, before this
# lane and after it. This is the same evidence the renders show, in numbers.
#
# Anchor-relative throughout; Highcourt's anchor is 0,40,-1500.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

road='castle_pavement|stonewall_stair|plaza|castle_paving'

# $1 dump, $2 fixed coordinate column (1 = x, 3 = z), $3 the fixed value,
# $4 the coordinate to walk (1 or 3)
walk() {
	awk -F'\t' -v fixed="$2" -v value="$3" -v along="$4" -v road="$road" '
		$0 !~ /^#/ && $fixed == value && $4 ~ road {
			if (!(($along) in top) || $2 > top[$along]) {
				top[$along] = $2; name[$along] = $4
			}
		}
		END {
			n = 0
			for (p in top) { order[n++] = p + 0 }
			for (i = 0; i < n; i++)
				for (j = i + 1; j < n; j++)
					if (order[j] < order[i]) { t = order[i]; order[i] = order[j]; order[j] = t }
			for (i = 0; i < n; i++) printf "%d\t%d\t%s\n", order[i], top[order[i]], name[order[i]]
		}' "$1"
}

section() {
	echo
	echo "== $1 =="
	echo "along	road_top	node"
}

section "seed 531802985935182545, ring_north over route_006, z = 96, BEFORE"
walk "$here/engine/before-A/highcourt-crossing-1.tsv" 3 96 1
section "seed 531802985935182545, ring_north over route_006, z = 96, AFTER"
walk "$here/engine/after-A/highcourt-crossing-1.tsv" 3 96 1
section "seed 531802985935182545, lane_northwest_cross, z = 146, BEFORE"
walk "$here/engine/before-A/highcourt-crossing-2.tsv" 3 146 1
section "seed 531802985935182545, lane_northwest_cross, z = 146, AFTER"
walk "$here/engine/after-A/highcourt-crossing-2.tsv" 3 146 1
section "seed 531802985935182545, ring_west under route_021, x = -96, BEFORE"
walk "$here/engine/before-A/highcourt-crossing-3.tsv" 1 -96 3
section "seed 531802985935182545, ring_west under route_021, x = -96, AFTER"
walk "$here/engine/after-A/highcourt-crossing-3.tsv" 1 -96 3
section "seed 8675309, ring_north over route_006, z = 96, BEFORE"
walk "$here/engine/before-B/highcourt-crossing-1.tsv" 3 96 1
section "seed 8675309, ring_north over route_006, z = 96, AFTER"
walk "$here/engine/after-B/highcourt-crossing-1.tsv" 3 96 1

echo
echo "== the column the playtest found, out of the map =="
echo "-- seed 531802985935182545, x = -31, z = 95, BEFORE: the street filled the"
echo "-- river to the deck and replaced it; the lanes beside it stayed at -5."
awk -F'\t' '$0 !~ /^#/ && $1 == -31 && $3 == 95 && $2 > -9' \
	"$here/engine/before-A/highcourt-crossing-1.tsv" | sort -t$'\t' -k2,2n
echo "-- the same column AFTER: the river runs, the bridge stands, the street"
echo "-- is one course on the deck."
awk -F'\t' '$0 !~ /^#/ && $1 == -31 && $3 == 95 && $2 > -9' \
	"$here/engine/after-A/highcourt-crossing-1.tsv" | sort -t$'\t' -k2,2n
echo
echo "== the standards on the ring_north crossing's two verges, out of the map =="
echo "-- Before, four of them were under the road they light. The road at the"
echo "-- crossing is y 1 and on its ramps y 0 and -1 (see the walk above), and a"
echo "-- standard's light sits three courses over its footing."
lamps() {
	awk -F'\t' -v dump="$1" '
		$0 !~ /^#/ && ($3 == 93 || $3 == 99) && $4 ~ /torch/ {
			printf "  (%s, %s) light at y %s\n", $1, $3, $2
		}' "$1" | sort
}
echo "-- BEFORE"
lamps "$here/engine/before-A/highcourt-crossing-1.tsv"
echo "-- AFTER"
lamps "$here/engine/after-A/highcourt-crossing-1.tsv"

echo
echo "-- seed 531802985935182545, x = -96, z = 35: the pass-under, AFTER."
echo "-- Road at -5, three blocks of air, support at -1, deck at 0."
awk -F'\t' '$0 !~ /^#/ && $1 == -96 && $3 == 35 && $2 > -9' \
	"$here/engine/after-A/highcourt-crossing-3.tsv" | sort -t$'\t' -k2,2n
