#!/usr/bin/env bash
# What this lane moved and what it did not.
#
#   identity.sh <this tree> <a main checkout at dfb32cd5>
#
# Round 4's copy of wave 3's script, pointed at this round's merge base.
set -uo pipefail
export LC_ALL=C
here="${1:?usage: identity.sh THIS_TREE MAIN_TREE}"
main="${2:?usage: identity.sh THIS_TREE MAIN_TREE}"
cd "$here"

echo "== the files this branch changed against dfb32cd5 =="
git diff --name-status dfb32cd5

echo
echo "== the six start identities: main's own, then this branch's =="
echo -n "main   "
( cd "$main" && luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua . ) | sha256sum
echo -n "branch "
luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua . | sha256sum

echo
echo "== Highcourt's blueprint digests: main's own, then this branch's =="
( cd "$main" && luajit tools/wp13/highcourt_identities.lua . ) > /tmp/hc-main.$$.txt
luajit tools/wp13/highcourt_identities.lua . > /tmp/hc-branch.$$.txt
diff /tmp/hc-main.$$.txt /tmp/hc-branch.$$.txt && echo "(no difference)"
rm -f /tmp/hc-main.$$.txt /tmp/hc-branch.$$.txt

echo
echo "== the frozen built-geometry digests this lane re-froze =="
git diff --stat dfb32cd5 -- tools/wp13/evidence/20260915-capital-terrain

echo
echo "== every settlement identity the integration fixture prints, main against"
echo "== this branch: one token per line so the comparison is readable =="
( cd "$main" && luajit -e 'io.write(dofile("tools/wp13/integration_fixture.lua")("."))' ) |
	tr ' ' '\n' > /tmp/identity-main.$$.txt
luajit -e 'io.write(dofile("tools/wp13/integration_fixture.lua")("."))' |
	tr ' ' '\n' > /tmp/identity-branch.$$.txt
diff /tmp/identity-main.$$.txt /tmp/identity-branch.$$.txt && echo "(no difference)"
rm -f /tmp/identity-main.$$.txt /tmp/identity-branch.$$.txt
