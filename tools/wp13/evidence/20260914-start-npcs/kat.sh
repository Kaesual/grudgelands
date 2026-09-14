#!/usr/bin/env bash
# library_kat + blueprint_kat + integration_fixture + settlement_sockets_kat in
# one process under both interpreters (must be byte-identical), then
# atmosphere_kat under both (it prints its own interpreter banner on line 2 and
# is compared without it).
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
out="$repo/tools/wp13/evidence/20260914-start-npcs"
cd "$repo"
prog='local r="." io.write(dofile(r.."/tools/wp13/library_kat.lua")(r)) io.write(dofile(r.."/tools/wp13/blueprint_kat.lua")(r)) io.write("wp13_integration\t"..dofile(r.."/tools/wp13/integration_fixture.lua")(r).."\n") io.write(dofile(r.."/tools/wp13/settlement_sockets_kat.lua")(r))'

luajit -e "$prog" >"$out/kat-luajit.txt"
tools/bin/lua51 -e "$prog" >"$out/kat-puc51.txt"
cmp "$out/kat-luajit.txt" "$out/kat-puc51.txt" && echo "KAT PAIR BYTE-IDENTICAL"

luajit tools/wp13/atmosphere_kat.lua >"$out/atmosphere-luajit.txt"
tools/bin/lua51 tools/wp13/atmosphere_kat.lua >"$out/atmosphere-puc51.txt"
diff <(sed '2d' "$out/atmosphere-luajit.txt") \
	<(sed '2d' "$out/atmosphere-puc51.txt") &&
	echo "ATMOSPHERE PAIR IDENTICAL apart from the interpreter banner"

sha256sum "$out/kat-luajit.txt" "$out/kat-puc51.txt"
