#!/usr/bin/env bash
# The KAT set of WP13 playtest round 3 lane 2, under both interpreters.
#
#   1. the new decoration anchor KAT -- the gate that turns red if a template
#      ever floats above its anchor again;
#   2. the six start identities, which this lane may not move;
#   3. the WP13 final micro pair, which this lane may not move;
#   4. the seam KAT, which builds the real R7 manifest from the roster.
#
# Usage: kat.sh OUTPUT_DIR   (absolute, must not exist)
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
out="${1:?usage: kat.sh OUTPUT_DIR}"
[[ "$out" = /* && ! -e "$out" ]] || { echo "OUTPUT_DIR must be absent and absolute" >&2; exit 2; }
mkdir -p "$out"
cd "$repo"
JIT="${WP13_LUAJIT:-luajit}"
PUC="${WP13_PUC:-$repo/tools/bin/lua51}"

for pair in "luajit:$JIT" "puc51:$PUC"; do
	label="${pair%%:*}"; bin="${pair#*:}"
	"$bin" -e 'io.write(dofile("tools/wp13/decoration_anchor_kat.lua")("."))' \
		>"$out/decoration-anchor-$label.txt" 2>&1
	echo "decoration_anchor_kat $label exit=$?"
done
# The only line that may differ between the two is the air_base provenance:
# LuaJIT decodes the schematics through zlib, PUC 5.1 cannot and reads the
# frozen table, and both then run the identical assertion.
diff <(sed 's/ decoded$/ X/;s/ frozen$/ X/;s/air_base .*/air_base X/' \
		"$out/decoration-anchor-luajit.txt") \
	<(sed 's/ decoded$/ X/;s/ frozen$/ X/;s/air_base .*/air_base X/' \
		"$out/decoration-anchor-puc51.txt") \
	&& echo "decoration_anchor_kat: interpreters agree"

"$JIT" tools/wp13/evidence/20260914-capital-parts/start_identity.lua . \
	>"$out/start-identity.txt" 2>&1
diff "$out/start-identity.txt" \
	tools/wp13/evidence/20260914-capital-parts/start-identity.txt \
	&& echo "six start identities: byte-identical to the recorded set"

"$JIT" tools/wp13/final_micro.lua . "$out/final-micro-luajit.tsv" luajit
"$PUC" tools/wp13/final_micro.lua . "$out/final-micro-puc51.tsv" puc51
cmp "$out/final-micro-luajit.tsv" "$out/final-micro-puc51.tsv" \
	&& echo "WP13 final micro pair: byte-identical"
sha256sum "$out/final-micro-luajit.tsv"

"$JIT" -e 'io.write(dofile("tools/wp13/seam_kat.lua")("."))' \
	>"$out/seam-luajit.txt" 2>&1
echo "seam_kat exit=$?"
"$PUC" -e 'io.write(dofile("tools/wp13/seam_kat.lua")("."))' \
	>"$out/seam-puc51.txt" 2>&1
cmp "$out/seam-luajit.txt" "$out/seam-puc51.txt" \
	&& echo "seam_kat: byte-identical under both interpreters"
