#!/usr/bin/env bash
# The two shipped walled capitals, full engine pass, BEFORE (main f5583e13) and
# AFTER (this branch), on both gate seeds: the rampart digest the runners gate on
# and the rampart dump itself, for the cell diff the corner commit owes.
set -uo pipefail
export LC_ALL=C
SP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
after="${1:?usage: engine-walls.sh AFTER_TREE BEFORE_TREE OUT_DIR}"
before="${2:?usage: engine-walls.sh AFTER_TREE BEFORE_TREE OUT_DIR}"
out="${3:?usage: engine-walls.sh AFTER_TREE BEFORE_TREE OUT_DIR}"
mkdir -p "$out"
port=31350
run() {   # run <tree> <label> <runner...>
	local tree="$1"; shift
	local label="$1"; shift
	[[ -e "$out/$label" ]] && { echo "skip $label"; return 0; }
	port=$((port + 1))
	printf '=== %s (port %s)\n' "$label" "$port"
	( cd "$tree" && WP13_CAPITAL_PORT="$port" HIGHCOURT_PORT="$port" \
		WP13_HIGHCOURT_PORT="$port" nice -n 19 "$@" ) 2>&1 |
		tail -25
}
for seed in 531802985935182545 8675309; do
	run "$before" "before-dur_brannoc-$seed" \
		bash tools/wp13/run_capital.sh "$out/before-dur_brannoc-$seed" \
		dur_brannoc full "$seed"
	run "$after" "after-dur_brannoc-$seed" \
		bash tools/wp13/run_capital.sh "$out/after-dur_brannoc-$seed" \
		dur_brannoc full "$seed"
	run "$before" "before-highcourt-$seed" \
		bash tools/wp13/run_highcourt.sh "$out/before-highcourt-$seed" \
		full "$seed"
	run "$after" "after-highcourt-$seed" \
		bash tools/wp13/run_highcourt.sh "$out/after-highcourt-$seed" \
		full "$seed"
done
echo "=== overlay digests"
grep -H . "$out"/*/overlay-digests.txt 2>/dev/null || true
grep -H . "$out"/*/avenue-digest.txt 2>/dev/null || true
echo "=== rampart dump diffs"
for seed in 531802985935182545 8675309; do
	for pair in "dur_brannoc:dur_brannoc-rampart.tsv" \
			"highcourt:highcourt-wall.tsv"; do
		key="${pair%%:*}"; file="${pair##*:}"
		a="$out/before-$key-$seed/$file"
		b="$out/after-$key-$seed/$file"
		if [[ -f "$a" && -f "$b" ]]; then
			n=$(diff "$a" "$b" | grep -c '^[<>]' || true)
			printf '%s %s %s changed_cell_lines=%s\n' "$key" "$seed" "$file" "$n"
			diff "$a" "$b" >"$out/diff-$key-$seed.txt" || true
		else
			printf '%s %s %s MISSING\n' "$key" "$seed" "$file"
		fi
	done
done
