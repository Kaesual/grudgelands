#!/usr/bin/env bash
# Lane R's offline sweep: `tools/wp13/route_gates.lua` on all nine fixture seeds,
# once against a checkout of the base commit and once against this tree.
#
#     bash measure.sh BEFORE_REPO AFTER_REPO OUT_DIR
#
# BEFORE_REPO is a checkout of main 922bfd92 with this lane's
# `tools/wp13/route_gates.lua` copied into it (the tool reads only the tree it
# is pointed at). Two processes at a time at most; every run under `nice -n 19`.
set -uo pipefail
export LC_ALL=C
before="${1:?before repo}"
after="${2:?after repo}"
out="${3:?output directory}"
mkdir -p "$out"
SEEDS=(531802985935182545 8675309 15912857179583385436 0 1 2 42 12345 999999999)
for tag in before after; do
	repo="$before"
	[[ "$tag" == after ]] && repo="$after"
	: >"$out/$tag-progress.txt"
	for seed in "${SEEDS[@]}"; do
		start=$(date +%s)
		nice -n 19 luajit "$repo/tools/wp13/route_gates.lua" "$repo" "$seed" \
			"$out/$tag-$seed.tsv" >"$out/$tag-$seed.log" 2>&1
		code=$?
		echo "$tag seed=$seed exit=$code seconds=$(( $(date +%s) - start ))" \
			>>"$out/$tag-progress.txt"
	done
done
echo "== approach: distance of each route end to its gate =="
for tag in before after; do
	printf '%s\t' "$tag"
	cat "$out/$tag"-*.tsv | grep -E "^approach" |
		awk -F'\t' '{if($11>m)m=$11; s+=$11; n++}
			END {print "rows="n" max="m+0" sum="s+0}'
done
echo "== route and deck columns strictly inside an envelope =="
for tag in before after; do
	printf '%s\t' "$tag"
	cat "$out/$tag"-*.tsv | grep -E "^interior	" |
		awk -F'\t' '{r+=$6; k+=$8; if($6>mr)mr=$6; if($8>mk)mk=$8; n++}
			END {print "rows="n" route="r+0" route_max="mr+0" deck="k+0" deck_max="mk+0}'
done
echo "== the step at the gate =="
for tag in before after; do
	printf '%s\t' "$tag"
	cat "$out/$tag"-*.tsv | grep -E "^gate	" |
		awk -F'\t' '{if($12>m)m=$12; if($12>1)bad++; n++}
			END {print "rows="n" over_one="bad+0" max="m+0}'
done
echo "== entry: walk breaks from 64 nodes outside the avenue in to the core =="
for tag in before after; do
	printf '%s\t' "$tag"
	cat "$out/$tag"-*.tsv | grep -E "^entry" |
		awk -F'\t' '{b+=$7; if($8>m)m=$8; if($7>0)runs++; n++}
			END {print "runs="n" with_a_break="runs+0" breaks="b+0" worst="m+0}'
done
echo "== water under the avenues, and whether the road is still continuous =="
for tag in before after; do
	printf '%s\t' "$tag"
	cat "$out/$tag"-*.tsv | grep -E "^avenue	" |
		awk -F'\t' '{w+=$6; if($6>0)wet++; miss+=$7; jump+=$8; n++}
			END {print "runs="n" wet="wet+0" water_columns="w+0" unpaved="miss+0" steps="jump+0}'
done
echo "== what is left, after, by capital and side =="
cat "$out"/after-*.tsv | grep -E "^entry" | awk -F'\t' '$7>0 {print $3"\t"$4}' |
	sort | uniq -c
