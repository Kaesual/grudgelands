#!/usr/bin/env bash
# library_kat + blueprint_kat + integration_fixture in one process under both
# interpreters (must be byte-identical). `library_kat` section 12 is the new
# part: every capital generator, every race palette, all four rotations.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
out="$repo/tools/wp13/evidence/20260914-capital-parts"
cd "$repo"
prog='local r="." io.write(dofile(r.."/tools/wp13/library_kat.lua")(r)) io.write(dofile(r.."/tools/wp13/blueprint_kat.lua")(r)) io.write("wp13_integration\t"..dofile(r.."/tools/wp13/integration_fixture.lua")(r).."\n")'

luajit -e "$prog" >"$out/kat-luajit.txt"
tools/bin/lua51 -e "$prog" >"$out/kat-puc51.txt"
cmp "$out/kat-luajit.txt" "$out/kat-puc51.txt" && echo "KAT PAIR BYTE-IDENTICAL"

sha256sum "$out/kat-luajit.txt" "$out/kat-puc51.txt"
