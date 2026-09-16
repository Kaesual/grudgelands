#!/usr/bin/env bash
# The one bounded final-byte process for this increment: every WP13 fixture in
# a single interpreter, run once under LuaJIT and once under the engine's own
# bundled PUC 5.1 build, with the inputs hashed before and after so the two
# outputs are known to have come from the same bytes.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
out="tools/wp13/evidence/20260915-nhal_veyr/final-micro"
mkdir -p "$out"
rm -f "$out"/micro-luajit.tsv "$out"/micro-puc51.tsv

inputs() {
	find mods/MAPGEN/grug_mapgen/wp13 mods/MAPGEN/grug_mapgen/wp40 tools/wp13 \
		-name '*.lua' -print0 | sort -z | xargs -0 sha256sum | sha256sum
}
before="$(inputs)"
luajit tools/wp13/final_micro.lua . "$out/micro-luajit.tsv" luajit
tools/bin/lua51 tools/wp13/final_micro.lua . "$out/micro-puc51.tsv" puc51
after="$(inputs)"
[[ "$before" == "$after" ]] || { echo "INPUTS MOVED between the two runs" >&2; exit 1; }
echo "inputs: $before"
sha256sum "$out"/micro-luajit.tsv "$out"/micro-puc51.tsv
if cmp -s "$out/micro-luajit.tsv" "$out/micro-puc51.tsv"; then
	echo "WP13 FINAL MICRO PAIR BYTE-IDENTICAL"
else
	echo "WP13 FINAL MICRO PAIR DIFFERS" >&2
	exit 1
fi
