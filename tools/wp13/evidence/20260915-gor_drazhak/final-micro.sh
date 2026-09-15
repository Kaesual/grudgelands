#!/usr/bin/env bash
# The single bounded final-byte process for the Gor Drazhak package: every WP13
# fixture in one interpreter process, run once under LuaJIT and once under the
# engine's bundled PUC 5.1 build, with the exact input set hashed before and
# after so the two runs provably saw the same bytes.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
out="$repo/tools/wp13/evidence/20260915-gor_drazhak/final-micro"
cd "$repo"
rm -rf "$out"
mkdir -p "$out"

inputs_sha() {
	{
		find mods/MAPGEN/grug_mapgen/wp13 -name '*.lua' -print
		find tools/wp13 -maxdepth 1 -name '*.lua' -print
		printf '%s\n' \
			mods/CORE/grug_core/settlement_sockets.lua \
			mods/ENTITIES/grug_mobs/start_npcs.lua \
			mods/ENTITIES/grug_traders/vendors.lua \
			mods/ITEMS/grug_nodes/init.lua \
			mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua \
			mods/MAPGEN/grug_mapgen/wp40/r7_gor_drazhak_blueprint.lua \
			mods/MAPGEN/grug_mapgen/wp40/r7_dur_brannoc_blueprint.lua \
			mods/MAPGEN/grug_mapgen/wp40/r7_highcourt_blueprint.lua \
			mods/MAPGEN/grug_mapgen/wp40/r7_wp13_library.lua \
			tools/wp40/r6/common.lua
	} | sort | xargs sha256sum
}

inputs_sha >"$out/inputs-before.sha256"

luajit tools/wp13/final_micro.lua . "$out/micro-luajit.tsv" luajit \
	>"$out/micro-luajit.log"
tools/bin/lua51 tools/wp13/final_micro.lua . "$out/micro-puc51.tsv" puc51 \
	>"$out/micro-puc51.log"

inputs_sha >"$out/inputs-after.sha256"
diff -q "$out/inputs-before.sha256" "$out/inputs-after.sha256"
echo "the two interpreters saw the same bytes"

if diff -q "$out/micro-luajit.tsv" "$out/micro-puc51.tsv" >/dev/null; then
	echo "WP13 FINAL MICRO PAIR BYTE-IDENTICAL"
else
	echo "WP13 FINAL MICRO PAIR DIFFERS" >&2
	diff "$out/micro-luajit.tsv" "$out/micro-puc51.tsv" | head -40 >&2
	exit 1
fi
sha256sum "$out/micro-luajit.tsv" "$out/micro-puc51.tsv"
echo
echo "== this capital's own rows =="
grep '^gor_drazhak' "$out/micro-luajit.tsv"
