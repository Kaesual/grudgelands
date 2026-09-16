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
# A HARNESS THAT PIPES A GATE THROUGH `tail` CANNOT FAIL. `run_capital.sh` exits
# 1 on a digest drift, and the first version of this function ended the pipeline
# with `tail -25`, so the status it saw was `tail`'s and every run reported 0.
# The review of 2026-09-16 hit that; `PIPESTATUS[0]` is what the runner actually
# returned, and it is carried out of the function and remembered.
run_status=0
run() {   # run <tree> <label> <runner...>
	local tree="$1"; shift
	local label="$1"; shift
	[[ -e "$out/$label" ]] && { echo "skip $label"; return 0; }
	port=$((port + 1))
	printf '=== %s (port %s)\n' "$label" "$port"
	( cd "$tree" && WP13_CAPITAL_PORT="$port" HIGHCOURT_PORT="$port" \
		WP13_HIGHCOURT_PORT="$port" nice -n 19 "$@" ) 2>&1 |
		tail -25
	local status="${PIPESTATUS[0]}"
	printf '%s runner exit=%s\n' "$label" "$status"
	[[ "$status" -eq 0 ]] || run_status=1
	return "$status"
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
printf 'runner exit status over every pass: %s\n' "$run_status"
exit "$run_status"
