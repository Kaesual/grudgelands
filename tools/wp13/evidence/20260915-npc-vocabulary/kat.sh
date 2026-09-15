#!/usr/bin/env bash
# The fixtures of this lane under both interpreters, plus the two WP40 stubs it
# re-counts, plus the six start identities it must not move.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260915-npc-vocabulary"
mkdir -p "$here/kat"

echo "== start_npcs_kat, LuaJIT =="
luajit -e 'io.write(dofile("tools/wp13/start_npcs_kat.lua")("."))' \
	>"$here/kat/start-npcs-luajit.txt" 2>&1
echo "exit=$?"
echo "== start_npcs_kat, PUC 5.1 =="
tools/bin/lua51 -e 'io.write(dofile("tools/wp13/start_npcs_kat.lua")("."))' \
	>"$here/kat/start-npcs-puc51.txt" 2>&1
echo "exit=$?"
if diff -q "$here/kat/start-npcs-luajit.txt" \
		"$here/kat/start-npcs-puc51.txt" >/dev/null; then
	echo "start_npcs_kat byte-identical under both interpreters"
else
	echo "START_NPCS_KAT INTERPRETER DRIFT"
	diff "$here/kat/start-npcs-luajit.txt" "$here/kat/start-npcs-puc51.txt"
fi

echo "== WP40 vendor_fixture (13 -> 20 vendor entities), both interpreters =="
luajit -e 'io.write(dofile("tools/wp40/quality/vendor_fixture.lua")("."))' \
	>"$here/kat/vendor-fixture-luajit.txt" 2>&1
echo "exit=$?"
tools/bin/lua51 -e 'io.write(dofile("tools/wp40/quality/vendor_fixture.lua")("."))' \
	>"$here/kat/vendor-fixture-puc51.txt" 2>&1
echo "exit=$?"
diff -q "$here/kat/vendor-fixture-luajit.txt" \
	"$here/kat/vendor-fixture-puc51.txt" >/dev/null &&
	echo "vendor_fixture byte-identical under both interpreters"

echo "== WP40 micro_kat_fixture: does it get PAST the trader projection? =="
# In a git WORKTREE the reference_projects submodules are not checked out, so
# this fixture stops later, in node_semantics_fixture, on a file it cannot
# open. What matters here is that it does not stop on the trader count: this
# lane moved that assertion from 13 to 20.
luajit -e 'dofile("tools/wp40/r7/micro_kat_fixture.lua")(".")' \
	>"$here/kat/micro-kat-fixture.txt" 2>&1
echo "exit=$?"
if grep -q "trader registration projection differs" \
		"$here/kat/micro-kat-fixture.txt"; then
	echo "TRADER PROJECTION FAILED"
else
	echo "trader projection passed (the fixture stopped later or not at all)"
fi

echo "== the six start identities, which this lane must not move =="
luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua . \
	>"$here/kat/start-identities.txt" 2>&1
cat "$here/kat/start-identities.txt"
echo -n "sha256 of that output: "
sha256sum <"$here/kat/start-identities.txt"
echo "wave-1 recorded value: 0bbf87a7253deadca55951752adde73e82c31cd10878dc64ef6d44af91ad1f5f"
