#!/usr/bin/env bash
# The pad-edge jitter in isolation: two `ring_heights.lua` dumps of the SAME
# tree, one with the jitter branch in `fitting_grade_at` disabled, summarised as
# changed columns and maximum absolute height delta per Chebyshev band. Disabling
# exactly that branch is what makes this an A/B of the jitter and not of the
# whole round.
#
#   pad_edge_delta.sh OUT.TSV SEED WITHOUT.TSV WITH.TSV [SEED WITHOUT WITH ...]
set -euo pipefail
export LC_ALL=C
out="${1:?output tsv required}"
shift
printf 'seed\tstart\tband\tcolumns\tchanged\tmax_abs_delta\n' >"$out"
while [[ "$#" -ge 3 ]]; do
	seed="$1" without="$2" with="$3"
	shift 3
	paste -- "$without" "$with" | awk -F'\t' -v seed="$seed" '
		{
			band = ($2 <= 63) ? "1pad_0_63" : (($2 <= 73) ? "2apron_64_73" :
				(($2 <= 127) ? "3blend_74_127" : "4outside_128_140"))
			key = $1 "\t" band
			total[key]++
			d = $6 - $3
			if (d != 0) {
				changed[key]++
				if (d < 0) d = -d
				if (d > max[key]) max[key] = d
			}
		}
		END {
			for (k in total)
				printf "%s\t%s\t%d\t%d\t%d\n", seed, k, total[k], changed[k] + 0,
					max[k] + 0
		}' | sort -k2,2 -k3,3 | sed 's/\t[1-4]\([a-z]\)/\t\1/' >>"$out"
done
column -t "$out"
