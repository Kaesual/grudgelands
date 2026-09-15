#!/usr/bin/env bash
# What the capital terraces look like, for the user.
#
# Two kinds of picture, and the difference matters:
#
#   * `renders/terraces-<capital>-<seed>.png` -- the HEIGHT, drawn by
#     `tools/wp13/render_terraces.py` from the field TSVs in `fields/`: the
#     plateau from above with one colour band per terrace, and a section through
#     the anchor drawn as blocks so the steps can be counted. `before` is the
#     same field taken on main at 19abee02, `after` is this branch.
#   * `renders/built-<capital>-<seed>.png` -- read back out of the FINISHED MAP
#     by the probe, so the ground MATERIAL and the road as actually laid are in
#     them. This is the picture that shows a capital is no longer a stone slab.
#
# Usage: renders.sh <engine dir of this branch> [<engine dir of main>]
#   each directory holds the per-seed run directories the run_*.sh scripts wrote.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
here="$repo/tools/wp13/evidence/20260915-capital-terrain"
after_engine="${1:?usage: renders.sh AFTER_ENGINE_DIR [BEFORE_ENGINE_DIR]}"
before_engine="${2:-}"
cd "$repo"
out="$here/renders"
mkdir -p "$out"

render_terraces() {
	python3 tools/wp13/render_terraces.py "$@"
}

echo "== the height, before and after =="
# The section window per capital is the stretch of the z = 0 row that carries
# the most terrace risers on the BEFORE tree, so the picture shows the thing the
# package changed rather than a flat plateau.
for pair in "highcourt:2:-240:-190:20:Highcourt" \
		"dur_brannoc:4:-140:-90:20:Dur Brannoc"; do
	key="${pair%%:*}"; rest="${pair#*:}"
	step="$(echo "$rest" | cut -d: -f1)"
	from="$(echo "$rest" | cut -d: -f2)"
	to="$(echo "$rest" | cut -d: -f3)"
	nodepx="$(echo "$rest" | cut -d: -f4)"
	name="$(echo "$rest" | cut -d: -f5-)"
	for seed in 8675309 531802985935182545; do
		before="$here/fields/before-$key-$seed.tsv"
		after="$here/fields/after-$key-$seed.tsv"
		[[ -f "$after" ]] || continue
		args=()
		labels=""
		if [[ -f "$before" ]]; then args+=("$before"); labels="before,after"; fi
		args+=("$after")
		[[ -n "$labels" ]] || labels="after"
		render_terraces "${args[@]}" -o "$out/terraces-$key-$seed.png" \
			--window 160 --scale 2 --step "$step" \
			--section-from "$from" --section-to "$to" --node-px "$nodepx" \
			--labels "$labels" --title "$name, seed $seed"
	done
done

echo "== the built ground, from the finished map =="
draw_built() {
	local label="$1" tsv="$2"
	[[ -f "$tsv" ]] || { echo "  (missing $tsv)"; return; }
	python3 tools/wp13/render_blueprint.py "$tsv" -o "$out/built-$label.png" \
		--quiet --scale 4 --max-pixels 5000
	printf '  %s\n' "$label"
}
draw_built "highcourt-8675309-after" \
	"$after_engine/hc-8675309/highcourt-avenue.tsv"
draw_built "dur_brannoc-8675309-after" \
	"$after_engine/db-8675309/dur_brannoc-avenue.tsv"
if [[ -n "$before_engine" ]]; then
	draw_built "highcourt-8675309-before" \
		"$before_engine/hc-8675309/highcourt-avenue.tsv"
	draw_built "dur_brannoc-8675309-before" \
		"$before_engine/db-8675309/dur_brannoc-avenue.tsv"
fi

echo "== the ground census of each built avenue strip =="
census() {
	local label="$1" tsv="$2"
	[[ -f "$tsv" ]] || return 0
	printf '\n== %s ==\n' "$label"
	cut -f4 "$tsv" | sort | uniq -c | sort -rn | head -14
}
{
	census "highcourt 8675309 after" \
		"$after_engine/hc-8675309/highcourt-avenue.tsv"
	census "dur_brannoc 8675309 after" \
		"$after_engine/db-8675309/dur_brannoc-avenue.tsv"
	if [[ -n "$before_engine" ]]; then
		census "highcourt 8675309 before" \
			"$before_engine/hc-8675309/highcourt-avenue.tsv"
		census "dur_brannoc 8675309 before" \
			"$before_engine/db-8675309/dur_brannoc-avenue.tsv"
	fi
} >"$here/ground-census.txt"
cat "$here/ground-census.txt"
ls -1 "$out"
