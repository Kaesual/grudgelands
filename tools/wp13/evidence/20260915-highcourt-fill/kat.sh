#!/usr/bin/env bash
# The Highcourt acceptance KAT under both interpreters, and the plot/fill-lot
# predicate against the two committed terrain fields.
#
# The KAT's two outputs must be byte-identical: the same Lua runs under LuaJIT
# and under the engine's bundled PUC 5.1 build (docs/research/luanti-lua.md).
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260915-highcourt-fill"
# THE FIELDS ARE THIS PACKAGE'S OWN since the rebase onto the capital-terrain
# lane: that lane gave every capital riser a band of one-block ground steps, so
# the districts package's committed fields describe ground this world no longer
# has. Both were re-dumped from the merged tree with
# `run_highcourt.sh <out> field <seed>`.
fields="tools/wp13/evidence/20260915-highcourt-fill/highcourt"

luajit -e 'io.write(dofile("tools/wp13/highcourt_kat.lua")("."))' \
	>"$here/kat/kat-luajit.txt"
tools/bin/lua51 -e 'io.write(dofile("tools/wp13/highcourt_kat.lua")("."))' \
	>"$here/kat/kat-puc51.txt"
cmp "$here/kat/kat-luajit.txt" "$here/kat/kat-puc51.txt"
echo "highcourt_kat BYTE-IDENTICAL under both interpreters"

# The other WP13 fixtures this package can move, both interpreters through the
# micro pair; here only the LuaJIT pass, as a quick refusal.
for kat in library_kat blueprint_kat dur_brannoc_kat seam_kat \
		settlement_sockets_kat; do
	printf '%-24s ' "$kat"
	luajit -e "io.write(dofile('tools/wp13/$kat.lua')('.'))" >/dev/null &&
		echo PASS
done

# The terrain half: the 36 lots, the 16 FILL lots and the 52 plots against the
# fields of both gate seeds.
luajit tools/wp13/highcourt_plots.lua . \
	"$fields/field-531802985935182545.tsv" "$fields/field-8675309.tsv" \
	>"$here/plots.txt"
tail -1 "$here/plots.txt"

# And the derivation that produced the committed fill grids, so the table in
# section 3.3 of the research note is re-derivable rather than remembered.
luajit tools/wp13/highcourt_plots.lua . \
	"$fields/field-531802985935182545.tsv" "$fields/field-8675309.tsv" \
	--derive-fill >"$here/fill-derive.txt"
sed -n '/derived fill grids/,$p' "$here/fill-derive.txt"
